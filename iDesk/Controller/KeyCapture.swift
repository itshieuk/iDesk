import UIKit
import SwiftUI

/// Invisible view that receives keys (Bluetooth or on-screen keyboard) and sends each character
/// to the focused field of the web page on the external display.
final class KeyCaptureView: UIView, UIKeyInput {
    var onInsert: (String) -> Void = { _ in }
    var onDelete: () -> Void = {}

    var autocorrectionType: UITextAutocorrectionType = .no
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var spellCheckingType: UITextSpellCheckingType = .no
    var smartQuotesType: UITextSmartQuotesType = .no

    override var canBecomeFirstResponder: Bool { true }
    var hasText: Bool { true }
    func insertText(_ text: String) { onInsert(text) }
    func deleteBackward() { onDelete() }
}

struct KeyCapture: UIViewRepresentable {
    @Binding var isActive: Bool
    let model: DesktopModel

    func makeUIView(context: Context) -> KeyCaptureView {
        let v = KeyCaptureView()
        v.onInsert = { text in
            if text == "\n" { model.pressEnter() } else { model.typeText(text) }
        }
        v.onDelete = { model.backspace() }
        return v
    }

    func updateUIView(_ v: KeyCaptureView, context: Context) {
        let active = isActive
        DispatchQueue.main.async {
            if active, !v.isFirstResponder { v.becomeFirstResponder() }
            if !active, v.isFirstResponder {
                v.resignFirstResponder()
                PhoneWindow.current?.claimKeyboard()
            }
        }
    }
}

// MARK: - Hardware keyboard (Bluetooth / USB)

/// The iPhone screen's window. When no text field is focused it becomes first responder itself
/// to receive hardware key presses and forward them to the page on the external display.
/// It does not adopt UIKeyInput, so the on-screen keyboard does not appear.
final class PhoneWindow: UIWindow {
    enum Mode {
        case all        // handle every key
        case special    // "live typing": text goes through KeyCaptureView, only special keys here
        case off        // typing into a field on the iPhone: leave keys alone
    }

    static weak var current: PhoneWindow?
    static var mode: Mode = .all

    private let model = DesktopModel.shared
    private var repeatTimer: Timer?
    private var repeatKey: UIKeyboardHIDUsage?
    /// The Win / ⌘ key went down and nothing else has been pressed since: releasing it opens the Start menu.
    private var winKeyAlone = false

    private static func isWinKey(_ code: UIKeyboardHIDUsage?) -> Bool {
        code == .keyboardLeftGUI || code == .keyboardRightGUI
    }

    private static func isAltKey(_ code: UIKeyboardHIDUsage?) -> Bool {
        code == .keyboardLeftAlt || code == .keyboardRightAlt
    }

    override var canBecomeFirstResponder: Bool { true }

    func claimKeyboard() {
        guard Self.mode == .all else { return }
        DispatchQueue.main.async { if !self.isFirstResponder { self.becomeFirstResponder() } }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        winKeyAlone = presses.count == 1 && Self.isWinKey(presses.first?.key?.keyCode)
        var unhandled = Set<UIPress>()
        for press in presses {
            guard let key = press.key, Self.mode != .off, handle(key) else { unhandled.insert(press); continue }
        }
        if !unhandled.isEmpty { super.pressesBegan(unhandled, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.key?.keyCode == repeatKey }) { stopRepeat() }
        let codes = presses.map { $0.key?.keyCode }
        // Releasing the modifier of Alt+Tab / Win+Tab switches to the selected window.
        if codes.contains(where: { Self.isWinKey($0) || Self.isAltKey($0) }) { model.commitSwitcher() }
        if winKeyAlone, Self.mode != .off, codes.contains(where: { Self.isWinKey($0) }) { model.toggleLauncher() }
        winKeyAlone = false
        super.pressesEnded(presses, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        stopRepeat()
        super.pressesCancelled(presses, with: event)
    }

    /// Returns true if the key was handled.
    private func handle(_ key: UIKey) -> Bool {
        let flags = key.modifierFlags
        let command = flags.contains(.command) || flags.contains(.control)
        let shift = flags.contains(.shift)
        let chars = key.charactersIgnoringModifiers.lowercased()

        // Desktop-style shortcuts
        if command {
            switch chars {
            case "t", "n": model.newBrowserWindow(); return true
            case "l": model.focusAddressBar(); return true
            case "w": model.closeFocused(); return true
            case "r": model.reload(); return true
            case "[": model.goBack(); return true
            case "]": model.goForward(); return true
            case "a": model.selectAll(); return true
            case "c": model.copySelection(); return true
            case "v": if Self.mode == .all { model.paste(); return true }
            case "d": model.toggleShowDesktop(); return true
            case "m": model.minimizeFocused(); return true
            default: break
            }
            if key.keyCode == .keyboardTab { model.cycleWindows(); return true }
            // Win (⌘) + arrows arrange the window, as on Windows / Samsung DeX; Ctrl + ← / → go back / forward.
            let win = flags.contains(.command)
            switch key.keyCode {
            case .keyboardLeftArrow: if win { model.snapFocused(.left) } else { model.goBack() }; return true
            case .keyboardRightArrow: if win { model.snapFocused(.right) } else { model.goForward() }; return true
            case .keyboardUpArrow where win: model.snapFocused(.up); return true
            case .keyboardDownArrow where win: model.snapFocused(.down); return true
            default: return false
            }
        }
        if flags.contains(.alternate) {
            switch key.keyCode {
            case .keyboardTab: model.cycleWindows(); return true
            case .keyboardLeftArrow: model.goBack(); return true        // as in browsers on Windows
            case .keyboardRightArrow: model.goForward(); return true
            default: break
            }
        }

        switch key.keyCode {
        case .keyboardEscape:
            model.escape(); return true
        case .keyboardLeftArrow: special(key, "ArrowLeft", 37, shift); return true
        case .keyboardRightArrow: special(key, "ArrowRight", 39, shift); return true
        case .keyboardUpArrow: special(key, "ArrowUp", 38, shift); return true
        case .keyboardDownArrow: special(key, "ArrowDown", 40, shift); return true
        case .keyboardPageUp: model.sendKey("PageUp", 33, shift); return true
        case .keyboardPageDown: model.sendKey("PageDown", 34, shift); return true
        case .keyboardHome: model.sendKey("Home", 36, shift); return true
        case .keyboardEnd: model.sendKey("End", 35, shift); return true
        case .keyboardDeleteForward: special(key, "Delete", 46, shift); return true
        default: break
        }

        // From here on, text keys: in "live typing" mode KeyCaptureView handles them.
        guard Self.mode == .all else { return false }
        switch key.keyCode {
        case .keyboardReturnOrEnter, .keypadEnter:
            model.pressEnter(); return true
        case .keyboardDeleteOrBackspace:
            model.backspace()
            startRepeat(key) { [weak self] in self?.model.backspace() }
            return true
        case .keyboardTab:
            model.sendKey("Tab", 9, shift); return true
        default:
            let text = key.characters
            guard !text.isEmpty, !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return false }
            model.typeText(text)
            return true
        }
    }

    private func special(_ key: UIKey, _ name: String, _ code: Int, _ shift: Bool) {
        model.sendKey(name, code, shift)
        startRepeat(key) { [weak self] in self?.model.sendKey(name, code, shift) }
    }

    /// Holding a key (delete, arrows) repeats it like on a computer.
    private func startRepeat(_ key: UIKey, _ action: @escaping () -> Void) {
        stopRepeat()
        repeatKey = key.keyCode
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            self?.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in action() }
        }
    }

    private func stopRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        repeatKey = nil
    }
}
