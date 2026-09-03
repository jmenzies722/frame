# Frame

Click a display. It’s on the clipboard.

Native Mac menu bar app. Swift only — no Electron, no account, no network. Press `⌃⇧⌘2`, every display dims, click one, paste. Emails and key-shaped strings are blurred before they reach the clipboard.

The image never leaves the Mac.

## Use

| | |
| --- | --- |
| `⌃⇧⌘2` / **Capture** | Dim every display. Click one. PNG on the clipboard. |
| `⌃⇧⌘3` / **Capture Window** | Click a window instead. Same result. |
| `⌃⇧⌘1` | Capture the display under the pointer. No click. |
| `⌃⇧⌘R` / **Capture Region…** | Drag a rectangle, then edit. |
| Copied toast | Drag into Slack or Notes. Space edits. `S` saves. |
| **Hide secrets on copy** | On by default. Blurs keys and emails *before* the clipboard. |

Shortcuts are editable in Settings. Frame does not steal `⌘⇧3` / `⌘⇧4` / `⌘⇧5`.

After copy, the toast is the product: drag it, or Space into the editor for arrows, rectangles, highlights, text, blur, and a padded frame. History keeps the last 20 copies in `~/Library/Application Support/Frame/History`. Launch at login is off until you turn it on.

## Install

macOS 26+, Apple Silicon. Xcode Command Line Tools, and an Apple Development identity so Screen Recording survives rebuilds.

```bash
git clone https://github.com/jmenzies722/frame.git
cd frame
make unlock
```

`make unlock` signs the app, resets the Screen Recording grant for `com.shualabs.frame`, installs to `~/Applications`, and opens it. macOS asks once. Allow it.

If you are not signing as the identity in the Makefile:

```bash
security find-identity -v -p codesigning
make unlock SIGN_ID="Apple Development: you@example.com (TEAMID)"
```

A free Apple ID is enough. Sign with a stable identity. macOS keys Screen Recording to the *code signature*, not the path. An unsigned rebuild inherits a grant that no longer applies and captures nothing. `make unlock` is the fix for that.

Then: menu bar → **Capture** → click a display. Paste.

## Secrets

On-device Vision reads the shot. Matches against emails, `sk-` keys, AWS ids, GitHub PATs, Slack tokens, Bearer tokens, and PEM private-key blocks, then blurs those boxes before the clipboard.

PEM blocks are tracked across lines — matching each line alone would hide the header and copy the key. If the scan cannot run, Frame does not copy. A failed scan and a clean scan are not the same thing.

This catches common shapes. A secret that does not look like one of them is not caught. Turn it off in Settings if you want the raw pixels.

```bash
make test
```

Runs the pattern tests. A false negative is a credential in a screenshot.

## Privacy

No analytics, no crash reporter, no account, no network. Screen Recording is the only permission, and only when you capture or open Settings — never on launch. History stays on this Mac.

## Not this

No recording. No scrolling capture. No share links. No model calls over the network.
