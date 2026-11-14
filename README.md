# iDesk

**Desktop mode for iPhone.** Connect your iPhone to a monitor or TV and get a real desktop on the big screen:
windows you can move and resize, a taskbar, a Start menu, desktop websites, and even other iOS apps running in
windows. The iPhone becomes your trackpad and keyboard.

[Tiếng Việt](README.vi.md)

> **Status: experimental.** iDesk uses private UIKit APIs. It is meant to be sideloaded, not published on the
> App Store, and a future iOS update may break parts of it.

## Features

- **A desktop on the external display.** Windows can be moved, resized, snapped to half the screen, maximized
  and minimized. There is a taskbar with clock and battery, a Start menu, desktop icons and right-click menus.
  Open windows come back the next time you start iDesk.
- **Desktop websites.** Each window is a browser that asks for the desktop version of sites. Clicks, scrolling
  and typing go into the page. Video fullscreen (YouTube, embedded players) fills the whole monitor.
- **iOS apps in windows.** Add decrypted IPA files and the apps run inside iDesk as desktop windows you can
  click, drag, scroll and type into, several at the same time.
- **The iPhone as input.** Trackpad gestures, a full-screen trackpad in landscape, a compose field that supports
  every keyboard and input method, live typing, Bluetooth keyboards with desktop shortcuts, and mice through
  AssistiveTouch.
- **Settings.** iPhone brightness, monitor brightness, wallpaper (built-in gradients or your own photo), pointer
  speed and scroll speed. Sound plays through the display: set the volume on the display or TV (over HDMI and
  DisplayPort iOS sends audio at full level, so volume sliders on the iPhone or in apps have no effect).
- **English and Vietnamese.** The app follows the iPhone's language and falls back to English.
- **Crash reports.** If an app takes iDesk down, the next launch says why, with a **Copy error** button.

## Requirements

- An iPhone on **iOS 17 or later**.
- A cable or adapter to the monitor: USB-C to HDMI/DisplayPort (iPhone 15 and later), or Apple's Lightning
  Digital AV Adapter (older iPhones).
- To build: a Mac with **Xcode 15+** and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Install

```bash
brew install xcodegen
git clone https://github.com/itshieuk/iDesk.git
cd iDesk
xcodegen
```

Then pick one:

- **Xcode:** open `iDesk.xcodeproj`, choose your Team under *Signing & Capabilities*, and press Run.
- **A signing app** (ESign, Feather, Scarlet, …): build an unsigned IPA, then sign and install it with that app.

  ```bash
  scripts/build-ipa.sh
  ```

  The file is written to `build/iDesk.ipa`.

## Using iDesk

Open iDesk, then connect the display. The monitor shows the desktop, and the iPhone shows the controls.

### Trackpad

| On the iPhone                | Does                                                               |
| ---------------------------- | ------------------------------------------------------------------ |
| Drag one finger              | Move the pointer                                                   |
| Tap / double tap             | Click / double-click                                               |
| Two-finger tap               | Right-click                                                        |
| Two-finger drag              | Scroll                                                             |
| Hold about 0.35 s, then drag | Press and drag: move a window by its title bar, resize by an edge  |

Turn the iPhone sideways and the whole screen becomes the trackpad.

### Controls on the iPhone

- **Address bar:** open a web address or search in the focused window.
- **Toolbar:** back, forward, reload, Start menu, new window, apps from IPA, close window, live typing.
- **Compose field:** type with any keyboard (Vietnamese, Japanese, Chinese, …), then send the text to the field
  selected on the page.
- **Gear button:** settings. **Corner button:** mouse mode (see below).

### Keyboard

A Bluetooth keyboard types straight into the page. Shortcuts work with ⌘ or Ctrl:

| Keys              | Does           | Keys  | Does                          |
| ----------------- | -------------- | ----- | ----------------------------- |
| T or N            | New window     | A     | Select all                    |
| W                 | Close window   | C / V | Copy / paste                  |
| R                 | Reload         | D     | Show desktop                  |
| [ / ] or ← / →    | Back / forward | M     | Minimize                      |
| Tab (or Alt+Tab)  | Switch windows | Esc   | Close menus, leave fullscreen |

### Mouse

On iPhone, iOS gives apps no pointer API like it does on iPad. A mouse only works through AssistiveTouch:
*Settings → Accessibility → Touch → AssistiveTouch*, then pair the mouse under *Pointer Devices*. iOS draws that
pointer on the iPhone screen only and does not tell apps where it is until you click.

So while AssistiveTouch is on, the iPhone trackpad shows a **live copy of the desktop**. Point at something on it
and click: the desktop pointer goes to the same spot. Hold to drag, use the right button for the context menu,
and scroll with two fingers or the wheel. The corner button turns on **mouse mode**: landscape, with the copy of
the desktop filling the screen.

### Language

iDesk follows the iPhone's language. To change it for iDesk only: *Settings → iDesk → Language*.

## Running iOS apps from IPA files

iDesk loads another app **into its own process** and shows the app's window on the desktop.

1. Tap the box button on the iPhone, then **Add IPA**, and pick one or more decrypted `.ipa` files.
2. iDesk prepares the apps one by one and creates `iDesk-with-apps.ipa`: iDesk with the new apps packed inside.
   The share sheet opens.
3. Open that file in your signing app, then sign and install it over iDesk as usual.
4. Open iDesk again and connect the display. The app is on the desktop and in the Start menu.

**Why install iDesk again?** With a normal certificate, iOS only runs code that ships inside an installed app.
Code from an app's own data folder is blocked, even with a valid signature. If iDesk was installed with a
development certificate (`get-task-allow`, for example through SideStore or AltStore), the **Advanced** section
can sign apps on the iPhone and open them right away.

**Storage.** Apps are packed inside iDesk, so iDesk takes about as much space as all of them together. To remove
one, swipe it, tap **Remove from iDesk**, then install iDesk again.

**What works and what does not.** Most apps open and work, but not all of them, because an app inside another
app is not a normal launch.

- Works: the app's screens, taps, drags, scrolling, typing, its own fonts, network access, sign-in, and data the
  app saves.
- Does not work: push notifications, iCloud sync, background tasks, widgets and other extensions.
- An app that turns to landscape for fullscreen (a video player) fills the display; it shrinks back when the app
  returns to portrait, or press Esc.
- Tweaked IPAs that bundle old jailbreak libraries (libsubstrate linking the removed libstdc++) load: the parts
  iOS no longer has do nothing. Tweaks that patch code in memory still cannot work without a jailbreak.
- System screens an app opens (App Store page, mail, share sheet, photo or file picker) appear on the iPhone
  screen, where you use them by touch. An app's in-app browser opens as a web window on the desktop.
- Closing an app's window sends it to the background (it pauses, like when you leave an app on the iPhone). It is
  fully closed only when iDesk quits: iOS cannot remove an app's code from a running process.
- Data an app shares with its sister apps (shared keychain, App Groups) stays inside iDesk.
- Apps that check where they run (jailbreak, tamper or signature checks) may refuse to start or close
  themselves.
- Several apps can run at once, but they share iDesk's memory: with too many big apps open, iOS closes iDesk.
  Closing a window only hides its app; it keeps running until you quit iDesk. If one app freezes, iDesk and the
  other apps freeze too.
- Two apps that use the same Objective-C class names inside their storyboards can disturb each other.

If an app crashes iDesk, open iDesk again, tap **Copy error** and include the text when you report the problem.

## How it works

**Desktop.** The external display gets its own scene that draws the whole desktop in SwiftUI. That scene
receives no touches, so iDesk draws its own pointer and does its own hit testing. Web windows are WKWebViews:
clicks, hover, scrolling and keys are sent into the page with JavaScript, and a small script emulates the element
Fullscreen API that WebKit lacks on iPhone.

**Apps from IPA files** (`iDesk/Guest/`):

- `MachOPatcher` turns the app's executable into a library that `dlopen` accepts (MH_DYLIB, a small
  `__PAGEZERO`, an install name, `@executable_path` rewritten) and keeps only the arm64 code.
- `ImportWeakener` marks system functions this iOS no longer has as optional, so old bundled libraries
  (libsubstrate in tweaked IPAs) do not stop the app from loading.
- `GuestStore` keeps the app library and packs apps into iDesk. It also copies into iDesk's Info.plist what iOS
  reads only from the installed app: permission texts, network security (ATS), background modes and URL schemes.
- `GuestRuntime` runs the app's own `main()` up to `UIApplicationMain` to learn its app delegate, then drives the
  app and scene lifecycle (UIKit and SwiftUI apps). Every window an app creates (a second main window, overlays,
  HUDs) is attributed to it from the call stack, kept below iDesk's window on the iPhone, and shown inside the
  app's desktop window through `_UIPortalView`.
- `GuestShims` fixes what every app meets inside iDesk, whatever the app:
  - it runs with iDesk's entitlements: keychain access groups are dropped, missing App Groups get a private
    folder, CloudKit gets an inert stand-in, HealthKit requests are answered "denied";
  - the process launched long before: `UIApplicationMain` is intercepted, `BGTaskScheduler` registrations are
    accepted without crashing, the app's fonts are registered;
  - the process is iDesk's and shared by several apps: `Bundle.main`, `CFBundleGetMainBundle`,
    `UIApplication.delegate`, `keyWindow` and `windows` answer each app with its own, found from the call stack;
    an `exit()` called by an app is recorded in the crash report.
- `CategoryRepair` adds the missing accessors of `@dynamic` properties that apps declare on `CALayer` /
  `CAAnimation` (AsyncDisplayKit, used by YouTube, does this).
- `GuestTouch` creates synthetic touches (UITouch + IOHIDEvent), scrolls and types into the app.
- `CrashReporter` records signals, uncaught exceptions and Mach exceptions, and writes a heartbeat so that a
  kill by iOS (out of memory) can be detected.
- `CodeSigner` signs code on the iPhone for the **Advanced** option.

## Development

### Testing without a monitor or an iPhone

- The launch argument `-iDeskPreview` shows the desktop on the iPhone screen; touch it directly. Add
  `-iDeskInstall <path.ipa> [more.ipa …]` to install apps and open the first, or `-iDeskOpen <url>` to open a page.
- The Simulator cannot run apps built for devices, but on Apple silicon Macs the code is the same. Convert a
  decrypted IPA, then pass the `-sim.ipa` file to `-iDeskInstall`:

  ```bash
  scripts/sim-ipa.sh App.ipa
  ```

  Videos do not play in the Simulator.

### Translating

All text is in `iDesk/Localizable.xcstrings`, and permission texts are in `iDesk/InfoPlist.xcstrings`. Open them
in Xcode and add a language to translate iDesk.

### Project layout

```
iDesk/
  App/          app delegate, iPhone and external display scenes, preview mode
  Desktop/      desktop state and drawing, web input, web fullscreen
  Controller/   iPhone screen: trackpad, keyboard, apps sheet, settings
  Input/        mouse input (GameController, AssistiveTouch)
  Guest/        running apps from IPA files (see "How it works")
  Localizable.xcstrings, InfoPlist.xcstrings
scripts/        build-ipa.sh, sim-ipa.sh
project.yml     XcodeGen project
```

## Known issues

- Web pages get mouse events from JavaScript, so CSS `:hover` styles do not apply, and some pages (canvas apps,
  frames from other sites) may ignore clicks.
- Live typing does not support input methods that compose characters; use the compose field for Vietnamese,
  Japanese, Chinese, …
- Without an external display, only app and certificate management works.

## FAQ

**Can iDesk show apps that are already installed on my iPhone?** No. iOS keeps every app in its own sandbox: no
app can see, show or control another app, and there is no API for it. iDesk can only show web pages or load an
app's code from an IPA file. To use installed apps on an external display you need an iPad with Stage Manager.

## License

[MIT](LICENSE)

## Disclaimer

Only load apps you have the right to use. iDesk is not affiliated with Apple, Google or any app developer.
