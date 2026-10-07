# PullJoy (native) — agent guide

A macOS menu-bar app, in Swift: an inbox of the pull requests waiting on you. The rules follow Pullover (https://github.com/omgovich/pullover), credited in the README.

- `Sources/PullJoyCore` — pure rules (classify, threads, stacks, snooze, format, agent view). No I/O, no clock: `now` is always passed in.
- `Sources/PullJoyKit` — GitHub GraphQL, browser sign-in, Keychain, `AppStore` (UserDefaults), the `Inbox` engine, the MCP server, the update check.
- `Sources/PullJoy` — the app: `AppModel` (state and actions), `StatusItemController` (status item, popover, keys, menus), SwiftUI views.

Commands:

- `swift format -i -r Sources Tests` — format. `swiftlint lint --strict` — rules (`brew install swiftlint`). CI runs both.
- `./scripts/test.sh` — all tests (Swift Testing). Run before committing.
- `swift run PullJoy` — run from source (needs `PULLJOY_GITHUB_CLIENT_ID`); `PULLJOY_DEMO=1` for an invented inbox.
- `./scripts/snapshots.sh [dir]` — render the screens offscreen to PNGs; look at them after any UI change.
- `./scripts/bundle.sh` — `dist/PullJoy.app`, zip and dmg.

Conventions:

- A rule change goes in `PullJoyCore` with a test; views only display what the core decides.
- Interpolated numbers in SwiftUI go through `Text(verbatim:)` — `Text("#\(n)")` localises to `#2,184`.
- `InboxSection` and `Preferences` are the core types for the inbox sections and the user settings.
- The MCP server listens on `7855` packaged and `7856` from source, on `127.0.0.1` only, and refuses foreign `Host`/`Origin`. Try it by hand:

```bash
curl -s -X POST http://127.0.0.1:7856/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

- Colours come from the palette in `Views/Theme.swift` (light and dark values), never `.blue`, `.red` or `.green`. Text sizes come from the system scale where one fits.
- A reason's wording and colour live on `Reason` in `PullJoyCore`; views never match on its text.
- Demo mode and snapshots are compiled in debug builds only. Demo avatars use a CC0 DiceBear style (`line-face`).

Comments: few, and only for a non-obvious why. Don't hard-wrap markdown.
