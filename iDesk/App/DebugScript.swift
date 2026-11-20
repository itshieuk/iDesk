import UIKit
#if DEBUG
/// Test steps for the Simulator, from the launch argument `-iDeskScript "app:YouTube; wait:8; focus:Settings"`:
/// `app:<name>` opens an installed iOS app, `focus:<title>` raises the window whose title starts with it,
/// `page:apps|settings|files` opens one of iDesk's pages, `wait:<seconds>` pauses; also `open:<url>`, `spotlight`,
/// `clipboard`, `area`, `shot`, `sticky`, `ontop`, `hot:on`, `type:<text>`, `copy:<text>`, `key:enter|esc|back|up|down`,
/// `snapkey:left|right|up|down`, `move:x,y`, `click:x,y`, `rclick:x,y`, `press:x,y`, `release`, `max`, `scroll:<dy>`. Each step is logged with "[iDesk-script]".
enum DebugScript {
    private static var started = false

    static func runIfRequested(_ model: DesktopModel) {
        let args = ProcessInfo.processInfo.arguments
        guard !started, let i = args.firstIndex(of: "-iDeskScript"), i + 1 < args.count else { return }
        started = true
        let steps = args[i + 1].split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        run(steps[...], model, after: 3)
    }

    private static func run(_ steps: ArraySlice<String>, _ model: DesktopModel, after delay: TimeInterval) {
        guard let step = steps.first else { NSLog("[iDesk-script] done"); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let parts = step.split(separator: ":", maxSplits: 1).map(String.init)
            let arg = parts.count > 1 ? parts[1] : ""
            var next: TimeInterval = 0.5
            switch parts[0] {
            case "app":
                if let app = GuestStore.shared.apps.first(where: { $0.name == arg }) { model.openApp(app) }
                else { NSLog("[iDesk-script] no app %@", arg) }
            case "focus":
                if let w = model.windows.last(where: { $0.title.hasPrefix(arg) }) { model.focus(w) }
                else { NSLog("[iDesk-script] no window %@", arg) }
            case "page":
                if let page = [DesktopPage.apps, .settings, .files].first(where: { "\($0)" == arg }) { model.openPage(page) }
            case "scroll":
                model.cursor.position = CGPoint(x: model.screenSize.width / 2, y: model.screenSize.height / 2)
                model.scroll(dx: 0, dy: CGFloat(Double(arg) ?? 300))
            case "open": model.openWindow(arg)
            case "spotlight": model.toggleSpotlight()
            case "clipboard": model.toggleClipboard()
            case "area": model.startAreaCapture()
            case "shot": model.takeScreenshot()
            case "sticky": model.newSticky()
            case "ontop": if let w = model.focused { model.toggleKeepOnTop(w) }
            case "hot": model.hotCorners = arg == "on"
            case "type": model.typeText(arg)
            case "copy": ClipboardHistory.shared.copy(arg)
            case "key":
                switch arg {
                case "enter": model.pressEnter()
                case "esc": model.escape()
                case "back": model.backspace()
                case "up": model.sendKey("ArrowUp", 38, false)
                case "down": model.sendKey("ArrowDown", 40, false)
                default: break
                }
            case "snapkey":
                let d: [String: DesktopModel.Direction] = ["left": .left, "right": .right, "up": .up, "down": .down]
                if let dir = d[arg] { model.snapFocused(dir) }
            case "move", "click", "rclick", "press":
                let xy = arg.split(separator: ",").compactMap { Double($0) }
                if xy.count == 2 {
                    let c = model.cursor.position
                    model.moveCursor(dx: CGFloat(xy[0]) - c.x, dy: CGFloat(xy[1]) - c.y)
                }
                if parts[0] == "click" { model.click() }
                if parts[0] == "rclick" { model.rightClick() }
                if parts[0] == "press" { model.mouseDown() }
            case "release": model.mouseUp()
            case "max":
                if let w = model.focused { model.toggleMaximize(w) }
            case "wait":
                next = Double(arg) ?? 1
            default:
                NSLog("[iDesk-script] unknown step %@", step)
            }
            NSLog("[iDesk-script] %@", step)
            run(steps.dropFirst(), model, after: next)
        }
    }
}
#endif
