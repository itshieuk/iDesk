import SwiftUI

/// iPhone UI: address bar, control buttons, trackpad, compose field.
struct ControllerView: View {
    @ObservedObject var model: DesktopModel
    @ObservedObject private var devices = MouseInput.shared
    @State private var address = ""
    @State private var compose = ""
    @State private var liveTyping = false
    @State private var showApps = false
    @State private var showSettings = false
    /// Mouse mode: iPhone held in landscape, the whole screen mirrors the desktop for the AssistiveTouch pointer.
    @State private var mouseMode = false
    @State private var assistiveTouch = UIAccessibility.isAssistiveTouchRunning
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @FocusState private var field: Field?

    private enum Field { case address, compose }

    var body: some View {
        ZStack {
            // Keep the key catcher outermost so switching modes does not lose the keyboard.
            KeyCapture(isActive: $liveTyping, model: model)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityHidden(true)
            if landscape {
                trackpadArea          // landscape: the trackpad fills the screen
            } else {
                VStack(spacing: 10) {
                    header
                    addressBar
                    toolbar
                    trackpadArea
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    composeBar
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onChange(of: field) { _, f in
            if f != nil { liveTyping = false }
            updateKeyboardMode()
        }
        .onChange(of: liveTyping) { _, _ in updateKeyboardMode() }
        .onChange(of: showApps) { _, _ in updateKeyboardMode() }
        .onChange(of: showSettings) { _, _ in updateKeyboardMode() }
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.assistiveTouchStatusDidChangeNotification)) { _ in
            assistiveTouch = UIAccessibility.isAssistiveTouchRunning
        }
        .sheet(isPresented: $showApps) { AppsSheet(model: model) }
        .sheet(isPresented: $showSettings) { SettingsSheet(model: model) }
        .alert("iDesk", isPresented: Binding(get: { model.notice != nil && !showApps && !showSettings },
                                             set: { if !$0 { model.notice = nil } })) {
            let text = model.notice ?? ""
            Button("Copy error") { UIPasteboard.general.string = text }
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.notice ?? "")
        }
    }

    private var landscape: Bool { mouseMode || verticalSizeClass == .compact }

    /// The trackpad shows a mirror of the desktop (click where you point) in mouse mode or while
    /// AssistiveTouch is running; otherwise it is a regular trackpad.
    private var mirrorOn: Bool { mouseMode || assistiveTouch }

    private var trackpadArea: some View {
        ZStack(alignment: .topTrailing) {
            TrackpadSurface(mirrorMode: mirrorOn)
            if !(mirrorOn && model.isExternalConnected) {
                trackpadHint.allowsHitTesting(false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack(spacing: 0) {
                roundButton(symbol: "gearshape", label: "Settings",
                            hint: "Brightness, wallpaper, pointer speed") { showSettings = true }
                roundButton(symbol: mouseMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                            label: mouseMode ? "Exit mouse mode" : "Mouse mode",
                            hint: "Turns the iPhone landscape and fills the screen with the desktop to point at") {
                    field = nil
                    mouseMode.toggle()
                    PhoneHostingController.setLandscape(mouseMode)
                }
            }
        }
        // Portrait: a gray pad framed in black. Landscape: the pad is the whole screen, pure black like the rest.
        .background((landscape ? Color.black : Color(white: 0.13)).ignoresSafeArea())
    }

    private func roundButton(symbol: String, label: LocalizedStringKey, hint: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 44, height: 44)
                .background(Circle().fill(landscape ? Color(white: 0.16) : Color.black.opacity(0.5)).padding(4))
        }
        .accessibilityLabel(label)
        .accessibilityHint(hint)
        .padding(4)
    }

    /// Tell PhoneWindow where hardware key presses should go.
    private func updateKeyboardMode() {
        // A sheet with text fields (e.g. a password) is open: let keys go there.
        PhoneWindow.mode = (field != nil || showApps || showSettings) ? .off : liveTyping ? .special : .all
        if PhoneWindow.mode == .all { PhoneWindow.current?.claimKeyboard() }
    }

    private var header: some View {
        VStack(spacing: 4) {
        HStack {
            Image(systemName: model.isExternalConnected ? "display" : "display.trianglebadge.exclamationmark")
                .foregroundStyle(model.isExternalConnected ? .green : .orange)
            Text(model.isExternalConnected ? "External display connected" : "No external display")
                .font(.subheadline.weight(.medium))
            Spacer()
            Text("\(model.windows.count) windows").font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        deviceStatus
        }
    }

    /// Shows whether a real mouse / keyboard is being received.
    private var deviceStatus: some View {
        HStack(spacing: 14) {
            Label(mouseText, systemImage: "computermouse")
                .foregroundStyle(devices.mouseActive ? .green : devices.mouseConnected ? .orange : .secondary)
            Label(devices.keyboardConnected ? "Keyboard: connected" : "Keyboard: none",
                  systemImage: "keyboard")
                .foregroundStyle(devices.keyboardConnected ? .green : .secondary)
            Spacer()
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
    }

    private var mouseText: String {
        switch devices.source {
        case .gameController: return String(localized: "Mouse: working (GameController)")
        case .assistiveTouch: return String(localized: "Mouse: working (AssistiveTouch)")
        case .none:
            return devices.mouseConnected ? String(localized: "Mouse: detected, try moving it") : String(localized: "Mouse: not detected, see the guide")
        }
    }

    private var addressBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Enter an address or search", text: $address)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .focused($field, equals: .address)
                .onSubmit {
                    model.navigate(address)
                    address = ""
                }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.16)))
        .disabled(!model.isExternalConnected)
        .opacity(model.isExternalConnected ? 1 : 0.4)
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            // No external display yet: desktop controls are disabled, only app/certificate management works.
            Group {
                toolButton("chevron.left", "Back") { model.goBack() }
                toolButton("chevron.right", "Forward") { model.goForward() }
                toolButton("arrow.clockwise", "Reload") { model.reload() }
                toolButton("square.grid.2x2", "Start menu") { model.toggleLauncher() }
                toolButton("plus.square.on.square", "New window") { model.openWindow("https://www.google.com") }
            }
            .disabled(!model.isExternalConnected)
            toolButton("shippingbox", "Apps from IPA") {
                field = nil
                showApps = true
            }
            Group {
                toolButton("xmark.square", "Close window") { model.closeFocused() }
                toolButton(liveTyping ? "keyboard.fill" : "keyboard", liveTyping ? "Stop live typing" : "Live typing") {
                    field = nil
                    liveTyping.toggle()
                }
            }
            .disabled(!model.isExternalConnected)
        }
    }

    private func toolButton(_ symbol: String, _ label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 44)   // touch target ≥ 44pt
        }
        .accessibilityLabel(label)
    }

    private var trackpadHint: some View {
        VStack(spacing: 6) {
            if model.isExternalConnected {
                Text("Trackpad").font(.headline)
                Text("1 finger: move · Tap: click · Double tap: double-click\nTwo-finger tap: right-click · Two-finger drag: scroll\nHold, then drag: move / resize windows")
                    .multilineTextAlignment(.center)
                Text("Using a mouse? Tap the corner button for mouse mode (landscape, point straight at the desktop).")
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            } else {
                Image(systemName: "cable.connector").font(.largeTitle)
                Text("Connect the iPhone to a display with a USB-C → HDMI/DisplayPort cable")
                    .multilineTextAlignment(.center)
            }
        }
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.35))
        .padding()
    }

    /// Compose field: full IME support (e.g. Vietnamese Telex/VNI); Send types the text into the page.
    private var composeBar: some View {
        HStack(spacing: 8) {
            TextField("Type text to send to the page", text: $compose)
                .focused($field, equals: .compose)
                .submitLabel(.send)
                .onSubmit { sendCompose(withEnter: true) }
            Button { sendCompose(withEnter: false) } label: {
                Image(systemName: "paperplane.fill").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Send text")
            .disabled(compose.isEmpty)
        }
        .padding(.leading, 12)
        .frame(height: 44)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.16)))
        .disabled(!model.isExternalConnected)
        .opacity(model.isExternalConnected ? 1 : 0.4)
    }

    private func sendCompose(withEnter: Bool) {
        if !compose.isEmpty { model.typeText(compose) }
        if withEnter { model.pressEnter() }
        compose = ""
    }
}
