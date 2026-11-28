# iDesk

**Desktop mode for iPhone and iPad.** Connect a monitor, a TV or a laptop: the big screen gets a desktop with windows,
a taskbar, desktop websites and iOS apps in windows. The iPhone becomes the trackpad and keyboard.

[Tiếng Việt](README.vi.md) · Developed by **Kryvanta** · Using Android? See [Olyvexis](https://github.com/Kryvanta/Olyvexis), the sister project with the same desktop look and shortcuts

> **Experimental.** iDesk uses private UIKit APIs, is meant to be sideloaded, and a future iOS may break parts of it.

## Features

- **Windows**: move, resize, snap layouts (halves, thirds, quarters), workspaces, Spotlight (⌘ + Space), ⌥ + Tab.
- **Browser**: tabs, desktop sites, bookmarks bar, ad blocking with your own lists, reader view, translate, dark pages.
- **iOS apps from IPA files** in windows, several at once. Two-finger scroll flicks TikTok, Reels and Shorts one video
  at a time; pinch zooms; *Quit app completely* in the window menu.
- **Files**: folders, search, zip, Trash, Quick Look, a text editor.
- **Desktop**: widgets, sticky notes, wallpapers, clipboard history (⌘ + Shift + V), screenshots and screen recording.
- **Input**: trackpad gestures, pinch to zoom, any keyboard language (Telex, VNI…), voice typing, Bluetooth keyboard,
  mouse, game controller.
- **Updates in the app**: *Settings › Help › Update* keeps your iOS apps.
- **Send report** after a crash opens a filled-in GitHub issue.

## Connect a display

| How              | You need                                                               |
| ---------------- | ---------------------------------------------------------------------- |
| Cable            | USB-C → HDMI cable, or Apple's Lightning → HDMI adapter                |
| AirPlay          | Apple TV, an AirPlay TV or a Mac                                       |
| Laptop           | Tap **Laptop** and open the address in its browser (same Wi-Fi)        |

In laptop mode, turn the iPhone sideways and it becomes the screen itself.

## Install

Needs **iOS 17+**: iPhone XS / XR or newer, or an iPad.

Download `iDesk-<version>.ipa` from [Releases](https://github.com/itshieuk/iDesk/releases), then sign and install it
with ESign, Feather or Scarlet. To build it yourself (Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)):

```bash
brew install xcodegen
git clone https://github.com/itshieuk/iDesk.git && cd iDesk
xcodegen
scripts/build-ipa.sh      # → build/iDesk.ipa
```

## Using iDesk

| On the iPhone           | Does                        | Keyboard (⌘)  | Does                     |
| ----------------------- | --------------------------- | ------------- | ------------------------ |
| One finger              | Move the pointer            | T / N / W     | New tab / window, close  |
| Tap / two-finger tap    | Click / right-click         | Shift + T     | Reopen what you closed   |
| Two-finger drag         | Scroll                      | L / R         | Address bar / reload     |
| Pinch                   | Zoom                        | F             | Find in page             |
| Hold, then drag         | Move or resize a window     | Space         | Spotlight                |
| Three fingers ↑ / ↓ / • | Recent apps / Home / Back   | /             | Every shortcut           |

## iOS apps from IPA files

1. Tap **Apps** on the iPhone and add decrypted `.ipa` files.
2. Tap **Install new apps into iDesk** and pick ESign: it signs iDesk again with the apps inside.
3. Open iDesk again: the apps are in the app menu.

iOS only runs code inside an installed app, hence the reinstall. App Store apps can't be shown. Push notifications,
iCloud and background tasks don't work, and all apps share iDesk's memory.

**Known issues:** YouTube may say "No stream"; Facebook may ask for a captcha; some modded IPAs make iOS close iDesk.

## Development

- `-iDeskPreview` shows the desktop on the iPhone screen. `scripts/sim-ipa.sh App.ipa` makes an IPA run in the
  Simulator.
- Code: `App/` scenes, `Desktop/` desktop and browser, `Controller/` iPhone screen, `Input/` mouse, `Guest/` loading
  apps.
- Texts: `iDesk/Localizable.xcstrings`. Releases: push a tag such as `v0.6.5`.

[GPL-3.0](LICENSE) · © Kryvanta · Only load apps you have the right to use. iDesk is not affiliated with Apple or any app developer.
