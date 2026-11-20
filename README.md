# iDesk

**Desktop mode for iPhone.** Plug the iPhone into a monitor or TV: the big screen gets a desktop with windows, a
taskbar, an app menu, desktop websites and iOS apps in windows. The iPhone becomes the trackpad and keyboard.

[Tiếng Việt](README.vi.md)

> **Experimental.** iDesk uses private UIKit APIs, is meant to be sideloaded, and a future iOS may break parts of it.

## Features

- **Spotlight** (⌘ + Space or the magnifier on the taskbar): apps, open windows, files, bookmarks and history in one
  search, plus sums (`(12+3)*4`, `15% of 80`) and unit conversions (`5 km to mi`, `100 f to c`).
- **App windows** you move, resize, minimize and maximize. Drag one to the top edge to pick a layout (halves, thirds,
  quarters); once a window takes one side, iDesk offers the other windows for the rest. ⌘ + arrows snap too. Keep a
  window on top from its title bar menu. A taskbar with Recent apps, Home and Back; an app menu with search and a
  Recent row; ⌥ + Tab, ⌘ + Q / H / `; workspaces and hot corners (optional). Open windows come back next time.
- **Clipboard history** (⌘ + Shift + V): what you copied on the desktop, pinned items first.
- **Screenshots** of the whole screen (⌘ + Shift + 3) or of an area or a window (⌘ + Shift + 4), saved to Photos and
  Files, copied, and shown in the corner. **Sticky notes** on the desktop (right-click the desktop).
- **Browser** with tabs, desktop sites, sign-in popups, fullscreen video, find in page, zoom, bookmarks and history,
  ad and tracker blocking, and a text size for every page.
- **Files**: downloads and screenshots, folders, rename, move, search, sort, new text file, unzip, import from the
  iPhone, Quick Look (Space). Text files open in an editor with autosave, find and replace, and Save as.
- **iOS apps from decrypted IPA files**, running in windows, several at once. They reopen next time, unless iDesk
  quit unexpectedly: the Apps page then marks the app that was in use.
- **The iPhone as input**: trackpad gestures, typing in any language (Telex, VNI…), a Bluetooth keyboard, a mouse
  through AssistiveTouch, and a paste button for what you copied on the iPhone (a password, say).
- **Desktop**: icons you arrange and size, files on the desktop, wallpaper, quick panel and notifications, battery,
  heat and memory in the tray, display resolution and TV overscan.
- A first-run guide, crash and freeze reports with a **Copy error** button, English and Vietnamese.

## Install

You need an iPhone on **iOS 17+** and a USB-C → HDMI/DisplayPort cable (or Apple's Lightning AV adapter).

Download `iDesk-<version>.ipa` from [Releases](https://github.com/itshieuk/iDesk/releases), then sign and install it
with ESign, Feather or Scarlet. To build it yourself (Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)):

```bash
brew install xcodegen
git clone https://github.com/itshieuk/iDesk.git && cd iDesk
xcodegen
scripts/build-ipa.sh      # → build/iDesk.ipa (or open iDesk.xcodeproj and Run)
```

## Using iDesk

Open iDesk, then connect the display.

| On the iPhone           | Does                          | Keyboard (⌘ or Ctrl)  | Does                            |
| ----------------------- | ----------------------------- | --------------------- | ------------------------------- |
| One finger              | Move the pointer              | T / N / W             | New tab / window, close         |
| Tap / two-finger tap    | Click / right-click           | Shift + T             | Reopen what you closed          |
| Two-finger drag         | Scroll                        | L / R                 | Address bar / reload            |
| Hold, then drag         | Move or resize a window       | F / G                 | Find / next match               |
| Three fingers ↑ / ↓ / • | Recent apps / Home / Back     | = / − / 0             | Zoom                            |
| Four-finger tap         | App menu                      | ⌘ alone / Tab         | App menu, Recent apps           |
| Turn it sideways        | The whole screen is the pad   | /                     | Every shortcut                  |

On a keyboard without ⌘, the logo key does the same. A mouse works through *Settings → Accessibility → Touch → AssistiveTouch*: the iPhone
then shows a copy of the desktop to point at (the **Mouse check** shows what reaches iDesk). Settings are on the
desktop; with no display, the gear on the iPhone keeps the trackpad and mouse settings.

## iOS apps from IPA files

1. Tap **Apps** (the box button) on the iPhone and add decrypted `.ipa` files.
2. Tap **Install new apps into iDesk** and pick ESign: it signs iDesk again with the apps inside and installs it.
3. Open iDesk again: the apps are in the app menu.

iOS only runs code that ships inside an installed app, hence the reinstall (with a development certificate, the
**Advanced** section signs apps on the iPhone instead). Apps installed from the App Store can't be shown: iOS keeps
every app in its own sandbox.

Most apps work: screens, touches, typing, network, sign-in, saved data. Push notifications, iCloud, background tasks
and extensions don't. Apps that check for tampering may quit, and all apps share iDesk's memory. If one crashes
iDesk, the next launch shows **Copy error**: please send that text.

## Development

- `-iDeskPreview` shows the desktop on the iPhone screen (touch it; hold for a right-click). Add
  `-iDeskInstall <ipa…>` or `-iDeskOpen <url>`. `scripts/sim-ipa.sh App.ipa` makes an IPA run in the Simulator.
- Code: `App/` scenes, `Desktop/` the desktop and browser, `Controller/` the iPhone screen, `Input/` mouse,
  `Guest/` loading apps (Mach-O patching, lifecycle, shims for bundle, keychain and process-wide hooks, synthetic
  touches, crash reports).
- Texts: `iDesk/Localizable.xcstrings`. Releases: push a tag such as `v0.5.2`.

**Known issues:** pages get mouse events from JavaScript, so CSS `:hover` doesn't apply and some canvas pages
ignore clicks. Without a display, only app management works.

[MIT](LICENSE) · Only load apps you have the right to use. iDesk is not affiliated with Apple or any app developer.
