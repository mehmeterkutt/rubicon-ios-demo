# Manual checklist

Run before every SDK release, with the demo app and the fake backend, and record the result in the
release pull request (SDK implementation plan, step 9.3). Setup: README "Run it"; the Server tab must
say "reachable". Settings changes need "Save and quit", then open the app again. Start from the
defaults (Settings > Defaults and quit). Scenarios 3, 12 and 13 need a device; the rest run on the
simulator.

| # | Scenario | Steps in the app | Expected |
|---|---|---|---|
| 1 | Fresh install | Delete the app, install, open, go to the home screen | `Session Started`, `Application Installed` (version, build, installed_at), `Application Opened` (`from_background: false`), the screens `home` (annotation) and `tab_events`, then `Application Backgrounded` and one upload inside the background task, all in one session |
| 2 | Update | Install a build with a higher `CFBundleVersion` over it (project.yml `CFBundleVersion`), open | `Application Updated` with the previous version and build |
| 3 | Offline (device) | Airplane mode on, Events > Burst 50, wait, airplane mode off | Nothing arrives while offline; all 50 arrive once when online (Server tab); no `connect` failures in the log |
| 4 | Background and return | Return within the timeout; then Settings > timeout 10 s, Save and quit, open, home screen, wait 15 s, open | Within: same session, no `Session Started`. After: `Session Ended` backdated to the last activity with `duration_ms`, a new session, `Application Opened` with `from_background: true` |
| 5 | Server errors | Server > 503 + Retry-After 30 > Apply, Events > Track, Flush; then 401 | 503: the retry comes 30 s later. 401: one request, then a pause of about an hour even after Reset to 200 and a new flush; one ERROR `UPLOAD_UNAUTHORIZED`. Identity > Clear local data ends the pause |
| 6 | Kill and relaunch | Events > Track ×5, Capture > "Track, then kill", open the app, home screen | The 5 events and `Before Kill` arrive once; nothing twice |
| 7 | Expired background task | Server > delay 240000 > Apply, Events > Track, home screen, wait 40 s, Reset to 200, open the app, home screen | The first attempt is cancelled when the system ends the task (`canceled` in the retry state, no error); the same batch arrives after the next trigger |
| 8 | Opt-out and consent | Identity > Opt out, Events > Track, Purchase, Flush, Identity > Opt in, Events > Screen. Then Settings > pending, choice not stored, Save and quit, open, Track, Purchase, Identity > Opt in | Nothing from the opted-out period, no `Session Ended`, a new session after opting in, no opt-in event. Pending: nothing sent, not even the immediate Purchase; after opting in, every waiting event arrives |
| 9 | Identity | Identity > Identify, Events > Track, Identity > Reset, Track, Identify; change the id while identified, Identify | Events carry the user id; reset: `Session Ended` with the old user, then `user_id: null` and a new session; another id while identified: `Session Ended` for the old user, a new session for the new one |
| 10 | Deep links | Capture > Campaign link, Token in path, Legacy host, Universal link; then with the app closed `xcrun simctl openurl booted "rubicon://open/promo?utm_source=terminal&secret=1"` and Open on the system's prompt | Only scheme, host, path, `utm_*` and referrer; the reset token becomes `:token`; the universal link's referrer is `news.example.org`; never a private parameter or fragment; the cold-start link arrives too |
| 11 | Network capture | Capture > every HTTP call; then Server > remote `autocapture_off: network_requests`, Save, quit and open, call again | Ids masked, no query or fragment, short errors (`timeout`, `connect`, `canceled`), unknown host and the SDK's host not captured. After the switch-off: the call works, nothing is captured |
| 12 | Device lock (device) | Settings on the device: a passcode; open the app, Events > Track, lock the device for a minute, unlock | No `STORAGE_*` error; the event arrives after the unlock (the files keep the host's protection class, iOS Disk 1) |
| 13 | Cleartext host without an exception | Remove `NSAppTransportSecurity` from project.yml, `xcodegen generate`, build, open, Events > Track, Flush | One ERROR `TLS_FAILED` naming App Transport Security; nothing arrives; the events stay queued |
| 14 | Wrong key | Settings > API key blank, Save and quit, open | The no-op instance: `deviceId` empty, `isOptedOut` true, one ERROR at start; with `debug` on the app traps at launch instead |
| 15 | Kill switch | Server > Kill switch, quit and open, Track, Flush; then Delete, quit and open twice | Nothing collected or sent after the configuration arrives; after Delete (404), collection resumes from the following launch |
| 16 | Silent log | Settings > warn, In-app logger off, Save and quit; use the app normally; `log stream --predicate 'subsystem == "com.rubicon.analytics"'` | No line, apart from `CLEARTEXT_HOST` at start because the fake backend is http |
| 17 | Privacy report | Xcode > Product > Archive > Generate Privacy Report (or inspect `PrivacyInfo.xcprivacy` in the built app) | The SDK's data types and the two required-reason APIs (`35F9.1`, `C617.1`), no tracking |

Also worth a look before a release: Events > every validation case and the hooks (Settings), the
`ScreenNamed` controller (`product_detail`), the SwiftUI page (no screen view), an alert and a
rotation (no new screen view), debug on (a mistake traps the app on purpose).

## Last run

Not yet run. The first run is the user's, on the simulator and on a device for 3, 12 and 13.
