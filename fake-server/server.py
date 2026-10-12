#!/usr/bin/env python3
"""
Fake Rubicon backend for the demo app. Standard library only; the same file as the Android demo's,
with the iOS names.

  python3 fake-server/server.py [port]      # listens on 0.0.0.0:8080
  The simulator reaches the Mac at http://127.0.0.1:8080. The demo's own HTTP calls use the second
  name http://localhost:8080, because the SDK's network observer never captures the SDK's own
  host. A device on the same Wi-Fi uses the Mac's address (Settings > Host and API base).

What the SDK calls
  POST /v1/batch          stores the events and answers as /control says (200 by default)
  GET  /v1/config         remote configuration of the key in `Authorization: Bearer <key>`, from
                          fake-server/config/<key>.json; ETag and 304; 404 when there is no file

What the demo app (or you) calls
  GET  /control                         current behaviour of /v1/batch
  GET  /control?status=503&retry_after=30&delay_ms=0&mode=normal
         status       HTTP status of the next batch responses (200, 400, 401, 413, 429, 503, ...)
         retry_after  Retry-After header, in seconds; empty to remove
         delay_ms     wait before answering (slow server, timeouts)
         mode         normal | redirect (302 to /elsewhere) | drop (close without answering)
  GET  /control/reset                   back to 200, no delay, normal
  GET  /control/config?key=K            the remote configuration of key K (404 if none)
  POST /control/config?key=K            body: a JSON object; saved as config/K.json
  DELETE /control/config?key=K          delete it, so /v1/config answers 404
  GET  /events[?since=N]                events received, oldest first, each with its index
  GET  /events/clear                    forget them
  GET  /requests                        the last 200 requests, newest first: method, path, status,
                                        sizes and the headers the SDK sets (never the key itself)
  ANY  /api/...                         for the app's own calls through the interceptor:
         /api/status/<code>             answers <code>
         /api/slow?ms=N                 answers after N ms
         anything else                  200 with a small JSON body
"""
import gzip
import hashlib
import json
import os
import re
import socket
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

CONFIG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config")
# What the two SDKs send: rubicon-ios/<version> (iOS <os>) and rubicon-android/<version> (...).
SDK_USER_AGENT = re.compile(r"^rubicon-(ios|android)/\d+\.\d+\.\d+ \(.+\)$")
MAX_REQUESTS = 200

lock = threading.Lock()
control = {"status": 200, "retry_after": None, "delay_ms": 0, "mode": "normal"}
received = []  # every event, in arrival order
requests_log = []  # recent requests, newest last


def config_path(key):
    safe = "".join(c for c in key if c.isalnum() or c in "-_.")
    return os.path.join(CONFIG_DIR, f"{safe or 'default'}.json")


def bearer(headers):
    value = headers.get("Authorization", "")
    return value[7:] if value.startswith("Bearer ") else ""


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    # --- helpers ---------------------------------------------------------------------------------

    def _query(self):
        url = urlparse(self.path)
        return url.path, {k: v[0] for k, v in parse_qs(url.query, keep_blank_values=True).items()}

    def _body(self):
        length = int(self.headers.get("Content-Length", 0) or 0)
        raw = self.rfile.read(length) if length else b""
        gzipped = self.headers.get("Content-Encoding", "").lower() == "gzip"
        return (gzip.decompress(raw) if gzipped and raw else raw), len(raw), gzipped

    def _send(self, code, body=None, headers=None, raw=None):
        data = raw if raw is not None else (b"" if body is None else json.dumps(body, indent=2).encode())
        self.send_response(code)
        if data:
            self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if data and self.command != "HEAD":
            self.wfile.write(data)
        return code

    def _record(self, status, sent_bytes, gzipped=False, note=""):
        entry = {
            "time": time.strftime("%H:%M:%S"),
            "method": self.command,
            "path": self.path,
            "status": status,
            "bytes": sent_bytes,
            "gzip": gzipped,
            "user_agent": self.headers.get("User-Agent"),
            "authorization": "Bearer ***" if self.headers.get("Authorization") else None,
            "if_none_match": self.headers.get("If-None-Match"),
            "note": note,
        }
        if self.path.startswith("/v1/") and not SDK_USER_AGENT.match(self.headers.get("User-Agent") or ""):
            entry["note"] = (note + "; " if note else "") + "unexpected User-Agent"
        with lock:
            requests_log.append(entry)
            del requests_log[:-MAX_REQUESTS]
        print(f"{entry['time']} {self.command} {self.path} -> {status} {note}")

    # --- routes ----------------------------------------------------------------------------------

    def do_GET(self):
        path, q = self._query()
        if path == "/v1/config":
            return self._remote_config()
        if path == "/control":
            with lock:
                if q.get("status"):
                    control["status"] = int(q["status"])
                if "retry_after" in q:
                    control["retry_after"] = q["retry_after"] or None
                if q.get("delay_ms"):
                    control["delay_ms"] = int(q["delay_ms"])
                if q.get("mode") in ("normal", "redirect", "drop"):
                    control["mode"] = q["mode"]
                snapshot = dict(control)
            return self._send(200, snapshot)
        if path == "/control/reset":
            with lock:
                control.update(status=200, retry_after=None, delay_ms=0, mode="normal")
                snapshot = dict(control)
            return self._send(200, snapshot)
        if path == "/control/config":
            file = config_path(q.get("key", ""))
            if not os.path.exists(file):
                return self._send(404, {"error": "no remote configuration for this key"})
            with open(file, "rb") as f:
                return self._send(200, raw=f.read())
        if path == "/events":
            since = int(q.get("since", 0) or 0)
            with lock:
                items = [{"index": i, "event": e} for i, e in enumerate(received) if i >= since]
            return self._send(200, items)
        if path == "/events/clear":
            with lock:
                received.clear()
            return self._send(200, {"cleared": True})
        if path == "/requests":
            with lock:
                items = list(reversed(requests_log))
            return self._send(200, items)
        if path.startswith("/api/"):
            return self._api(path, q)
        return self._send(404, {"error": "not found"})

    def do_POST(self):
        path, q = self._query()
        if path == "/v1/batch":
            return self._batch()
        if path == "/control/config":
            raw, _, _ = self._body()
            try:
                value = json.loads(raw.decode("utf-8"))
                assert isinstance(value, dict)
            except Exception:
                return self._send(400, {"error": "the body must be a JSON object"})
            os.makedirs(CONFIG_DIR, exist_ok=True)
            with open(config_path(q.get("key", "")), "w") as f:
                json.dump(value, f, indent=2)
            return self._send(200, value)
        if path.startswith("/api/"):
            self._body()
            return self._api(path, q)
        self._body()
        return self._send(404, {"error": "not found"})

    def do_DELETE(self):
        path, q = self._query()
        if path == "/control/config":
            file = config_path(q.get("key", ""))
            if os.path.exists(file):
                os.remove(file)
            return self._send(200, {"deleted": True})
        return self._send(404, {"error": "not found"})

    do_PUT = do_POST

    # --- endpoints -------------------------------------------------------------------------------

    def _batch(self):
        raw, size, gzipped = self._body()
        with lock:
            status, retry_after, delay_ms, mode = control["status"], control["retry_after"], control["delay_ms"], control["mode"]
        if delay_ms:
            time.sleep(delay_ms / 1000)
        if mode == "drop":
            self._record("dropped", size, gzipped, "connection closed without an answer")
            self.close_connection = True
            try:
                self.connection.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            return
        if mode == "redirect":
            self._record(302, size, gzipped, "redirect")
            return self._send(302, {"error": "moved"}, {"Location": "/elsewhere"})
        try:
            events = json.loads(raw.decode("utf-8"))["batch"]
        except Exception as e:
            self._record(400, size, gzipped, f"unreadable body: {e}")
            return self._send(400, {"error": "unreadable body"})
        headers = {"Retry-After": retry_after} if retry_after else None
        if status == 200:
            with lock:
                received.extend(events)
            names = ", ".join((e.get("event") or e.get("name") or e.get("type") or "?") for e in events[:6])
            self._record(200, size, gzipped, f"{len(events)} event(s): {names}{' ...' if len(events) > 6 else ''}")
            return self._send(200, {"ok": True})
        self._record(status, size, gzipped, f"forced {status}, {len(events)} event(s) not kept")
        return self._send(status, {"error": f"forced {status}"}, headers)

    def _remote_config(self):
        file = config_path(bearer(self.headers))
        if not os.path.exists(file):
            self._record(404, 0, note="no remote configuration")
            return self._send(404, {"error": "no remote configuration for this key"})
        with open(file, "rb") as f:
            data = f.read()
        etag = '"' + hashlib.sha1(data).hexdigest()[:16] + '"'
        if self.headers.get("If-None-Match") == etag:
            self._record(304, 0, note=f"unchanged {etag}")
            return self._send(304, headers={"ETag": etag})
        self._record(200, 0, note=f"configuration {etag}")
        return self._send(200, raw=data, headers={"ETag": etag})

    def _api(self, path, q):
        if path.startswith("/api/status/"):
            code = int(path.rsplit("/", 1)[1] or 200)
            self._record(code, 0, note="app call")
            return self._send(code, {"status": code})
        if path == "/api/slow":
            time.sleep(int(q.get("ms", 3000) or 3000) / 1000)
        self._record(200, 0, note="app call")
        return self._send(200, {"ok": True, "path": path, "items": list(range(20))})

    def log_message(self, fmt, *args):
        pass  # our own lines only


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    print(f"Rubicon fake backend on http://0.0.0.0:{port}  (simulator: http://127.0.0.1:{port})")
    print(f"remote configuration files: {CONFIG_DIR}")
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
