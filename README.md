# Rubicon iOS demo app

The app to try every behaviour of the Rubicon iOS SDK by hand, against a fake backend that you
control from the app itself. It is a test harness: every screen and button triggers one SDK
behaviour and says what to expect.

## Run it

1. `brew install xcodegen`, then `xcodegen generate` in this folder (the project file is generated).
2. The SDK is built from its checkout, expected at `../rubicon-ios-sdk` next to this folder
   (`project.yml`, `packages.Rubicon.path`). Once a release is tagged, switch it to the git URL.
3. Start the fake backend on the Mac: `python3 fake-server/server.py` (the simulator reaches it at
   `http://127.0.0.1:8080`; a device uses the Mac's address, set in Settings as Host and API base).
4. Open `RubiconDemo.xcodeproj` and run on a simulator, or build and install from the terminal
   (`CLAUDE.md`, Commands).

## The app

| Tab | What it tries |
|---|---|
| Events | Quick events, an event builder with typed properties, every allowed value type, every validation rule (unsupported types and keys, depth, long strings and names, 32 KB, a lone surrogate, the copy), volume and threads, the `beforeSend` hooks |
| Identity | `deviceId`, `identify` with and without traits, another user, a blank id, `reset`, super properties, `optIn`, `optOut`, `clearLocalData`, "forget me" |
| Capture | Automatic screens (`ScreenNamed`, class name, a plain controller, a SwiftUI page that produces none, an alert, a permission dialog), deep links (utm, tokens, referrer, a simulated universal link, a cold-start link from the terminal), lifecycle and sessions, killing the process, nine HTTP calls through `RubiconNetworkObserver` |
| Server | The fake backend from the app: its batch responses (any status, `Retry-After`, delay, redirect, dropped connection), the remote configuration (kill switch, autocapture off, flush values, sampling), the events it received, and the requests it saw |
| Logs | The SDK's `eventObserver` (queued, sent, dropped with the reason) and its log lines, by level |

Settings (the gear) holds every SDK setting, the hooks, consent and the observer's hosts. The SDK
reads its configuration once, so a change applies when the app is opened again ("Save and quit",
then open it); that also shows that the SDK keeps its state across a restart.

`debug` is off by default: with it on, the SDK traps on a developer's mistake, which ends the app
(iOS Configuration 2). With it off, the mistake is a WARN on the Logs tab.

The manual checklist run before every release is in [`docs/manual-checklist.md`](docs/manual-checklist.md).

## Fake backend

`fake-server/server.py`, standard library only, the same file as the Android demo's; its docstring
lists every endpoint.

- `POST /v1/batch` stores the events and answers as `/control` says.
- `GET /v1/config` serves `fake-server/config/<api key>.json` with an ETag and 304, or 404.
- `GET /control?status=503&retry_after=30&delay_ms=0&mode=normal|redirect|drop`, `GET /control/reset`.
- `GET|POST|DELETE /control/config?key=...` reads, writes and deletes a remote configuration.
- `GET /events`, `GET /events/clear`, `GET /requests` (the headers the SDK sets, never the key; a
  `User-Agent` that is not an SDK's is noted).
- `/api/...` answers the app's own calls; `/api/status/<code>`, `/api/slow?ms=N`. The app calls it
  as `localhost`, the SDK as `127.0.0.1`: the observer never captures the SDK's own host.

## Useful commands

```bash
log stream --predicate 'subsystem == "com.rubicon.analytics"' --level debug       # the SDK's log
xcrun simctl openurl booted "rubicon://open/promo?utm_source=terminal&secret=1"   # deep link; iOS asks "Open in Rubicon?", tap Open
xcrun simctl terminate booted com.rubicon.demo && xcrun simctl launch booted com.rubicon.demo
xcrun simctl install booted RubiconDemo.app                                       # a build with a higher CFBundleVersion: Application Updated
```

Offline needs a device (airplane mode); the simulator has no switch for it. On the simulator, stop
the fake server instead: the SDK sees a connection failure and backs off.
