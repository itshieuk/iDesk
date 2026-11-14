import GameController
import Combine
import QuartzCore

/// A real mouse (Bluetooth/USB) via GameController. iOS shows no system pointer on the iPhone's
/// external display, so the app reads raw motion and draws its own pointer.
/// Note: on iPhone, whether GCMouse delivers data depends on the iOS version.
/// If it does not, AssistiveTouch provides the fallback path in TrackpadView.
final class MouseInput: ObservableObject {
    static let shared = MouseInput()
    var scrollSpeed: CGFloat = 12

    enum Source { case none, gameController, assistiveTouch }

    @Published private(set) var mouseConnected = false
    @Published private(set) var mouseActive = false      // actually received mouse data
    @Published private(set) var source: Source = .none   // which path the mouse input arrives through
    @Published private(set) var keyboardConnected = false

    /// Last GCMouse event; used to avoid handling the same input twice with the fallback path.
    private(set) var lastEvent: CFTimeInterval = 0
    var recentlyActive: Bool { CACurrentMediaTime() - lastEvent < 0.4 }

    /// Called by TrackpadView when the indirect pointer (mouse via AssistiveTouch) is active.
    func indirectPointerSeen() {
        if source != .gameController {
            source = .assistiveTouch
            mouseConnected = true
            mouseActive = true
        }
    }

    func start() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: .GCMouseDidConnect, object: nil, queue: .main) { [weak self] note in
            guard let mouse = note.object as? GCMouse else { return }
            self?.attach(mouse)
            self?.refresh()
        }
        nc.addObserver(forName: .GCMouseDidDisconnect, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
        nc.addObserver(forName: .GCKeyboardDidConnect, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
        nc.addObserver(forName: .GCKeyboardDidDisconnect, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
        GCMouse.mice().forEach(attach)
        refresh()
    }

    private func refresh() {
        let hasGC = !GCMouse.mice().isEmpty
        if hasGC { mouseConnected = true }
        else if source != .assistiveTouch { mouseConnected = false }
        keyboardConnected = GCKeyboard.coalesced != nil
    }

    private func touch() {
        lastEvent = CACurrentMediaTime()
        source = .gameController
        mouseConnected = true
        if !mouseActive { mouseActive = true }
    }

    private func attach(_ mouse: GCMouse) {
        guard let input = mouse.mouseInput else { return }
        let model = DesktopModel.shared

        input.mouseMovedHandler = { [weak self] _, dx, dy in
            DispatchQueue.main.async {
                self?.touch()
                // GameController's Y axis points up, the screen's points down.
                let k = InputSettings.pointerSpeed / CGFloat(InputSettings.defaultPointer)
                model.moveCursor(dx: CGFloat(dx) * k, dy: CGFloat(-dy) * k)
            }
        }
        input.leftButton.pressedChangedHandler = { [weak self] _, _, pressed in
            DispatchQueue.main.async {
                self?.touch()
                if pressed { model.physicalPress() } else { model.physicalRelease() }
            }
        }
        input.rightButton?.pressedChangedHandler = { [weak self] _, _, pressed in
            DispatchQueue.main.async {
                self?.touch()
                if pressed { model.rightClick() }
            }
        }
        input.scroll.valueChangedHandler = { [weak self] _, x, y in
            let speed = (self?.scrollSpeed ?? 12) * InputSettings.scrollSpeed / CGFloat(InputSettings.defaultScroll)
            DispatchQueue.main.async {
                self?.touch()
                model.scroll(dx: CGFloat(x) * speed, dy: CGFloat(-y) * speed)
            }
        }
    }
}
