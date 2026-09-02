# Frame

Click a display. It’s on the clipboard.

Menu bar only. Local only. No account.

## Try

macOS 26+, Apple Silicon. Xcode Command Line Tools. An Apple Development identity on the machine so Screen Recording survives rebuilds.

```bash
cd ~/Developer/projects/frame
make unlock
```

`make unlock` signs Frame, resets the Screen Recording grant for this bundle, installs to `~/Applications`, and opens it. macOS will ask once. Allow it.

Then: menu bar → **Capture** (or `⌃⇧⌘2`) → click any display. Paste.

If Settings already showed Frame as allowed and capture still failed, that grant was bound to an older unsigned build. `make unlock` is the fix.

## Use

| Action | What happens |
| --- | --- |
| `⌃⇧⌘2` / Capture | Dim every display. Click one. PNG lands on the clipboard. |
| `⌃⇧⌘3` / Capture Window | Click a window. Same, clipboard. |
| `⌃⇧⌘1` | Capture the display under the pointer, no click. |
| `⌃⇧⌘R` / Capture Region… | Drag a rectangle, then edit. |
| Copied toast | Drag into Slack or Notes. Space edits. `S` saves. |
| Hide secrets on copy | On by default. Blurs emails and keys before the clipboard. |

Shortcuts are editable in Settings and do not steal `⌘⇧3` / `⌘⇧4` / `⌘⇧5`.

History keeps the last 20 copies in Application Support. Launch at login is off until you turn it on.

## Privacy

No analytics, no crash reporter, no account, no network. History lives in `~/Library/Application Support/Frame/History`.

## Tests

```bash
make test
```
