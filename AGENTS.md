# Frame

Native Mac menu-bar screenshot app. Swift only. No Electron. No Catalyst.
No network, no analytics, no account, no cloud.

Deployment floor is macOS 26.0, Apple Silicon. Do not add Intel slices.
Use public `glassEffect` / `GlassEffectContainer` only.

Screen Recording is the only TCC prompt. Trigger it from a capture action
or Settings — never on launch. Sign the .app with a stable identifier so
TCC survives rebuilds. If the user already granted an older unsigned
build, `tccutil reset ScreenCapture com.shualabs.frame` is required once.

Do not register `SMAppService` on launch. Login item is opt-in and off
by default.

Do not steal `⌘⇧3`, `⌘⇧4`, or `⌘⇧5`.

Identity lives in `ProductIdentity`. Rename there, not by hunting strings.

The primary loop is click a display → clipboard. Region edit is secondary.
No recording, no scrolling capture, no share links, no model calls over
the network.
