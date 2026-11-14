import SwiftUI
import WebKit

enum Wallpapers {
    static let all: [[Color]] = [
        [Color(red: 0.06, green: 0.10, blue: 0.22), Color(red: 0.18, green: 0.10, blue: 0.30), Color(red: 0.05, green: 0.22, blue: 0.30)],
        [Color(red: 0.95, green: 0.45, blue: 0.30), Color(red: 0.55, green: 0.18, blue: 0.45), Color(red: 0.15, green: 0.10, blue: 0.35)],
        [Color(red: 0.05, green: 0.25, blue: 0.20), Color(red: 0.10, green: 0.45, blue: 0.40), Color(red: 0.02, green: 0.12, blue: 0.18)],
        [Color(red: 0.20, green: 0.45, blue: 0.85), Color(red: 0.45, green: 0.30, blue: 0.85), Color(red: 0.10, green: 0.20, blue: 0.50)],
        [Color(red: 0.12, green: 0.12, blue: 0.14), Color(red: 0.22, green: 0.22, blue: 0.26), Color(red: 0.08, green: 0.08, blue: 0.10)],
    ]
    static var count: Int { all.count }
}

/// The whole UI on the external display.
struct DesktopView: View {
    @ObservedObject var model: DesktopModel

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                WallpaperView(index: model.wallpaper, image: model.customWallpaper)
                    .frame(width: geo.size.width, height: geo.size.height)

                DesktopIconsView(model: model, cursor: model.cursor)

                if model.showWidgets {
                    WidgetsView()
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topTrailing)
                }

                ForEach(model.windows) { w in
                    WindowView(window: w, focused: w.id == model.focusedID, cursor: model.cursor)
                }

                if let r = model.snapPreview {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.5), lineWidth: 2))
                        .frame(width: r.width, height: r.height)
                        .offset(x: r.minX, y: r.minY)
                }

                if model.showLauncher {
                    LauncherView(model: model, cursor: model.cursor)
                }

                if model.taskbarVisible {
                    TaskbarView(model: model, cursor: model.cursor)
                        .frame(width: geo.size.width, height: Layout.taskbar)
                        .offset(y: geo.size.height - Layout.taskbar)
                        .transition(.move(edge: .bottom))
                }

                if let preview = model.taskPreview, model.taskbarVisible {
                    TaskPreviewView(preview: preview, screenWidth: geo.size.width, taskbarTop: model.taskbarTop)
                }

                if let switcher = model.switcher {
                    SwitcherView(model: model, switcher: switcher)
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                if let recents = model.recents {
                    RecentsView(model: model, recents: recents, cursor: model.cursor)
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                if model.showQuickPanel {
                    QuickPanelView(model: model, cursor: model.cursor)
                }

                if let banner = model.banner {
                    NotificationCard(notification: banner)
                        .frame(width: model.bannerRect.width, height: model.bannerRect.height)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 14, y: 4)
                        .offset(x: model.bannerRect.minX, y: model.bannerRect.minY)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                if model.showShortcuts {
                    ShortcutsView()
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                if let menu = model.contextMenu {
                    ContextMenuView(menu: menu, cursor: model.cursor)
                }

                if let toast = model.toast {
                    Text(toast)
                        .font(.system(size: 14, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                        .frame(maxWidth: min(560, geo.size.width - 32))
                        .padding(.top, 24)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                        .allowsHitTesting(false)
                }

                CursorView(cursor: model.cursor)
                    .opacity(model.cursor.isHidden ? 0 : 1)

                if model.externalBrightness < 0.99 {
                    Color.black.opacity(1 - model.externalBrightness)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .onAppear { model.screenSize = geo.size }
            .onChange(of: geo.size) { _, newSize in model.screenSize = newSize }
        }
        .ignoresSafeArea()
        // No allowsHitTesting(false) here: it disables interaction on a parent view, and UIKit then ignores
        // actions inside guest apps (see GuestWindowHost). The external display receives no touches anyway.
        .preferredColorScheme(.dark)
    }
}

struct WallpaperView: View {
    let index: Int
    var image: UIImage?
    var watermark = true

    var body: some View {
        if index < 0, let image {
            Image(uiImage: image).resizable().scaledToFill().clipped()
        } else {
            LinearGradient(colors: Wallpapers.all[max(0, index) % Wallpapers.count],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(alignment: .center) {
                    if watermark {
                        Text("iDesk")
                            .font(.system(size: 96, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.06))
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: index)
        }
    }
}

private struct AppIcon: View {
    let shortcut: Shortcut
    let size: CGFloat

    var body: some View {
        if let icon = shortcut.app?.icon {
            Image(uiImage: icon)
                .resizable()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(LinearGradient(colors: [Color(hue: shortcut.hue, saturation: 0.65, brightness: 0.95),
                                          Color(hue: shortcut.hue, saturation: 0.8, brightness: 0.65)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay(Image(systemName: shortcut.symbol)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white))
            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
    }
}

// MARK: - Desktop icons

private struct DesktopIconsView: View {
    @ObservedObject var model: DesktopModel
    @ObservedObject var cursor: CursorModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(model.items.enumerated()), id: \.offset) { i, s in
                let r = model.iconRect(i)
                let hovered = r.contains(cursor.position) && model.topWindow(at: cursor.position) == nil
                let selected = model.selectedIcon == i
                VStack(spacing: 6) {
                    AppIcon(shortcut: s, size: 48)
                    Text(s.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.8), radius: 2)
                }
                .frame(width: r.width, height: r.height)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Color.accentColor.opacity(0.35) : hovered ? Color.white.opacity(0.1) : .clear))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Color.accentColor.opacity(0.7) : .clear, lineWidth: 1))
                .offset(x: r.minX, y: r.minY)
            }
        }
    }
}

// MARK: - Windows

private struct WindowView: View {
    @ObservedObject var window: DeskWindow
    let focused: Bool
    let cursor: CursorModel

    var body: some View {
        let f = window.frame
        let radius: CGFloat = window.isFullscreen ? 0 : window.isMaximized ? 6 : 10
        VStack(spacing: 0) {
            if !window.isFullscreen {
                TitleBar(title: window.title, focused: focused, frame: f, cursor: cursor,
                         tabs: window.webView == nil ? nil : window.tabs.indices.map { window.title(ofTab: $0) },
                         activeTab: window.activeTab)
                    .frame(height: Layout.titleBar)
                if window.webView != nil {
                    AddressBar(window: window, focused: focused, cursor: cursor)
                        .frame(height: Layout.addressBar)
                }
            }
            if let guest = window.guestWindow {
                GuestWindowHost(guest: guest, hidden: !window.isShown) { on in window.onFullscreen?(on) }
            } else if let web = window.webView {
                WebViewHost(webView: web).id(ObjectIdentifier(web))     // another tab: another web view
            }
        }
        .frame(width: f.width, height: f.height)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(focused ? Color.accentColor.opacity(0.7) : Color.white.opacity(0.12),
                        lineWidth: window.isFullscreen ? 0 : 1)
        )
        .shadow(color: .black.opacity(focused ? 0.5 : 0.25), radius: focused ? 24 : 10, y: 8)
        .offset(x: f.minX, y: f.minY)
        .opacity(window.isShown ? 1 : 0)   // keep the web view alive while minimized or on another workspace
    }
}

private struct TitleBar: View {
    let title: String
    let focused: Bool
    let frame: CGRect
    let cursor: CursorModel
    /// Tab titles of a web window (nil for an app window, which shows its name instead).
    var tabs: [String]? = nil
    var activeTab = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(focused ? Color(white: 0.2) : Color(white: 0.15))
            HStack {
                TitleButtons(frame: frame, focused: focused, cursor: cursor)
                Spacer()
            }
            .padding(.leading, 12)
            .frame(maxHeight: .infinity)
            if let tabs {
                TabStrip(titles: tabs, active: activeTab, focused: focused, frame: frame, cursor: cursor)
            } else {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(focused ? .primary : .secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 90)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// A browser window's tabs, as in a desktop browser: the one shown is lighter, × closes, + opens a new one.
private struct TabStrip: View {
    let titles: [String]
    let active: Int
    let focused: Bool
    let frame: CGRect
    @ObservedObject var cursor: CursorModel

    var body: some View {
        let n = titles.count, p = cursor.position
        ZStack(alignment: .topLeading) {
            ForEach(titles.indices, id: \.self) { i in
                let r = Layout.tabRect(i, count: n, in: frame)
                let hovered = r.contains(p)
                let closeHovered = Layout.tabCloseRect(i, count: n, in: frame).insetBy(dx: -3, dy: -3).contains(p)
                HStack(spacing: 6) {
                    Text(titles[i]).font(.system(size: 12, weight: i == active ? .semibold : .regular)).lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.white.opacity(closeHovered ? 0.25 : 0)))
                        .opacity(i == active || hovered ? 1 : 0)
                }
                .padding(.leading, 10).padding(.trailing, 4)
                .frame(width: r.width, height: r.height)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(i == active ? Color.white.opacity(focused ? 0.16 : 0.1) : hovered ? Color.white.opacity(0.07) : .clear))
                .foregroundStyle(Color.white.opacity(i == active ? 1 : 0.62))
                .offset(x: r.minX - frame.minX, y: r.minY - frame.minY)
            }
            let plus = Layout.newTabRect(count: n, in: frame)
            Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                .frame(width: plus.width, height: plus.height)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(plus.contains(p) ? 0.14 : 0)))
                .offset(x: plus.minX - frame.minX, y: plus.minY - frame.minY)
        }
    }
}

/// A web window's back / forward / reload buttons and address field. Clicking the field (or ⌘L) starts typing:
/// keys, the iPhone's compose field and paste go into it, Enter opens the address, Esc cancels.
private struct AddressBar: View {
    @ObservedObject var window: DeskWindow
    let focused: Bool
    @ObservedObject var cursor: CursorModel

    var body: some View {
        let f = window.frame, p = cursor.position
        HStack(spacing: 4) {
            button("chevron.left", enabled: window.canGoBack, hovered: Layout.backButton(in: f).contains(p))
            button("chevron.right", enabled: window.canGoForward, hovered: Layout.forwardButton(in: f).contains(p))
            button(window.isLoading ? "xmark" : "arrow.clockwise", enabled: true, hovered: Layout.reloadButton(in: f).contains(p))
            field(hovered: Layout.addressField(in: f).contains(p))
                .padding(.leading, 4)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(focused ? Color(white: 0.17) : Color(white: 0.13))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1) }
    }

    private func button(_ symbol: String, enabled: Bool, hovered: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.5))
            .frame(width: 28, height: 28)
            .background(RoundedRectangle(cornerRadius: 6).fill(hovered && enabled ? Color.white.opacity(0.12) : .clear))
    }

    private func field(hovered: Bool) -> some View {
        let editing = window.addressDraft != nil
        return HStack(spacing: 6) {
            Image(systemName: window.currentURL.scheme == "https" ? "lock.fill" : "globe")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            if let draft = window.addressDraft {
                if draft.isEmpty {
                    Text("Type an address or search").foregroundStyle(.secondary)
                        + Text(verbatim: "|").foregroundColor(.accentColor)
                } else {
                    Text(verbatim: draft) + Text(verbatim: "|").foregroundColor(.accentColor)
                }
            } else {
                Text(verbatim: Self.shown(window.currentURL)).foregroundStyle(.white.opacity(focused ? 0.85 : 0.6))
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 12.5))
        .lineLimit(1)
        .truncationMode(.head)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(editing ? Color.black.opacity(0.35) : hovered ? Color.white.opacity(0.1) : Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(editing ? Color.accentColor : .clear, lineWidth: 1.5))
    }

    /// The address without "https://" and a trailing slash, as browsers show it.
    private static func shown(_ url: URL) -> String {
        var s = url.absoluteString
        for prefix in ["https://", "http://"] where s.hasPrefix(prefix) { s.removeFirst(prefix.count) }
        if s.hasSuffix("/") { s.removeLast() }
        return s
    }
}

/// Three round buttons; symbols appear when the pointer hovers (like macOS).
private struct TitleButtons: View {
    let frame: CGRect
    let focused: Bool
    @ObservedObject var cursor: CursorModel

    var body: some View {
        let hovered = Layout.titleButtons(in: frame).contains(cursor.position)
        let active = focused || hovered
        HStack(spacing: 6) {
            dot(.red, "xmark", 8, active, hovered)
            dot(.yellow, "minus", 8, active, hovered)
            dot(.green, "arrow.up.left.and.arrow.down.right", 7, active, hovered)
        }
    }

    private func dot(_ c: Color, _ symbol: String, _ size: CGFloat, _ active: Bool, _ hovered: Bool) -> some View {
        Circle().fill(active ? c : Color(white: 0.35))
            .frame(width: 16, height: 16)
            .overlay(Image(systemName: symbol)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.black.opacity(0.6))
                .opacity(hovered ? 1 : 0))
    }
}

private struct WebViewHost: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// Shows a guest app's window inside a desktop window.
///
/// The guest window stays an independent UIWindow at the origin; here we only "project" its image
/// (portal). Two simpler approaches were tried and both broke:
/// - adding the UIWindow as a subview: the guest's views treat iDesk's window as their own, so alerts and
///   sheets cover the whole screen and the desktop pointer cannot reach them;
/// - adding its layer here: "window → screen" conversions then return desktop positions that do not match
///   the touch coordinates, so SwiftUI buttons ignore taps.
private struct GuestWindowHost: UIViewRepresentable {
    let guest: UIWindow
    let hidden: Bool
    /// The app wants landscape (fullscreen video) or no longer does.
    let onLandscape: (Bool) -> Void

    func makeUIView(context: Context) -> GuestContainerView { GuestContainerView() }

    func updateUIView(_ view: GuestContainerView, context: Context) {
        view.guest = guest
        view.isMinimized = hidden
        view.onLandscape = onLandscape
        view.attach()
    }

    static func dismantleUIView(_ view: GuestContainerView, coordinator: ()) {
        // Closing the desktop window: the guest app stays in the process (code cannot be unloaded), sent to the
        // background by DesktopModel.close.
        view.detach()
    }
}

final class GuestContainerView: UIView {
    var guest: UIWindow?
    var isMinimized = false
    var onLandscape: ((Bool) -> Void)?
    private var wantsLandscape = false
    /// One portal per window of the app (main window, overlays…), bottom to top.
    private var portals: [ObjectIdentifier: UIView] = [:]
    /// Windows that fill the app's screen (the main one, full-screen overlays): sized to the desktop window.
    /// Smaller ones (a HUD, a floating button) keep their own frame.
    private var fullScreen = Set<ObjectIdentifier>()
    private var watchdog: Timer?
    /// Shown until the app shows its first window (many apps create it a moment after launching).
    private let spinner = UIActivityIndicatorView(style: .large)

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        isUserInteractionEnabled = false
        spinner.color = .white
        spinner.hidesWhenStopped = true
        addSubview(spinner)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func attach() {
        guard let guest, window != nil else { return }
        // GuestRuntime keeps every window of the app below iDesk's own (solid black) window, so nothing of the
        // app shows on the iPhone screen; the user sees the projections here.
        let windows = isMinimized ? [] : GuestRuntime.windowsOfApp(with: guest)
        // Only on a change, so leaving fullscreen with Esc sticks until the app asks again.
        let landscape = GuestRuntime.appWantsLandscape(with: guest)
        if landscape != wantsLandscape {
            wantsLandscape = landscape
            DispatchQueue.main.async { [onLandscape] in onLandscape?(landscape) }
        }
        spinner.center = CGPoint(x: bounds.midX, y: bounds.midY)
        if windows.isEmpty && !isMinimized { spinner.startAnimating() } else { spinner.stopAnimating() }
        let size = bounds.size
        var alive = Set<ObjectIdentifier>()
        var ordered: [UIView] = []
        for w in windows {
            let id = ObjectIdentifier(w)
            alive.insert(id)
            if portals[id] == nil, w.frame.size == w.screen.bounds.size || w.frame.size == size {
                fullScreen.insert(id)
            }
            if fullScreen.contains(id), w.frame.size != size || w.frame.origin != .zero {
                w.frame = CGRect(origin: .zero, size: size)
            }
            // hidesSource: do not draw the window at its original place on the iPhone screen.
            if portals[id] == nil { portals[id] = Portal.make(of: w, hidesSource: true) }
            if let portal = portals[id] {
                ordered.append(portal)
                let frame = fullScreen.contains(id) ? bounds : w.frame
                if portal.frame != frame { portal.frame = frame }
            } else if w.layer.superlayer !== layer {
                // No portal available (iOS changed the private API): attach the layer directly and accept coordinate glitches.
                layer.addSublayer(w.layer)
            }
            cancelSafeArea(of: w)
        }
        for (id, portal) in portals where !alive.contains(id) {
            portal.removeFromSuperview()
            portals[id] = nil
            fullScreen.remove(id)
        }
        // Stack the portals like the app's windows; only touch the hierarchy when the order changed.
        if subviews.filter({ ordered.contains($0) }) != ordered || ordered.contains(where: { $0.superview !== self }) {
            ordered.forEach { addSubview($0) }
        }
        if watchdog == nil {
            // The app may open or close windows, swap its root view controller or show a window again.
            watchdog = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.attach() }
        }
    }

    /// A guest window belongs to the iPhone scene, so it gets insets for the notch / home indicator even
    /// though it is shown inside a desktop window. Cancel them with negative safe-area insets until they are 0.
    private func cancelSafeArea(of w: UIWindow) {
        guard let root = w.rootViewController, root.isViewLoaded else { return }
        let extra = root.view.safeAreaInsets
        guard extra != .zero else { return }
        let a = root.additionalSafeAreaInsets
        root.additionalSafeAreaInsets = UIEdgeInsets(top: a.top - extra.top, left: a.left - extra.left,
                                                     bottom: a.bottom - extra.bottom, right: a.right - extra.right)
    }

    func detach() {
        watchdog?.invalidate()
        watchdog = nil
        portals.values.forEach { $0.removeFromSuperview() }
        portals = [:]
        fullScreen = []
        guard let guest else { return }
        for w in GuestRuntime.windowsOfApp(with: guest) where w.layer.superlayer === layer { w.layer.removeFromSuperlayer() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        attach()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attach()
    }
}

// MARK: - Taskbar

private struct TaskbarView: View {
    @ObservedObject var model: DesktopModel
    @ObservedObject var cursor: CursorModel

    var body: some View {
        let p = cursor.position
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(model.showLauncher ? Color.accentColor.opacity(0.5)
                          : model.startButtonRect.contains(p) ? Color.white.opacity(0.16) : Color.white.opacity(0.08))
                    .frame(width: Layout.startWidth, height: Layout.buttonHeight)
                    .overlay(Image(systemName: "square.grid.2x2.fill").font(.system(size: 18)))

                Spacer().frame(width: Layout.navX - Layout.startX - Layout.startWidth)

                // Android's navigation buttons, as on Samsung DeX: Recent apps, Home, Back.
                HStack(spacing: Layout.navGap) {
                    navButton(.recents, "square.stack", active: model.recents != nil, p)
                    navButton(.home, "circle", active: false, p)
                    navButton(.back, "chevron.backward", active: false, p)
                }

                Spacer().frame(width: Layout.workspaceX - Layout.navX - 3 * Layout.navWidth - 2 * Layout.navGap)

                // Workspaces: the one shown is highlighted, a dot marks those with windows.
                HStack(spacing: 0) {
                    ForEach(0..<DesktopModel.workspaceCount, id: \.self) { n in
                        let current = n == model.workspace
                        let used = model.windows.contains { $0.workspace == n }
                        VStack(spacing: 2) {
                            Text(verbatim: "\(n + 1)")
                                .font(.system(size: 12, weight: current ? .bold : .medium).monospacedDigit())
                                .foregroundStyle(current ? Color.primary : Color.secondary)
                            Circle().fill(used ? Color.primary.opacity(current ? 0.9 : 0.5) : .clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(width: Layout.workspaceCell, height: 30)
                        .background(RoundedRectangle(cornerRadius: 6)
                            .fill(current ? Color.white.opacity(0.18)
                                  : model.workspaceCellRect(n).contains(p) ? Color.white.opacity(0.1) : .clear))
                    }
                }
                .frame(width: Layout.workspaceWidth, height: Layout.buttonHeight)

                Spacer().frame(width: Layout.taskItemX - Layout.workspaceX - Layout.workspaceWidth)

                ZStack(alignment: .leading) {
                    ForEach(Array(model.taskLayout.enumerated()), id: \.offset) { _, item in
                        let hovered = item.rect.contains(p)
                        Group {
                            if let w = item.entry.window {
                                TaskItem(window: w, focused: w.id == model.focusedID, width: item.rect.width,
                                         hovered: hovered)
                            } else if case let .pinned(shortcut, _) = item.entry {
                                PinnedItem(shortcut: shortcut, hovered: hovered)
                            }
                        }
                        .offset(x: item.rect.minX - Layout.taskItemX)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TrayView().frame(width: Layout.trayWidth, height: Layout.taskbar)

                // Right corner: show desktop
                Rectangle()
                    .fill(model.showDesktopRect.contains(p) ? Color.white.opacity(0.2) : Color.clear)
                    .overlay(alignment: .leading) { Rectangle().fill(Color.white.opacity(0.25)).frame(width: 1) }
                    .frame(width: Layout.showDesktopWidth, height: Layout.taskbar)
            }
            .padding(.leading, Layout.startX)
        }
    }

    private func navButton(_ b: DesktopModel.NavButton, _ symbol: String, active: Bool, _ p: CGPoint) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .frame(width: Layout.navWidth, height: Layout.buttonHeight)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(active ? Color.accentColor.opacity(0.5)
                      : model.navButtonRect(b).contains(p) ? Color.white.opacity(0.14) : .clear))
    }
}

/// A pinned app that is not open: its icon only (like the Samsung DeX taskbar).
private struct PinnedItem: View {
    let shortcut: Shortcut
    let hovered: Bool

    var body: some View {
        AppIcon(shortcut: shortcut, size: 26)
            .frame(width: Layout.pinnedWidth, height: Layout.buttonHeight)
            .background(RoundedRectangle(cornerRadius: 8).fill(hovered ? Color.white.opacity(0.12) : .clear))
    }
}

private struct TaskItem: View {
    @ObservedObject var window: DeskWindow
    let focused: Bool
    let width: CGFloat
    let hovered: Bool

    var body: some View {
        let active = focused && !window.isMinimized
        HStack(spacing: 8) {
            if let icon = window.guestApp?.icon {
                Image(uiImage: icon).resizable().frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                Image(systemName: window.isApp ? "app.fill" : "globe").font(.system(size: 13))
            }
            if width > 70 {
                Text(window.title).font(.system(size: 13)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: Layout.buttonHeight)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(active ? Color.white.opacity(0.18) : hovered ? Color.white.opacity(0.12) : Color.white.opacity(0.06)))
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(active ? Color.accentColor : Color.white.opacity(0.5))
                .frame(width: active ? 20 : 8, height: 3)
                .padding(.bottom, 2)
        }
        .opacity(window.isMinimized ? 0.6 : 1)
    }
}

/// System tray: network, battery, time and date.
private struct TrayView: View {
    @ObservedObject private var network = NetworkStatus.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 20)) { ctx in
            HStack(spacing: 14) {
                Image(systemName: network.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(network.kind == .offline ? Color.secondary : Color.primary)
                let level = UIDevice.current.batteryLevel
                if level >= 0 {
                    HStack(spacing: 4) {
                        Image(systemName: batterySymbol(level, UIDevice.current.batteryState))
                        Text("\(Int((level * 100).rounded()))%").font(.system(size: 12).monospacedDigit())
                    }
                }
                VStack(alignment: .trailing, spacing: 1) {
                    Text(ctx.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                    Text(ctx.date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func batterySymbol(_ level: Float, _ state: UIDevice.BatteryState) -> String {
        if state == .charging || state == .full { return "battery.100.bolt" }
        switch level {
        case 0.875...: return "battery.100"
        case 0.625...: return "battery.75"
        case 0.375...: return "battery.50"
        case 0.125...: return "battery.25"
        default: return "battery.0"
        }
    }
}

// MARK: - Menu Start

private struct LauncherView: View {
    @ObservedObject var model: DesktopModel
    @ObservedObject var cursor: CursorModel

    var body: some View {
        let r = model.launcherRect
        ZStack(alignment: .topLeading) {
            Text("Apps")
                .font(.system(size: 15, weight: .semibold))
                .offset(x: Layout.launcherPadding + 4, y: Layout.launcherPadding + 6)

            // Search: typing on the keyboard while the menu is open goes here.
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                if model.launcherQuery.isEmpty {
                    Text("Type to search").foregroundStyle(.secondary)
                } else {
                    Text(verbatim: model.launcherQuery) + Text(verbatim: "|").foregroundColor(.accentColor)
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(width: r.width - Layout.launcherPadding * 2, height: 30)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
            .offset(x: Layout.launcherPadding, y: Layout.launcherPadding + 34)

            if model.launcherItems.isEmpty {
                Text("No apps match").font(.system(size: 13)).foregroundStyle(.secondary)
                    .offset(x: Layout.launcherPadding + 4, y: Layout.launcherPadding + Layout.launcherHeader + 30)
            }

            ForEach(Array(model.launcherItems.enumerated()), id: \.offset) { i, s in
                let t = model.launcherItemRect(i)
                let hovered = t.contains(cursor.position)
                VStack(spacing: 8) {
                    AppIcon(shortcut: s, size: 40)
                    Text(s.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                }
                .frame(width: t.width, height: t.height)
                .background(RoundedRectangle(cornerRadius: 10).fill(hovered ? Color.white.opacity(0.14) : .clear))
                .offset(x: t.minX - r.minX, y: t.minY - r.minY)
            }
        }
        .frame(width: r.width, height: r.height, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 6)
        .offset(x: r.minX, y: r.minY)
    }
}

// MARK: - Alt+Tab switcher

private struct SwitcherView: View {
    @ObservedObject var model: DesktopModel
    let switcher: DesktopModel.Switcher

    var body: some View {
        let windows = switcher.ids.compactMap { id in model.windows.first { $0.id == id } }
        HStack(spacing: 12) {
            ForEach(Array(windows.enumerated()), id: \.element.id) { i, w in
                VStack(spacing: 10) {
                    Group {
                        if let icon = w.guestApp?.icon {
                            Image(uiImage: icon).resizable()
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.1))
                                .overlay(Image(systemName: w.isApp ? "app.fill" : "globe").font(.system(size: 26)))
                        }
                    }
                    .frame(width: 56, height: 56)
                    Text(w.title).font(.system(size: 12, weight: .medium)).lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(12)
                .frame(width: 132, height: 128)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(i == switcher.index ? Color.accentColor.opacity(0.45) : Color.clear))
                .opacity(w.isMinimized ? 0.6 : 1)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 8)
    }
}

// MARK: - Quick panel

/// Opened from the clock: quick toggles, external display brightness and the apps' notifications.
private struct QuickPanelView: View {
    @ObservedObject var model: DesktopModel
    @ObservedObject var cursor: CursorModel

    var body: some View {
        let r = model.quickPanelRect, p = cursor.position
        ZStack(alignment: .topLeading) {
            TimelineView(.periodic(from: .now, by: 15)) { ctx in
                VStack(alignment: .leading, spacing: 2) {
                    Text(ctx.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 26, weight: .semibold).monospacedDigit())
                    Text(ctx.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            .offset(x: 14, y: 12)

            ForEach(0..<DesktopModel.quickTileCount, id: \.self) { i in
                let t = model.quickTileRect(i)
                let (symbol, label, on) = tile(i)
                VStack(spacing: 6) {
                    Image(systemName: symbol).font(.system(size: 17, weight: .medium))
                    Text(label).font(.system(size: 10.5, weight: .medium)).lineLimit(2).multilineTextAlignment(.center)
                }
                .frame(width: t.width, height: t.height)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(on ? Color.accentColor.opacity(0.75) : Color.white.opacity(t.contains(p) ? 0.18 : 0.1)))
                .offset(x: t.minX - r.minX, y: t.minY - r.minY)
            }

            // Brightness of the external display: − bar +
            let down = model.brightnessDownRect, up = model.brightnessUpRect
            Group {
                roundButton("sun.min", hovered: down.contains(p)).offset(x: down.minX - r.minX, y: down.minY - r.minY)
                roundButton("sun.max.fill", hovered: up.contains(p)).offset(x: up.minX - r.minX, y: up.minY - r.minY)
                let barX = down.maxX + 10, barW = up.minX - 10 - barX
                Capsule().fill(Color.white.opacity(0.12)).frame(width: barW, height: 8)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.85))
                            .frame(width: barW * CGFloat((model.externalBrightness - 0.2) / 0.8), height: 8)
                    }
                    .offset(x: barX - r.minX, y: down.midY - 4 - r.minY)
            }

            // Notifications
            let top = model.notificationsTop
            Text("Notifications").font(.system(size: 13, weight: .semibold))
                .offset(x: 14, y: top + 5 - r.minY)
            if !model.notifications.isEmpty {
                let c = model.clearNotificationsRect
                Text("Clear all").font(.system(size: 12, weight: .medium))
                    .frame(width: c.width, height: c.height)
                    .background(Capsule().fill(Color.white.opacity(c.contains(p) ? 0.2 : 0.1)))
                    .offset(x: c.minX - r.minX, y: c.minY - r.minY)
            } else {
                Text("No notifications").font(.system(size: 12)).foregroundStyle(.secondary)
                    .offset(x: 14, y: top + 34 - r.minY)
            }
            ForEach(Array(model.notifications.prefix(5).enumerated()), id: \.element.id) { i, n in
                let row = model.notificationRect(i)
                NotificationCard(notification: n)
                    .frame(width: row.width, height: row.height)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(row.contains(p) ? 0.14 : 0.07)))
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.white.opacity(model.notificationCloseRect(i).contains(p) ? 0.3 : 0.12)))
                            .padding(6)
                            .opacity(row.contains(p) ? 1 : 0)
                    }
                    .offset(x: row.minX - r.minX, y: row.minY - r.minY)
            }
        }
        .frame(width: r.width, height: r.height, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 6)
        .offset(x: r.minX, y: r.minY)
    }

    private func tile(_ i: Int) -> (String, LocalizedStringKey, Bool) {
        switch i {
        case 0: return ("moon.fill", "Do not disturb", model.doNotDisturb)
        case 1: return ("dock.arrow.down.rectangle", "Hide taskbar", model.autoHideTaskbar)
        case 2: return ("camera.viewfinder", "Screenshot", false)
        default: return ("gearshape", "Settings", false)
        }
    }

    private func roundButton(_ symbol: String, hovered: Bool) -> some View {
        Image(systemName: symbol).font(.system(size: 14))
            .frame(width: 36, height: 36)
            .background(Circle().fill(Color.white.opacity(hovered ? 0.2 : 0.1)))
    }
}

/// One notification: the app's icon, title, text and time.
private struct NotificationCard: View {
    let notification: DeskNotification

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Group {
                if let icon = notification.app?.icon {
                    Image(uiImage: icon).resizable()
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.15))
                        .overlay(Image(systemName: "bell.fill").font(.system(size: 14)))
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(notification.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(notification.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                        .padding(.trailing, 22)
                }
                if !notification.body.isEmpty {
                    Text(notification.body).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Widgets

/// Desktop widgets: a clock and this month's calendar, top right, behind the windows.
private struct WidgetsView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { ctx in
            VStack(alignment: .trailing, spacing: 12) {
                clock(ctx.date)
                calendar(ctx.date)
            }
            .padding(.top, 24).padding(.trailing, 24)
        }
        .allowsHitTesting(false)
    }

    private func clock(_ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(date.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(16)
        .frame(width: 236, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func calendar(_ date: Date) -> some View {
        let cal = Calendar.current
        let month = cal.dateInterval(of: .month, for: date)!
        let days = cal.range(of: .day, in: .month, for: date)!.count
        let lead = (cal.component(.weekday, from: month.start) - cal.firstWeekday + 7) % 7
        let today = cal.component(.day, from: date)
        let symbols = (0..<7).map { cal.veryShortStandaloneWeekdaySymbols[($0 + cal.firstWeekday - 1) % 7] }
        let cells: [Int?] = Array(repeating: nil, count: lead) + (1...days).map { $0 }
        return VStack(alignment: .leading, spacing: 8) {
            Text(date.formatted(.dateTime.month(.wide).year())).font(.system(size: 14, weight: .semibold))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 3), count: 7), spacing: 4) {
                ForEach(symbols.indices, id: \.self) { i in
                    Text(symbols[i]).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.55))
                }
                ForEach(cells.indices, id: \.self) { i in
                    if let d = cells[i] {
                        Text(verbatim: "\(d)")
                            .font(.system(size: 11, weight: d == today ? .bold : .regular).monospacedDigit())
                            .frame(width: 24, height: 22)
                            .background(Circle().fill(d == today ? Color.accentColor : .clear))
                    } else {
                        Color.clear.frame(width: 24, height: 22)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 236, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Taskbar preview

/// A picture of a window above its taskbar button, shown while the pointer rests on the button.
private struct TaskPreviewView: View {
    let preview: DesktopModel.TaskPreview
    let screenWidth: CGFloat
    let taskbarTop: CGFloat

    var body: some View {
        let width: CGFloat = 240, height: CGFloat = 170
        let x = min(max(8, preview.anchor.midX - width / 2), screenWidth - width - 8)
        VStack(alignment: .leading, spacing: 6) {
            Text(preview.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
            Group {
                if let image = preview.image {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    Color(white: 0.15)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(8)
        .frame(width: width, height: height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 14, y: 4)
        .offset(x: x, y: taskbarTop - height - 8)
        .allowsHitTesting(false)
    }
}

// MARK: - Keyboard shortcuts

/// Win + / (or the desktop menu): every shortcut on one panel.
private struct ShortcutsView: View {
    private let rows: [(String, LocalizedStringKey)] = [
        ("Win", "Start menu (type to search)"),
        ("Win + Tab", "Recent apps"),
        ("Alt + Tab", "Switch windows"),
        ("Win + ← → ↑ ↓", "Snap, maximize, minimize the window"),
        ("Win + Ctrl + ← →", "Previous / next workspace"),
        ("Win + Ctrl + Shift + ← →", "Move the window to another workspace"),
        ("Esc  ·  Alt + ←", "Back"),
        ("Win + D", "Show desktop"),
        ("Win + M", "Minimize"),
        ("Win + W", "Close the tab or window"),
        ("Win + T  ·  Win + N", "New tab  ·  New window"),
        ("Win + L", "Address bar"),
        ("Ctrl + Tab", "Next tab"),
        ("Win + C / X / V", "Copy / cut / paste"),
        ("PrtSc  ·  Win + Shift + S", "Screenshot"),
        ("Win + /", "This list"),
    ]
    private let gestures: [(String, LocalizedStringKey)] = [
        ("3 ↑", "Recent apps"),
        ("3 ↓", "Home"),
        ("3 ← →", "Next / previous app"),
        ("3 •", "Back"),
        ("4 ← →", "Next / previous workspace"),
        ("4 •", "Start menu"),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
            HStack(alignment: .top, spacing: 28) {
                column("Keyboard", rows)
                column("Trackpad (fingers)", gestures)
            }
            .padding(22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 24, y: 8)
        }
        .allowsHitTesting(false)
    }

    private func column(_ title: LocalizedStringKey, _ items: [(String, LocalizedStringKey)]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 15, weight: .semibold)).padding(.bottom, 4)
            ForEach(items.indices, id: \.self) { i in
                HStack(spacing: 12) {
                    Text(verbatim: items[i].0)
                        .font(.system(size: 12, weight: .semibold).monospaced())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.12)))
                        .frame(width: 215, alignment: .leading)
                    Text(items[i].1).font(.system(size: 13))
                }
            }
        }
    }
}

// MARK: - Recent apps

/// Every window as a card with a picture of it, like Android's Recent apps: click one to switch to it,
/// its × (or Delete) closes it, "Close all" closes everything.
private struct RecentsView: View {
    @ObservedObject var model: DesktopModel
    let recents: DesktopModel.Switcher
    @ObservedObject var cursor: CursorModel

    var body: some View {
        let count = recents.ids.count
        let p = cursor.position
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.78)
            if count == 0 {
                Text("No recent apps")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: model.desktopArea.width, height: model.desktopArea.height)
            }
            ForEach(Array(recents.ids.enumerated()), id: \.element) { i, id in
                if let w = model.windows.first(where: { $0.id == id }) {
                    let r = model.recentsTileRect(i, of: count)
                    card(w, image: model.thumbnails[id], rect: r, selected: i == recents.index,
                         hovered: r.contains(p), closeHovered: model.recentsCloseRect(i, of: count).contains(p))
                        .offset(x: r.minX, y: r.minY)
                }
            }
            if count > 0 {
                let r = model.recentsCloseAllRect(count)
                Text("Close all")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: r.width, height: r.height)
                    .background(Capsule().fill(Color.white.opacity(r.contains(p) ? 0.28 : 0.16)))
                    .offset(x: r.minX, y: r.minY)
            }
        }
    }

    private func card(_ w: DeskWindow, image: UIImage?, rect r: CGRect, selected: Bool,
                      hovered: Bool, closeHovered: Bool) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                if let icon = w.guestApp?.icon {
                    Image(uiImage: icon).resizable().frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                } else {
                    Image(systemName: w.isApp ? "app.fill" : "globe").font(.system(size: 14))
                }
                Text(w.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Spacer(minLength: 28)
            }
            .frame(height: Layout.recentsTitle - 6)
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(white: 0.12))
                if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else if let icon = w.guestApp?.icon {
                    Image(uiImage: icon).resizable().frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                } else {
                    Image(systemName: w.isApp ? "app.fill" : "globe").font(.system(size: 40)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .frame(width: r.width, height: r.height)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(selected ? Color(red: 0.12, green: 0.27, blue: 0.5) : Color(white: hovered ? 0.24 : 0.18)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(selected ? Color.accentColor : .clear, lineWidth: 2))
        .overlay(alignment: .topTrailing) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(closeHovered ? 0.35 : 0.14)))
                .padding(.top, 5).padding(.trailing, 4)
        }
        .opacity(w.isMinimized && !selected ? 0.85 : 1)
    }
}

// MARK: - Context menu

private struct ContextMenuView: View {
    let menu: ContextMenu
    @ObservedObject var cursor: CursorModel

    var body: some View {
        let f = menu.frame
        VStack(spacing: 0) {
            ForEach(Array(menu.items.enumerated()), id: \.offset) { i, item in
                if item.isSeparator {
                    Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                        .padding(.horizontal, 6)
                        .frame(height: Layout.menuSeparatorHeight)
                } else {
                    let hovered = item.enabled && menu.itemRect(i).contains(cursor.position)
                    HStack(spacing: 10) {
                        Group {
                            if let s = item.symbol { Image(systemName: s) } else { Color.clear }
                        }
                        .frame(width: 18)
                        Text(item.title).font(.system(size: 13))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: Layout.menuItemHeight)
                    .background(RoundedRectangle(cornerRadius: 6).fill(hovered ? Color.accentColor.opacity(0.6) : .clear))
                    .opacity(item.enabled ? 1 : 0.4)
                }
            }
        }
        .padding(Layout.menuPadding)
        .frame(width: f.width, height: f.height, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 16, y: 6)
        .offset(x: f.minX, y: f.minY)
    }
}

// MARK: - Pointer

private struct CursorView: View {
    @ObservedObject var cursor: CursorModel

    var body: some View {
        let p = cursor.position
        // The press bounce must scale around the hot spot itself, and must come BEFORE offset.
        // Scaling the whole thing after moving it drags the pointer toward the screen corner on every click.
        let press: CGFloat = cursor.isPressed ? 0.85 : 1
        Group {
            switch cursor.style {
            case .arrow, .grab:
                // Hand-drawn arrow: its tip is at (0,0), so the hot spot = the tip.
                ArrowCursor()
                    .frame(width: 18, height: 26)
                    .scaleEffect(press, anchor: .topLeading)
                    .offset(x: p.x, y: p.y)
            case .pointer:
                // Hand: the index fingertip is near the top, aligned to the hot spot.
                glyph("hand.point.up.left.fill", 24)
                    .scaleEffect(press, anchor: .topLeading)
                    .offset(x: p.x - 6, y: p.y - 2)
            default:
                glyph(symbol, 18).frame(width: 28, height: 28)
                    .scaleEffect(press)
                    .offset(x: p.x - 14, y: p.y - 14)
            }
        }
    }

    private var symbol: String {
        switch cursor.style {
        case .text: return "character.cursor.ibeam"
        case .resizeH: return "arrow.left.and.right"
        case .resizeV: return "arrow.up.and.down"
        case .resizeNWSE: return "arrow.up.left.and.arrow.down.right"
        case .resizeNESW: return "arrow.up.right.and.arrow.down.left"
        case .arrow, .pointer, .grab: return "cursorarrow"
        }
    }

    private func glyph(_ name: String, _ size: CGFloat) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(.white)
            .shadow(color: .black, radius: 1)
            .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
    }
}

/// Classic arrow pointer, tip at the origin (0,0).
private struct ArrowCursor: View {
    var body: some View {
        ArrowShape()
            .fill(.white)
            .overlay(ArrowShape().stroke(.black, lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
    }
}

private struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: 0, y: 17.5))
        p.addLine(to: CGPoint(x: 4.3, y: 13.2))
        p.addLine(to: CGPoint(x: 7.2, y: 20))
        p.addLine(to: CGPoint(x: 10, y: 18.8))
        p.addLine(to: CGPoint(x: 7.2, y: 12.2))
        p.addLine(to: CGPoint(x: 13, y: 12.2))
        p.closeSubpath()
        return p
    }
}

/// `_UIPortalView` (private UIKit API): renders a view's content somewhere else without moving it,
/// even on another display (guest window on the iPhone → desktop; desktop → mirror on the iPhone).
enum Portal {
    static func make(of source: UIView, hidesSource: Bool) -> UIView? {
        guard let cls = NSClassFromString("_UIPortalView") as? UIView.Type else { return nil }
        let portal = cls.init(frame: .zero)
        let setters: [(String, Any)] = [
            ("sourceView", source),
            ("hidesSourceView", hidesSource),
            ("matchesPosition", false),
            ("matchesTransform", false),
            ("matchesAlpha", false),
        ]
        for (key, value) in setters {
            let setter = Selector("set" + key.prefix(1).uppercased() + key.dropFirst() + ":")
            guard portal.responds(to: setter) else { return key == "sourceView" ? nil : portal }
            portal.setValue(value, forKey: key)
        }
        if portal.layer.responds(to: Selector(("setCrossDisplay:"))) {
            portal.layer.setValue(true, forKey: "crossDisplay")
        }
        portal.isUserInteractionEnabled = false
        return portal
    }
}
