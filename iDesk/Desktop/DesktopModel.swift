import UIKit
import WebKit
import Combine

// MARK: - Layout metrics (shared by drawing and hit testing)

enum Layout {
    static let titleBar: CGFloat = 34
    static let addressBar: CGFloat = 38            // web windows: back, forward, reload, address field
    static let taskbar: CGFloat = 48
    static let resizeGrip: CGFloat = 22
    static let edgeGrab: CGFloat = 6
    static let minWindowSize = CGSize(width: 360, height: 260)

    // Title bar buttons (close / minimize / maximize), relative to the window frame.
    static func closeButton(in f: CGRect) -> CGRect { CGRect(x: f.minX + 12, y: f.minY + 9, width: 16, height: 16) }
    static func minimizeButton(in f: CGRect) -> CGRect { CGRect(x: f.minX + 34, y: f.minY + 9, width: 16, height: 16) }
    static func maximizeButton(in f: CGRect) -> CGRect { CGRect(x: f.minX + 56, y: f.minY + 9, width: 16, height: 16) }
    static func titleButtons(in f: CGRect) -> CGRect { CGRect(x: f.minX + 8, y: f.minY + 5, width: 70, height: 24) }

    // Address bar of a web window, below the title bar.
    static func addressRow(in f: CGRect) -> CGRect { CGRect(x: f.minX, y: f.minY + titleBar, width: f.width, height: addressBar) }
    static func backButton(in f: CGRect) -> CGRect { CGRect(x: f.minX + 8, y: f.minY + titleBar + 5, width: 28, height: 28) }
    static func forwardButton(in f: CGRect) -> CGRect { CGRect(x: f.minX + 40, y: f.minY + titleBar + 5, width: 28, height: 28) }
    static func reloadButton(in f: CGRect) -> CGRect { CGRect(x: f.minX + 72, y: f.minY + titleBar + 5, width: 28, height: 28) }
    static func addressField(in f: CGRect) -> CGRect {
        CGRect(x: f.minX + 108, y: f.minY + titleBar + 5, width: max(0, f.width - 116), height: 28)
    }

    // Taskbar
    static let startX: CGFloat = 8
    static let startWidth: CGFloat = 44
    static let taskItemX: CGFloat = 60
    static let taskItemMaxWidth: CGFloat = 200
    static let taskItemMinWidth: CGFloat = 48
    static let taskItemGap: CGFloat = 6
    static let pinnedWidth: CGFloat = 44           // a pinned app that is not open: icon only
    static let buttonHeight: CGFloat = 40
    static let trayWidth: CGFloat = 190
    static let showDesktopWidth: CGFloat = 10

    // Start menu (grid)
    static let launcherColumns = 3
    static let launcherTile = CGSize(width: 104, height: 88)
    static let launcherGap: CGFloat = 6
    static let launcherPadding: CGFloat = 14
    static let launcherHeader: CGFloat = 76        // title + search field

    // Desktop icons
    static let iconCell = CGSize(width: 92, height: 92)
    static let iconGap: CGFloat = 6
    static let iconOrigin = CGPoint(x: 16, y: 16)

    // Context menu
    static let menuWidth: CGFloat = 250
    static let menuItemHeight: CGFloat = 32
    static let menuSeparatorHeight: CGFloat = 9
    static let menuPadding: CGFloat = 6
}

struct Shortcut {
    let name: String
    let symbol: String
    let url: String
    let hue: Double
    var app: GuestApp? = nil      // non-nil: an app installed from an IPA rather than a web page
}

enum CursorStyle {
    case arrow, pointer, text, grab, resizeH, resizeV, resizeNWSE, resizeNESW
}

struct ResizeEdges: OptionSet {
    let rawValue: Int
    static let left = ResizeEdges(rawValue: 1)
    static let right = ResizeEdges(rawValue: 2)
    static let top = ResizeEdges(rawValue: 4)
    static let bottom = ResizeEdges(rawValue: 8)

    var cursorStyle: CursorStyle {
        if (contains(.left) && contains(.top)) || (contains(.right) && contains(.bottom)) { return .resizeNWSE }
        if (contains(.left) && contains(.bottom)) || (contains(.right) && contains(.top)) { return .resizeNESW }
        if contains(.left) || contains(.right) { return .resizeH }
        if contains(.top) || contains(.bottom) { return .resizeV }
        return .arrow
    }
}

// MARK: - Context menu

struct MenuItem {
    let title: String
    let symbol: String?
    let enabled: Bool
    let action: (() -> Void)?

    init(_ title: String.LocalizationValue, _ symbol: String?, enabled: Bool = true, action: (() -> Void)?) {
        self.title = String(localized: title)
        self.symbol = symbol
        self.enabled = enabled
        self.action = action
    }

    static let separator = MenuItem("", nil, action: nil)
    var isSeparator: Bool { title.isEmpty && action == nil }
    var height: CGFloat { isSeparator ? Layout.menuSeparatorHeight : Layout.menuItemHeight }
}

struct ContextMenu {
    let items: [MenuItem]
    let frame: CGRect

    func itemRect(_ i: Int) -> CGRect {
        let y = items[..<i].reduce(frame.minY + Layout.menuPadding) { $0 + $1.height }
        return CGRect(x: frame.minX + Layout.menuPadding, y: y,
                      width: frame.width - Layout.menuPadding * 2, height: items[i].height)
    }
}

// MARK: - Windows

final class DeskWindow: NSObject, ObservableObject, Identifiable, WKUIDelegate, WKNavigationDelegate {
    let id = UUID()
    @Published var frame: CGRect
    @Published var title = String(localized: "New window")
    @Published var isMinimized = false
    @Published var isMaximized = false
    var isSnapped = false           // snapped to a half or a quarter of the screen
    var snap: DesktopModel.Snap?    // which one, while isSnapped
    var restoreFrame: CGRect?
    let initialURL: URL
    let webView: WKWebView?         // web window
    let guestApp: GuestApp?         // window of an app installed from an IPA
    let guestWindow: UIWindow?
    var isApp: Bool { guestWindow != nil }
    var onChange: (() -> Void)?

    // Fullscreen (requested by the page through the Fullscreen API, see WebFullscreen.swift)
    @Published var isFullscreen = false
    var fullscreenRestore: (frame: CGRect, maximized: Bool, snapped: Bool)?
    var fullscreenFrame: WKFrameInfo?
    var onFullscreen: ((Bool) -> Void)?
    private let fullscreenBridge = WebFullscreenBridge()

    /// Height of what is above the content: title bar, plus the address bar of a web window. None in fullscreen.
    var chromeHeight: CGFloat { isFullscreen ? 0 : Layout.titleBar + (webView != nil ? Layout.addressBar : 0) }

    // Address bar
    /// What is being typed in the address field; nil while the field is not being edited.
    @Published var addressDraft: String?
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isLoading = false
    private var navigationObservations: [NSKeyValueObservation] = []

    /// Asks the page to leave fullscreen (it reports back so iDesk restores the window).
    func exitFullscreen() {
        guard let webView else { onFullscreen?(false); return }
        webView.evaluateJavaScript(WebFullscreen.exitScript, in: fullscreenFrame, in: .page) { [weak self] result in
            // The page did not answer (navigated away, iframe gone…): leave on our own.
            if case .failure = result, self?.isFullscreen == true { self?.onFullscreen?(false) }
        }
    }
    private var titleObservation: NSKeyValueObservation?
    private var urlObservation: NSKeyValueObservation?

    var currentURL: URL { webView?.url ?? initialURL }

    /// A window hosting a guest app launched by GuestRuntime.
    init(app: GuestApp, window: UIWindow, frame: CGRect) {
        self.frame = frame
        self.initialURL = app.bundleURL
        self.webView = nil
        self.guestApp = app
        self.guestWindow = window
        super.init()
        title = app.name
    }

    init(url: URL, frame: CGRect) {
        self.frame = frame
        self.initialURL = url
        self.guestApp = nil
        self.guestWindow = nil
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.preferredContentMode = .desktop   // request desktop websites
        config.userContentController.addUserScript(WebFullscreen.script)
        config.userContentController.add(fullscreenBridge, name: WebFullscreen.messageName)
        let webView = WKWebView(frame: CGRect(origin: .zero, size: frame.size), configuration: config)
        self.webView = webView
        super.init()
        fullscreenBridge.window = self
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.load(URLRequest(url: url))
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
            DispatchQueue.main.async {
                let t = wv.title ?? ""
                self?.title = t.isEmpty ? (wv.url?.host ?? String(localized: "Window")) : t
            }
        }
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.onChange?(); self?.objectWillChange.send() }
        }
        navigationObservations = [
            webView.observe(\.canGoBack) { [weak self] wv, _ in DispatchQueue.main.async { self?.canGoBack = wv.canGoBack } },
            webView.observe(\.canGoForward) { [weak self] wv, _ in DispatchQueue.main.async { self?.canGoForward = wv.canGoForward } },
            webView.observe(\.isLoading) { [weak self] wv, _ in DispatchQueue.main.async { self?.isLoading = wv.isLoading } },
        ]
    }

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: WebFullscreen.messageName)
    }

    // Navigating while in fullscreen: the new page is no longer fullscreen.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if isFullscreen { onFullscreen?(false) }
    }

    // target=_blank links: open in the current window.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { webView.load(URLRequest(url: url)) }
        return nil
    }
}

// MARK: - Pointer (separate so moving it does not redraw the whole desktop)

final class CursorModel: ObservableObject {
    @Published var position: CGPoint = CGPoint(x: 200, y: 200)
    @Published var isPressed = false
    @Published private(set) var style: CursorStyle = .arrow

    func setStyle(_ s: CursorStyle) { if style != s { style = s } }
}

// MARK: - Desktop state

final class DesktopModel: ObservableObject {
    static let shared = DesktopModel()

    static let shortcuts: [Shortcut] = [
        Shortcut(name: "Google", symbol: "magnifyingglass", url: "https://www.google.com", hue: 0.60),
        Shortcut(name: "YouTube", symbol: "play.rectangle.fill", url: "https://www.youtube.com", hue: 0.00),
        Shortcut(name: "Gmail", symbol: "envelope.fill", url: "https://mail.google.com", hue: 0.03),
        Shortcut(name: "Facebook", symbol: "person.2.fill", url: "https://www.facebook.com", hue: 0.62),
        Shortcut(name: "ChatGPT", symbol: "bubble.left.and.bubble.right.fill", url: "https://chatgpt.com", hue: 0.45),
    ]

    @Published var windows: [DeskWindow] = []      // order = stacking order (last = topmost)
    @Published var focusedID: UUID? {
        // Code no app can be found for on the call stack is attributed to the app the user works with.
        didSet { if let guest = focused?.guestWindow { GuestRuntime.activateApp(with: guest) } }
    }
    @Published var screenSize: CGSize = CGSize(width: 1280, height: 720)
    @Published var isExternalConnected = false
    @Published var showLauncher = false {
        didSet { if !showLauncher { launcherQuery = "" } }
    }
    /// Typed while the Start menu is open: filters the apps.
    @Published var launcherQuery = ""
    /// Apps pinned to the taskbar (keys: app bundle id or web address), in order.
    @Published private(set) var pinnedKeys: [String] = UserDefaults.standard.stringArray(forKey: Keys.pinned)
        ?? ["https://www.google.com", "https://www.youtube.com"] {
        didSet { UserDefaults.standard.set(pinnedKeys, forKey: Keys.pinned) }
    }
    /// The Alt+Tab switcher while it is shown: windows from most to least recent, and the one selected.
    @Published private(set) var switcher: Switcher?
    @Published var contextMenu: ContextMenu?
    @Published var snapPreview: CGRect?
    @Published var selectedIcon: Int?
    @Published var notice: String?                 // error message shown on the iPhone
    @Published private(set) var apps: [GuestApp] = []
    /// Wallpaper: 0…n are the built-in gradients, -1 is the user's photo (`customWallpaper`).
    @Published var wallpaper: Int = UserDefaults.standard.integer(forKey: Keys.wallpaper) {
        didSet { UserDefaults.standard.set(wallpaper, forKey: Keys.wallpaper) }
    }
    @Published private(set) var customWallpaper: UIImage? = UIImage(contentsOfFile: DesktopModel.wallpaperFile.path)
    /// External display brightness (0.2…1). Apps cannot change its backlight, so it is dimmed with an overlay.
    @Published var externalBrightness: Double = UserDefaults.standard.object(forKey: Keys.brightness) as? Double ?? 1 {
        didSet { UserDefaults.standard.set(externalBrightness, forKey: Keys.brightness) }
    }
    let cursor = CursorModel()

    private enum Keys {
        static let wallpaper = "iDesk.wallpaper"
        static let brightness = "iDesk.externalBrightness"
        static let session = "iDesk.session.v1"
        static let pinned = "iDesk.pinned"
    }

    private enum Drag {
        case none
        case move(UUID, offset: CGPoint)
        case resize(UUID, edges: ResizeEdges, start: CGPoint, startFrame: CGRect)
        case guest(UUID)            // holding a "finger" down in a guest app
    }
    enum Snap { case left, right, maximize, topLeft, topRight, bottomLeft, bottomRight }

    struct Switcher {
        var ids: [UUID]
        var index: Int
    }

    /// A taskbar entry: a pinned app (with its window when it is open) or another open window.
    enum TaskEntry {
        case pinned(Shortcut, DeskWindow?)
        case window(DeskWindow)

        var window: DeskWindow? {
            switch self {
            case let .pinned(_, w): return w
            case let .window(w): return w
            }
        }
    }

    private var drag: Drag = .none
    private var snapTarget: Snap?
    private var pressPoint: CGPoint?
    private var lastClickTime: CFTimeInterval = 0
    private var lastClickPoint: CGPoint = .zero
    private var hiddenByShowDesktop: [UUID] = []
    private var hoverInFlight = false
    private var hoverStarted: CFTimeInterval = 0
    private var hoverAgain = false
    private var saveWork: DispatchWorkItem?
    private var switcherCommit: DispatchWorkItem?
    private var appsSubscription: AnyCancellable?
    private var isDragging: Bool { if case .none = drag { return false } else { return true } }
    private var isGuestDrag: Bool { if case .guest = drag { return true } else { return false } }

    private init() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.saveNow() }
        appsSubscription = GuestStore.shared.$apps.sink { [weak self] in self?.apps = $0 }
        // A guest app opened an in-app browser (GuestRuntimeOpenURLNotification): a web window on the desktop.
        NotificationCenter.default.addObserver(forName: Notification.Name("iDeskGuestOpenURL"),
                                               object: nil, queue: .main) { [weak self] note in
            if let url = note.object as? URL { self?.openWindow(url.absoluteString) }
        }
        // iDesk quit last time (usually because of a guest app): show the report so the user can send it.
        if let report = CrashReporter.takeLastReport() {
            let text = report.count > 4000 ? String(report.prefix(4000)) + "\n…" : report
            notice = String(localized: "iDesk quit unexpectedly last time. Tap “Copy error” and send the text below:") + "\n\n" + text
        }
    }

    /// Everything that can be opened from the desktop / Start menu: web shortcuts + installed apps.
    var items: [Shortcut] {
        Self.shortcuts + apps.map { Shortcut(name: $0.name, symbol: "app.fill", url: "", hue: 0.5, app: $0) }
    }

    func open(_ item: Shortcut) {
        if let app = item.app { openApp(app) } else { openWindow(item.url) }
    }

    // MARK: Pinned apps (taskbar)

    static func key(of item: Shortcut) -> String { item.app?.id ?? item.url }

    var pinnedItems: [Shortcut] {
        let all = items
        return pinnedKeys.compactMap { key in all.first { Self.key(of: $0) == key } }
    }

    func isPinned(_ item: Shortcut) -> Bool { pinnedKeys.contains(Self.key(of: item)) }

    func togglePin(_ item: Shortcut) {
        let key = Self.key(of: item)
        if let i = pinnedKeys.firstIndex(of: key) { pinnedKeys.remove(at: i) } else { pinnedKeys.append(key) }
    }

    /// Pinned apps first (an open app shows its window there, like Samsung DeX), then the other windows.
    var taskEntries: [TaskEntry] {
        var shown = Set<UUID>()
        var entries: [TaskEntry] = pinnedItems.map { item in
            let w = item.app.flatMap { app in windows.first { $0.guestApp == app } }
            if let w { shown.insert(w.id) }
            return .pinned(item, w)
        }
        entries += windows.filter { !shown.contains($0.id) }.map { .window($0) }
        return entries
    }

    /// The Start menu's apps, filtered by what was typed.
    var launcherItems: [Shortcut] {
        let q = launcherQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private func itemMenu(_ item: Shortcut) -> [MenuItem] {
        [
            MenuItem("Open", "arrow.up.forward.app") { [weak self] in self?.showLauncher = false; self?.open(item) },
            MenuItem(isPinned(item) ? "Unpin from taskbar" : "Pin to taskbar",
                     isPinned(item) ? "pin.slash" : "pin") { [weak self] in self?.togglePin(item) },
        ]
    }

    var focused: DeskWindow? { windows.first { $0.id == focusedID } }
    var taskbarTop: CGFloat { screenSize.height - Layout.taskbar }
    var desktopArea: CGRect { CGRect(x: 0, y: 0, width: screenSize.width, height: max(0, taskbarTop)) }
    private var maximizedFrame: CGRect { desktopArea.insetBy(dx: 4, dy: 4) }

    private func window(_ id: UUID) -> DeskWindow? { windows.first { $0.id == id } }

    // MARK: Display connection

    func externalConnected() {
        isExternalConnected = true
        UIApplication.shared.isIdleTimerDisabled = true
        cursor.position = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
        if windows.isEmpty && !restoreSession() { openWindow("https://www.google.com") }
    }

    func externalDisconnected() {
        saveNow()
        isExternalConnected = false
        UIApplication.shared.isIdleTimerDisabled = false
        drag = .none
        contextMenu = nil
        snapPreview = nil
    }

    // MARK: Windows

    func openWindow(_ string: String) { openWindow(Self.url(from: string)) }

    func openWindow(_ url: URL) {
        // No external display means no desktop to put the window on: do not open it invisibly.
        guard isExternalConnected else { return }
        let area = desktopArea
        let size = CGSize(width: min(1100, area.width * 0.72), height: min(760, area.height * 0.8))
        let step = CGFloat(windows.count % 8) * 32
        let origin = CGPoint(x: max(0, (area.width - size.width) / 2 - 96 + step),
                             y: max(0, (area.height - size.height) / 2 - 48 + step))
        let w = DeskWindow(url: url, frame: CGRect(origin: origin, size: size))
        add(w)
        focusedID = w.id
        scheduleSave()
    }

    // MARK: Apps installed from IPA files

    /// Loads the guest app into the process (first time) and puts its window on the desktop.
    func openApp(_ app: GuestApp) {
        guard isExternalConnected else {
            notice = String(localized: "Connect an external display first; the app opens as a window on the desktop.")
            return
        }
        if let w = windows.first(where: { $0.guestApp == app }) { focus(w); return }
        guard let scene = PhoneWindow.current?.windowScene else { return }

        CrashReporter.setGuestName(app.name)
        do {
            try GuestStore.shared.prepareForLaunch(app)
        } catch {
            notice = error.localizedDescription
            return
        }
        do {
            let guest = try GuestRuntime.launchBundle(atPath: app.bundleURL.path, scene: scene)
            GuestRuntime.resumeApp(with: guest)        // reopened after its window was closed
            let area = desktopArea
            // Default size matches a phone screen, since iPhone apps are designed for it.
            let size = CGSize(width: min(430, area.width - 16),
                              height: min(800 + Layout.titleBar, area.height - 16))
            let step = CGFloat(windows.count % 8) * 32
            let origin = CGPoint(x: min(max(8, area.width - size.width - 48 - step), area.width - size.width),
                                 y: max(8, min(24 + step, area.height - size.height)))
            let w = DeskWindow(app: app, window: guest, frame: CGRect(origin: origin, size: size))
            add(w)
            focusedID = w.id
        } catch {
            notice = LaunchDiagnostics.explain(error.localizedDescription)
        }
        // Guest apps tend to grab the key window: give the keyboard back to iDesk.
        PhoneWindow.current?.makeKey()
        PhoneWindow.current?.claimKeyboard()
    }

    private func add(_ w: DeskWindow) {
        w.onChange = { [weak self] in self?.scheduleSave() }
        w.onFullscreen = { [weak self, weak w] on in
            guard let self, let w else { return }
            self.setFullscreen(w, on)
        }
        windows.append(w)
    }

    func focus(_ w: DeskWindow) {
        w.isMinimized = false
        if let i = windows.firstIndex(where: { $0.id == w.id }), i != windows.count - 1 {
            windows.append(windows.remove(at: i))
        }
        focusedID = w.id
    }

    func close(_ w: DeskWindow) {
        w.webView?.stopLoading()
        if w.isApp, isGuestDrag { Self.guestInput { GuestTouch.cancel() }; drag = .none }
        windows.removeAll { $0.id == w.id }
        // Closing an app: it gets the "went to the background" events, so it stops playing and pauses.
        if let guest = w.guestWindow { GuestRuntime.suspendApp(with: guest) }
        focusedID = windows.last(where: { !$0.isMinimized })?.id
        hoverInFlight = false
        scheduleSave()
    }

    func minimize(_ w: DeskWindow) {
        w.isMinimized = true
        if focusedID == w.id { focusedID = windows.last(where: { !$0.isMinimized })?.id }
        scheduleSave()
    }

    /// The window covers the whole external display (taskbar included) when the page requests fullscreen.
    func setFullscreen(_ w: DeskWindow, _ on: Bool) {
        guard on != w.isFullscreen else { return }
        objectWillChange.send()   // the desktop must redraw to hide/show the taskbar
        if on {
            w.fullscreenRestore = (w.frame, w.isMaximized, w.isSnapped)
            w.isFullscreen = true
            w.frame = CGRect(origin: .zero, size: screenSize)
            showLauncher = false
            contextMenu = nil
            focus(w)
        } else {
            w.isFullscreen = false
            if let r = w.fullscreenRestore {
                w.frame = r.frame
                w.isMaximized = r.maximized
                w.isSnapped = r.snapped
            }
            w.fullscreenRestore = nil
            w.fullscreenFrame = nil
        }
        updateHover(cursor.position)
    }

    /// Whether any window is fullscreen (the taskbar is hidden).
    var hasFullscreen: Bool { windows.contains { $0.isFullscreen && !$0.isMinimized } }

    /// Top edge of the taskbar's hit area; none while a window is fullscreen and the taskbar is hidden.
    private var taskbarHitTop: CGFloat { hasFullscreen ? .infinity : taskbarTop }

    func toggleMaximize(_ w: DeskWindow) {
        if w.isMaximized {
            w.frame = w.restoreFrame ?? w.frame
            w.isMaximized = false
        } else {
            if !w.isSnapped { w.restoreFrame = w.frame }
            w.frame = maximizedFrame
            w.isMaximized = true
        }
        w.isSnapped = false
        w.snap = nil
        scheduleSave()
    }

    private func snap(_ w: DeskWindow, _ s: Snap) {
        if s == .maximize {
            if !w.isMaximized { toggleMaximize(w) }
            return
        }
        if !w.isMaximized && !w.isSnapped { w.restoreFrame = w.frame }
        w.frame = snapRect(s)
        w.isMaximized = false
        w.isSnapped = true
        w.snap = s
        scheduleSave()
    }

    /// Restores a maximized or snapped window to its size before.
    private func restore(_ w: DeskWindow) {
        if w.isMaximized { toggleMaximize(w); return }
        guard w.isSnapped else { return }
        if let r = w.restoreFrame { w.frame = r }
        w.isSnapped = false
        w.snap = nil
        scheduleSave()
    }

    enum Direction { case left, right, up, down }

    /// Win + arrow keys, as on Windows and Samsung DeX: halves left / right, then quarters with up / down;
    /// up maximizes, down restores and then minimizes.
    func snapFocused(_ direction: Direction) {
        guard let w = focused, !w.isMinimized, !w.isFullscreen else { return }
        let current = w.isSnapped ? w.snap : (w.isMaximized ? .maximize : nil)
        switch (direction, current) {
        case (.left, .right), (.right, .left): restore(w)
        case (.left, .topRight), (.left, .bottomRight), (.right, .topLeft), (.right, .bottomLeft):
            restore(w)
        case (.left, _): snap(w, .left)
        case (.right, _): snap(w, .right)
        case (.up, .left), (.up, .bottomLeft): snap(w, .topLeft)
        case (.up, .right), (.up, .bottomRight): snap(w, .topRight)
        case (.up, _): snap(w, .maximize)
        case (.down, .left), (.down, .topLeft): snap(w, .bottomLeft)
        case (.down, .right), (.down, .topRight): snap(w, .bottomRight)
        case (.down, .maximize): restore(w)
        case (.down, _): if w.isSnapped { restore(w) } else { minimize(w) }
        }
    }

    private func snapRect(_ s: Snap) -> CGRect {
        let a = maximizedFrame
        switch s {
        case .maximize: return a
        case .left: return CGRect(x: a.minX, y: a.minY, width: a.width / 2 - 3, height: a.height)
        case .right: return CGRect(x: a.midX + 3, y: a.minY, width: a.width / 2 - 3, height: a.height)
        case .topLeft: return CGRect(x: a.minX, y: a.minY, width: a.width / 2 - 3, height: a.height / 2 - 3)
        case .topRight: return CGRect(x: a.midX + 3, y: a.minY, width: a.width / 2 - 3, height: a.height / 2 - 3)
        case .bottomLeft: return CGRect(x: a.minX, y: a.midY + 3, width: a.width / 2 - 3, height: a.height / 2 - 3)
        case .bottomRight: return CGRect(x: a.midX + 3, y: a.midY + 3, width: a.width / 2 - 3, height: a.height / 2 - 3)
        }
    }

    /// Arranges visible windows in a grid.
    func tileWindows() {
        let visible = windows.filter { !$0.isMinimized }
        guard !visible.isEmpty else { return }
        let cols = Int(ceil(Double(visible.count).squareRoot()))
        let rows = Int(ceil(Double(visible.count) / Double(cols)))
        let a = maximizedFrame, gap: CGFloat = 6
        let cw = (a.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
        let ch = (a.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
        for (i, w) in visible.enumerated() {
            let c = i % cols, r = i / cols
            w.frame = CGRect(x: a.minX + CGFloat(c) * (cw + gap), y: a.minY + CGFloat(r) * (ch + gap), width: cw, height: ch)
            w.isMaximized = false
            w.isSnapped = false
        }
        scheduleSave()
    }

    /// Cascades windows.
    func cascadeWindows() {
        let a = desktopArea
        let size = CGSize(width: min(1000, a.width * 0.6), height: min(700, a.height * 0.7))
        for (i, w) in windows.filter({ !$0.isMinimized }).enumerated() {
            let step = CGFloat(i % 10) * 36
            w.frame = CGRect(origin: CGPoint(x: a.minX + 24 + step, y: a.minY + 24 + step), size: size)
            w.isMaximized = false
            w.isSnapped = false
        }
        scheduleSave()
    }

    /// "Show desktop" button: minimize everything, press again to restore.
    func toggleShowDesktop() {
        let visible = windows.filter { !$0.isMinimized }
        if visible.isEmpty {
            for id in hiddenByShowDesktop { window(id)?.isMinimized = false }
            hiddenByShowDesktop = []
            focusedID = windows.last(where: { !$0.isMinimized })?.id
        } else {
            hiddenByShowDesktop = visible.map(\.id)
            visible.forEach { $0.isMinimized = true }
            focusedID = nil
        }
        scheduleSave()
    }

    func nextWallpaper() { wallpaper = wallpaper < 0 ? 0 : (wallpaper + 1) % Wallpapers.count }

    private static var wallpaperFile: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("iDeskWallpaper.jpg")
    }

    /// Sets a photo as wallpaper: scaled down to display size (less memory), then saved.
    func setCustomWallpaper(_ data: Data) {
        guard let image = UIImage(data: data) else { notice = String(localized: "Could not read this image."); return }
        let maxSide: CGFloat = 2560
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        try? resized.jpegData(compressionQuality: 0.85)?.write(to: Self.wallpaperFile, options: .atomic)
        customWallpaper = resized
        wallpaper = -1
    }

    func topWindow(at p: CGPoint) -> DeskWindow? {
        windows.reversed().first { !$0.isMinimized && $0.frame.contains(p) }
    }

    /// Like topWindow but includes the outer border, to catch resize edges.
    private func pointerWindow(at p: CGPoint) -> DeskWindow? {
        let g = Layout.edgeGrab
        return windows.reversed().first { !$0.isMinimized && $0.frame.insetBy(dx: -g, dy: -g).contains(p) }
    }

    private func resizeEdges(_ w: DeskWindow, at p: CGPoint) -> ResizeEdges {
        guard !w.isMaximized, !w.isFullscreen else { return [] }
        let f = w.frame, g = Layout.edgeGrab
        guard f.insetBy(dx: -g, dy: -g).contains(p) else { return [] }
        if p.x > f.maxX - Layout.resizeGrip && p.y > f.maxY - Layout.resizeGrip { return [.right, .bottom] }
        var e: ResizeEdges = []
        if p.x < f.minX + g { e.insert(.left) }
        if p.x > f.maxX - g { e.insert(.right) }
        if p.y < f.minY + 3 { e.insert(.top) }
        if p.y > f.maxY - g { e.insert(.bottom) }
        return e
    }

    private func isOverContent(_ p: CGPoint, of w: DeskWindow) -> Bool {
        w.frame.contains(p) && p.y >= w.frame.minY + w.chromeHeight
    }

    // MARK: Taskbar / Start menu / icon geometry

    var startButtonRect: CGRect {
        CGRect(x: Layout.startX, y: taskbarTop + 4, width: Layout.startWidth, height: Layout.buttonHeight)
    }

    var trayRect: CGRect {
        CGRect(x: screenSize.width - Layout.showDesktopWidth - Layout.trayWidth, y: taskbarTop,
               width: Layout.trayWidth, height: Layout.taskbar)
    }

    var showDesktopRect: CGRect {
        CGRect(x: screenSize.width - Layout.showDesktopWidth, y: taskbarTop,
               width: Layout.showDesktopWidth, height: Layout.taskbar)
    }

    /// Taskbar entries and where they are: a pinned app that is not open is just an icon, an open window
    /// gets a button with its title.
    var taskLayout: [(entry: TaskEntry, rect: CGRect)] {
        let entries = taskEntries
        let icons = entries.filter { $0.window == nil }.count
        let buttons = entries.count - icons
        let avail = trayRect.minX - Layout.taskItemX - 8 - CGFloat(icons) * (Layout.pinnedWidth + Layout.taskItemGap)
        let width = buttons == 0 ? 0 : max(Layout.taskItemMinWidth, min(Layout.taskItemMaxWidth,
            (avail - Layout.taskItemGap * CGFloat(buttons - 1)) / CGFloat(buttons)))
        var x = Layout.taskItemX
        return entries.map { entry in
            let w = entry.window == nil ? Layout.pinnedWidth : width
            defer { x += w + Layout.taskItemGap }
            return (entry, CGRect(x: x, y: taskbarTop + 4, width: w, height: Layout.buttonHeight))
        }
    }

    var launcherRect: CGRect {
        let cols = CGFloat(Layout.launcherColumns)
        let rows = CGFloat(max(1, (launcherItems.count + Layout.launcherColumns - 1) / Layout.launcherColumns))
        let t = Layout.launcherTile, g = Layout.launcherGap, pad = Layout.launcherPadding
        let w = pad * 2 + cols * t.width + (cols - 1) * g
        let h = pad * 2 + Layout.launcherHeader + rows * t.height + max(0, rows - 1) * g
        return CGRect(x: 8, y: taskbarTop - h - 8, width: w, height: h)
    }

    func launcherItemRect(_ i: Int) -> CGRect {
        let r = launcherRect, t = Layout.launcherTile, g = Layout.launcherGap, pad = Layout.launcherPadding
        let c = CGFloat(i % Layout.launcherColumns), row = CGFloat(i / Layout.launcherColumns)
        return CGRect(x: r.minX + pad + c * (t.width + g),
                      y: r.minY + pad + Layout.launcherHeader + row * (t.height + g),
                      width: t.width, height: t.height)
    }

    func iconRect(_ i: Int) -> CGRect {
        let c = Layout.iconCell, g = Layout.iconGap, o = Layout.iconOrigin
        let perColumn = max(1, Int((taskbarTop - o.y) / (c.height + g)))
        let col = CGFloat(i / perColumn), row = CGFloat(i % perColumn)
        return CGRect(x: o.x + col * (c.width + g), y: o.y + row * (c.height + g), width: c.width, height: c.height)
    }

    private func iconIndex(at p: CGPoint) -> Int? {
        items.indices.first { iconRect($0).contains(p) }
    }

    // MARK: Pointer & mouse

    func moveCursor(dx: CGFloat, dy: CGFloat) {
        var p = cursor.position
        p.x = min(max(0, p.x + dx), screenSize.width - 1)
        p.y = min(max(0, p.y + dy), screenSize.height - 1)
        cursor.position = p

        switch drag {
        case .none:
            updateHover(p)
        case let .move(id, offset):
            guard let w = window(id) else { return }
            w.frame.origin = CGPoint(x: p.x - offset.x, y: max(0, min(p.y - offset.y, taskbarTop - Layout.titleBar)))
            // Dragged to the left/right edge: half the screen; near a corner of it: a quarter.
            // To the top edge: maximize.
            let top = p.y < desktopArea.height * 0.2, bottom = p.y > desktopArea.height * 0.8
            let edge: CGFloat = 6       // the pointer stops at the screen edge; a touch in preview mode lands near it
            if p.x <= edge { snapTarget = top ? .topLeft : bottom ? .bottomLeft : .left }
            else if p.x >= screenSize.width - 1 - edge { snapTarget = top ? .topRight : bottom ? .bottomRight : .right }
            else if p.y <= edge { snapTarget = .maximize }
            else { snapTarget = nil }
            let preview = snapTarget.map(snapRect)
            if preview != snapPreview { snapPreview = preview }
        case let .resize(id, edges, start, sf):
            guard let w = window(id) else { return }
            let dx = p.x - start.x, dy = p.y - start.y
            let minW = Layout.minWindowSize.width, minH = Layout.minWindowSize.height
            var f = sf
            if edges.contains(.right) { f.size.width = max(minW, sf.width + dx) }
            if edges.contains(.left) {
                let nw = max(minW, sf.width - dx)
                f.origin.x = sf.maxX - nw
                f.size.width = nw
            }
            if edges.contains(.bottom) { f.size.height = max(minH, sf.height + dy) }
            if edges.contains(.top) {
                let nh = max(minH, sf.height - dy)
                f.origin.y = max(0, sf.maxY - nh)
                f.size.height = sf.maxY - f.origin.y
            }
            w.frame = f
        case let .guest(id):
            guard let w = window(id) else { return }
            let local = localPoint(p, in: w)
            Self.guestInput { GuestTouch.move(to: local) }
        }
    }

    /// Updates the pointer shape and sends hover events to the page under the pointer.
    private func updateHover(_ p: CGPoint) {
        if contextMenu != nil || (showLauncher && launcherRect.contains(p)) || p.y >= taskbarHitTop {
            cursor.setStyle(.arrow); return
        }
        guard let w = pointerWindow(at: p) else { cursor.setStyle(.arrow); return }
        let edges = resizeEdges(w, at: p)
        if !edges.isEmpty { cursor.setStyle(edges.cursorStyle); return }
        guard isOverContent(p, of: w), let web = w.webView else { cursor.setStyle(.arrow); return }

        let now = CACurrentMediaTime()
        if hoverInFlight && now - hoverStarted < 0.5 { hoverAgain = true; return }
        hoverInFlight = true
        hoverStarted = now
        WebInput.hover(web, at: localPoint(p, in: w)) { [weak self, weak w] style in
            guard let self else { return }
            self.hoverInFlight = false
            if case .none = self.drag, self.contextMenu == nil, let w,
               self.topWindow(at: self.cursor.position) === w, self.isOverContent(self.cursor.position, of: w) {
                self.cursor.setStyle(style)
            }
            if self.hoverAgain {
                self.hoverAgain = false
                if case .none = self.drag { self.updateHover(self.cursor.position) }
            }
        }
    }

    /// Press (start of a drag): drag the title bar to move, an edge/corner to resize.
    func mouseDown() {
        cursor.isPressed = true
        let p = cursor.position
        if contextMenu != nil || (showLauncher && launcherRect.contains(p)) { return }
        guard p.y < taskbarHitTop, let w = pointerWindow(at: p) else { return }
        focus(w)
        let edges = resizeEdges(w, at: p)
        if !edges.isEmpty {
            w.isMaximized = false
            w.isSnapped = false
            drag = .resize(w.id, edges: edges, start: p, startFrame: w.frame)
            cursor.setStyle(edges.cursorStyle)
        } else if w.frame.contains(p), !w.isFullscreen, p.y < w.frame.minY + Layout.titleBar,
                  !Layout.titleButtons(in: w.frame).contains(p) {
            if w.isMaximized || w.isSnapped, let r = w.restoreFrame {
                // Dragging a maximized/snapped window: restore its size, keeping the pointer at the same spot on the title bar.
                let rx = (p.x - w.frame.minX) / max(1, w.frame.width)
                w.isMaximized = false
                w.isSnapped = false
                w.frame = CGRect(x: p.x - r.width * rx, y: w.frame.minY, width: r.width, height: r.height)
            }
            drag = .move(w.id, offset: CGPoint(x: p.x - w.frame.minX, y: p.y - w.frame.minY))
            cursor.setStyle(.grab)
        } else if let guest = w.guestWindow, isOverContent(p, of: w) {
            // Press and drag in a guest app = put a finger down and move it (sliders, swipes…).
            let local = localPoint(p, in: w)
            Self.guestInput { Self.touchDown(at: local, in: guest) }
            drag = .guest(w.id)
        }
    }

    func mouseUp() {
        cursor.isPressed = false
        let wasDragging = isDragging
        if isGuestDrag { Self.guestInput { GuestTouch.end() } }
        if case let .move(id, _) = drag, let s = snapTarget, let w = window(id) { snap(w, s) }
        drag = .none
        snapTarget = nil
        snapPreview = nil
        if wasDragging {
            scheduleSave()
            updateHover(cursor.position)
        }
    }

    // Real mouse (GCMouse): press and release in place = click; press and move = drag.
    func physicalPress() {
        pressPoint = cursor.position
        mouseDown()
    }

    func physicalRelease() {
        let moved = pressPoint.map { hypot($0.x - cursor.position.x, $0.y - cursor.position.y) > 4 } ?? true
        let wasGuest = isGuestDrag      // the guest app already received the whole touch (down + up)
        mouseUp()
        if !moved && !wasGuest { click() }
        pressPoint = nil
    }

    func click() {
        let p = cursor.position
        flashPress()
        let now = CACurrentMediaTime()
        let isDouble = now - lastClickTime < 0.45 && hypot(p.x - lastClickPoint.x, p.y - lastClickPoint.y) < 10
        lastClickTime = isDouble ? 0 : now
        lastClickPoint = p

        if let menu = contextMenu {
            contextMenu = nil
            if let i = menu.items.indices.first(where: { menu.itemRect($0).contains(p) }),
               menu.items[i].enabled, let action = menu.items[i].action {
                action()
            }
            return
        }

        if showLauncher {
            let all = launcherItems
            for i in all.indices where launcherItemRect(i).contains(p) {
                showLauncher = false
                open(all[i])
                return
            }
            if launcherRect.contains(p) { return }
            showLauncher = false
            if startButtonRect.contains(p) { return }
        }

        if p.y >= taskbarHitTop { clickTaskbar(p); return }

        if let w = topWindow(at: p) {
            selectedIcon = nil
            focus(w)
            let f = w.frame
            if !w.isFullscreen {   // fullscreen: no title bar, the top-left corner is page content
                if Layout.closeButton(in: f).insetBy(dx: -4, dy: -4).contains(p) { close(w); return }
                if Layout.minimizeButton(in: f).insetBy(dx: -4, dy: -4).contains(p) { minimize(w); return }
                if Layout.maximizeButton(in: f).insetBy(dx: -4, dy: -4).contains(p) { toggleMaximize(w); return }
            }
            if !w.isFullscreen, p.y < f.minY + Layout.titleBar {
                if isDouble { toggleMaximize(w) }   // double click on the title bar = maximize / restore
                return
            }
            if let web = w.webView, !w.isFullscreen, Layout.addressRow(in: f).contains(p) {
                clickAddressBar(w, web, at: p)
                return
            }
            w.addressDraft = nil       // clicking the page leaves the address field
            if let guest = w.guestWindow {
                tapGuest(guest, at: localPoint(p, in: w), hold: 0.06)
            } else if let web = w.webView {
                WebInput.click(web, at: localPoint(p, in: w), count: isDouble ? 2 : 1)
            }
            return
        }

        // Desktop background: click selects an icon, double click opens it.
        focusedID = nil
        if let i = iconIndex(at: p) {
            if isDouble && selectedIcon == i {
                selectedIcon = nil
                open(items[i])
            } else {
                selectedIcon = i
            }
        } else {
            selectedIcon = nil
        }
    }

    /// Sends synthetic touches to the guest app on the next run loop turn instead of immediately.
    /// A mouse button or a real touch on the iPhone arrives as a touch event; sending another touch event to the
    /// guest window while UIKit is still dispatching the real one often gets the synthetic touch ignored
    /// (left clicks in the app did nothing). The main queue is FIFO, so down → move → up stay in order.
    private static func guestInput(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }

    /// Puts a finger down in the app's window that is on top at that point (an overlay window, or the main one).
    private static func touchDown(at point: CGPoint, in guest: UIWindow) {
        GuestRuntime.activateApp(with: guest)
        GuestTouch.begin(at: point, in: GuestRuntime.touchWindow(at: point, appWindow: guest))
    }

    /// Taps the guest app: finger down, then up after `hold` seconds.
    private func tapGuest(_ guest: UIWindow, at point: CGPoint, hold: TimeInterval) {
        guard !isGuestDrag else { return }
        Self.guestInput { Self.touchDown(at: point, in: guest) }
        DispatchQueue.main.asyncAfter(deadline: .now() + hold) { [weak self] in
            guard let self, !self.isGuestDrag else { return }
            GuestTouch.end()
        }
    }

    private func taskEntry(at p: CGPoint) -> TaskEntry? {
        taskLayout.first { $0.rect.contains(p) }?.entry
    }

    private func clickTaskbar(_ p: CGPoint) {
        if startButtonRect.contains(p) { showLauncher.toggle(); return }
        if showDesktopRect.contains(p) { toggleShowDesktop(); return }
        switch taskEntry(at: p) {
        case let .pinned(item, nil)?: open(item)
        case let entry?:
            guard let w = entry.window else { return }
            if focusedID == w.id && !w.isMinimized { minimize(w) } else { focus(w) }
        case nil: break
        }
    }

    // MARK: Right click

    func rightClick() {
        let p = cursor.position
        flashPress()
        contextMenu = nil

        // Start menu: an app's menu (open, pin), the menu stays open behind it.
        if showLauncher, launcherRect.contains(p) {
            let all = launcherItems
            if let i = all.indices.first(where: { launcherItemRect($0).contains(p) }) { presentMenu(itemMenu(all[i]), at: p) }
            return
        }
        showLauncher = false

        if p.y >= taskbarHitTop {
            guard let entry = taskEntry(at: p) else { presentMenu(desktopMenuItems(), at: p); return }
            var menu: [MenuItem] = []
            if let w = entry.window {
                menu = [
                    MenuItem(w.isMinimized ? "Show window" : "Minimize", w.isMinimized ? "macwindow" : "minus") { [weak self] in
                        guard let self else { return }
                        if w.isMinimized { self.focus(w) } else { self.minimize(w) }
                    },
                    MenuItem(w.isMaximized ? "Restore size" : "Maximize", "arrow.up.left.and.arrow.down.right") { [weak self] in
                        self?.focus(w); self?.toggleMaximize(w)
                    },
                    .separator,
                ]
            }
            // An app can be pinned from its window; a pinned app can be unpinned.
            let item: Shortcut? = {
                if case let .pinned(item, _) = entry { return item }
                guard let app = entry.window?.guestApp else { return nil }
                return items.first { $0.app == app }
            }()
            if let item {
                if entry.window == nil {
                    menu.append(MenuItem("Open", "arrow.up.forward.app") { [weak self] in self?.open(item) })
                }
                menu.append(MenuItem(isPinned(item) ? "Unpin from taskbar" : "Pin to taskbar",
                                     isPinned(item) ? "pin.slash" : "pin") { [weak self] in self?.togglePin(item) })
            }
            if let w = entry.window {
                menu += [.separator, MenuItem("Close window", "xmark") { [weak self] in self?.close(w) }]
            }
            presentMenu(menu, at: p)
            return
        }

        if let w = topWindow(at: p) {
            focus(w)
            if p.y < w.frame.minY + w.chromeHeight {
                presentMenu(windowMenuItems(w), at: p)
                return
            }
            if let guest = w.guestWindow {
                // Right click in a guest app = long press (iOS context menu).
                tapGuest(guest, at: localPoint(p, in: w), hold: 0.7)
                return
            }
            guard let web = w.webView else { return }
            WebInput.contextInfo(web, at: localPoint(p, in: w)) { [weak self, weak w] handled, href in
                // The page has its own context menu (Google Docs, Drive…): let it handle the click.
                guard let self, let w, !handled else { return }
                self.presentMenu(self.webMenuItems(w, web, link: href.flatMap(URL.init(string:))), at: p)
            }
            return
        }

        if let i = iconIndex(at: p) {
            selectedIcon = i
            presentMenu(itemMenu(items[i]), at: p)
            return
        }
        presentMenu(desktopMenuItems(), at: p)
    }

    private func presentMenu(_ items: [MenuItem], at p: CGPoint) {
        let h = items.reduce(Layout.menuPadding * 2) { $0 + $1.height }
        let w = Layout.menuWidth
        var x = p.x, y = p.y
        if x + w > screenSize.width { x = p.x - w }
        if y + h > screenSize.height { y = p.y - h }
        contextMenu = ContextMenu(items: items, frame: CGRect(x: max(0, x), y: max(0, y), width: w, height: h))
        cursor.setStyle(.arrow)
    }

    private func desktopMenuItems() -> [MenuItem] {
        let anyVisible = windows.contains { !$0.isMinimized }
        return [
            MenuItem("New window", "plus.rectangle.on.rectangle") { [weak self] in self?.newBrowserWindow() },
            .separator,
            MenuItem("Tile windows", "rectangle.split.2x2", enabled: anyVisible) { [weak self] in self?.tileWindows() },
            MenuItem("Cascade windows", "square.stack", enabled: anyVisible) { [weak self] in self?.cascadeWindows() },
            MenuItem(anyVisible ? "Show desktop" : "Show windows again", "menubar.dock.rectangle",
                     enabled: !windows.isEmpty) { [weak self] in self?.toggleShowDesktop() },
            .separator,
            MenuItem("Change wallpaper", "photo") { [weak self] in self?.nextWallpaper() },
        ]
    }

    private func windowMenuItems(_ w: DeskWindow) -> [MenuItem] {
        var items = [
            MenuItem(w.isMaximized ? "Restore size" : "Maximize",
                     w.isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") { [weak self] in
                self?.toggleMaximize(w)
            },
            MenuItem("Minimize", "minus") { [weak self] in self?.minimize(w) },
            MenuItem("Snap left", "rectangle.lefthalf.filled") { [weak self] in self?.snap(w, .left) },
            MenuItem("Snap right", "rectangle.righthalf.filled") { [weak self] in self?.snap(w, .right) },
            .separator,
        ]
        if w.isApp {
            // Like Samsung DeX: an app made for a phone can be shown at phone or tablet size, or turned sideways.
            items += [
                MenuItem("Phone size", "iphone") { [weak self] in self?.resizeApp(w, .phone) },
                MenuItem("Tablet size", "ipad") { [weak self] in self?.resizeApp(w, .tablet) },
                MenuItem("Landscape", "iphone.landscape") { [weak self] in self?.resizeApp(w, .landscape) },
                .separator,
            ]
        }
        if let web = w.webView {
            items += [MenuItem("Reload", "arrow.clockwise") { web.reload() }, .separator]
        }
        items.append(MenuItem("Close", "xmark") { [weak self] in self?.close(w) })
        return items
    }

    private func webMenuItems(_ w: DeskWindow, _ web: WKWebView, link: URL?) -> [MenuItem] {
        var items = [
            MenuItem("Back", "chevron.left", enabled: web.canGoBack) { web.goBack() },
            MenuItem("Forward", "chevron.right", enabled: web.canGoForward) { web.goForward() },
            MenuItem("Reload", "arrow.clockwise") { web.reload() },
        ]
        if let link {
            items += [
                .separator,
                MenuItem("Open link in new window", "macwindow.badge.plus") { [weak self] in self?.openWindow(link) },
                MenuItem("Copy link", "link") { UIPasteboard.general.url = link },
            ]
        }
        items += [
            .separator,
            MenuItem("Copy page address", "doc.on.doc") { UIPasteboard.general.url = w.currentURL },
        ]
        return items
    }

    func scroll(dx: CGFloat, dy: CGFloat) {
        let p = cursor.position
        guard contextMenu == nil, p.y < taskbarHitTop, let w = topWindow(at: p), isOverContent(p, of: w) else { return }
        if let guest = w.guestWindow {
            let local = localPoint(p, in: w)
            Self.guestInput {
                GuestTouch.scroll(at: local, in: GuestRuntime.touchWindow(at: local, appWindow: guest), dx: dx, dy: dy)
            }
        } else if let web = w.webView {
            WebInput.scroll(web, at: localPoint(p, in: w), dx: dx, dy: dy)
        }
    }

    private func localPoint(_ p: CGPoint, in w: DeskWindow) -> CGPoint {
        CGPoint(x: p.x - w.frame.minX, y: p.y - w.frame.minY - w.chromeHeight)
    }

    private func flashPress() {
        cursor.isPressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, !self.isDragging else { return }
            self.cursor.isPressed = false
        }
    }

    // MARK: Address bar

    private func clickAddressBar(_ w: DeskWindow, _ web: WKWebView, at p: CGPoint) {
        let f = w.frame
        if Layout.backButton(in: f).contains(p) { w.addressDraft = nil; web.goBack() }
        else if Layout.forwardButton(in: f).contains(p) { w.addressDraft = nil; web.goForward() }
        else if Layout.reloadButton(in: f).contains(p) {
            w.addressDraft = nil
            if web.isLoading { web.stopLoading() } else { web.reload() }
        }
        else if Layout.addressField(in: f).contains(p) { w.addressDraft = "" }
    }

    /// ⌘L (or a click on the field): type a new address for the focused web window.
    func focusAddressBar() {
        guard let w = focused, w.webView != nil, !w.isFullscreen else { return }
        w.addressDraft = ""
    }

    /// ⌘T / ⌘N: a new browser window, ready for an address.
    func newBrowserWindow() {
        openWindow("https://www.google.com")
        focusAddressBar()
    }

    private func commitAddress(_ w: DeskWindow) {
        let text = (w.addressDraft ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        w.addressDraft = nil
        guard !text.isEmpty, let web = w.webView else { return }
        web.load(URLRequest(url: Self.url(from: text)))
    }

    /// The focused web window whose address field is being edited, if any.
    private var editingAddress: DeskWindow? {
        guard let w = focused, w.addressDraft != nil else { return nil }
        return w
    }

    // MARK: Keyboard & navigation (act on the focused window)

    func typeText(_ s: String) {
        if showLauncher { launcherQuery += s; return }
        if let w = editingAddress { w.addressDraft? += s.replacingOccurrences(of: "\n", with: ""); return }
        if let guest = focused?.guestWindow { Self.inAppWindows(of: guest) { GuestTouch.insertText(s, in: $0) } }
        else if let web = focused?.webView { WebInput.type(web, text: s) }
    }
    func backspace() {
        if showLauncher { if !launcherQuery.isEmpty { launcherQuery.removeLast() }; return }
        if let w = editingAddress { if w.addressDraft?.isEmpty == false { w.addressDraft?.removeLast() }; return }
        if let guest = focused?.guestWindow { Self.inAppWindows(of: guest) { GuestTouch.deleteBackward(in: $0) } }
        else if let web = focused?.webView { WebInput.backspace(web) }
    }
    func pressEnter() {
        if showLauncher {
            if let first = launcherItems.first { showLauncher = false; open(first) }
            return
        }
        if let w = editingAddress { commitAddress(w); return }
        if let guest = focused?.guestWindow { Self.inAppWindows(of: guest) { GuestTouch.insertText("\n", in: $0) } }
        else if let web = focused?.webView { WebInput.enter(web) }
    }

    /// Typing goes to the text field that has focus, in whichever of the app's windows it is (top first).
    private static func inAppWindows(of guest: UIWindow, _ type: (UIWindow) -> Bool) {
        for window in GuestRuntime.windowsOfApp(with: guest).reversed() where type(window) { return }
    }

    func goBack() { focused?.webView?.goBack() }
    func goForward() { focused?.webView?.goForward() }
    func reload() { focused?.webView?.reload() }
    func closeFocused() { if let w = focused { close(w) } }
    func toggleLauncher() {
        guard isExternalConnected else { return }
        contextMenu = nil
        showLauncher.toggle()
    }
    func minimizeFocused() { if let w = focused { minimize(w) } }
    func sendKey(_ key: String, _ code: Int, _ shift: Bool) {
        if let web = focused?.webView { WebInput.key(web, key: key, keyCode: code, shift: shift) }
    }
    func selectAll() { if let web = focused?.webView { WebInput.selectAll(web) } }
    func copySelection() {
        guard let web = focused?.webView else { return }
        WebInput.selectedText(web) { s in if let s { UIPasteboard.general.string = s } }
    }
    func paste() { if let s = UIPasteboard.general.string, !s.isEmpty { typeText(s) } }

    /// Alt+Tab: shows the switcher with the previous window selected; each press selects the next one.
    /// Releasing the key (or a short pause) switches to it.
    func cycleWindows() {
        if var s = switcher {
            s.index = (s.index + 1) % s.ids.count
            switcher = s
        } else {
            let ids = windows.reversed().map(\.id)     // most recent first
            guard ids.count > 1 else { return }
            switcher = Switcher(ids: ids, index: 1)
            contextMenu = nil
            showLauncher = false
        }
        switcherCommit?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.commitSwitcher() }
        switcherCommit = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    func commitSwitcher() {
        switcherCommit?.cancel()
        guard let s = switcher else { return }
        switcher = nil
        if let w = window(s.ids[s.index]) { focus(w) }
    }

    enum AppSize { case phone, tablet, landscape }

    /// Sizes for an app window, fitted to the desktop and kept around the window's current centre.
    func resizeApp(_ w: DeskWindow, _ size: AppSize) {
        let a = desktopArea.insetBy(dx: 8, dy: 8)
        var content: CGSize
        switch size {
        case .phone: content = CGSize(width: 430, height: 800)
        case .tablet: content = CGSize(width: 820, height: 1100)
        case .landscape: content = CGSize(width: 800, height: 430)
        }
        let scale = min(1, a.width / content.width, (a.height - Layout.titleBar) / content.height)
        let s = CGSize(width: content.width * scale, height: content.height * scale + Layout.titleBar)
        let center = CGPoint(x: w.frame.midX, y: w.frame.midY)
        w.frame = CGRect(x: min(max(a.minX, center.x - s.width / 2), a.maxX - s.width),
                         y: min(max(a.minY, center.y - s.height / 2), a.maxY - s.height), width: s.width, height: s.height)
        w.isMaximized = false
        w.isSnapped = false
        focus(w)
    }

    /// Esc: close the open menu, otherwise send Esc to the page.
    func escape() {
        if switcher != nil { switcherCommit?.cancel(); switcher = nil; return }
        if contextMenu != nil { contextMenu = nil; return }
        if showLauncher { showLauncher = false; return }
        if let w = editingAddress { w.addressDraft = nil; return }
        if let w = focused, w.isFullscreen { w.exitFullscreen(); return }
        sendKey("Escape", 27, false)
    }

    static func url(from text: String) -> URL {
        if let u = URL(string: text), let s = u.scheme?.lowercased(), s == "http" || s == "https" { return u }
        if !text.contains(" "), text.contains("."), let u = URL(string: "https://" + text) { return u }
        var c = URLComponents(string: "https://www.google.com/search")!
        c.queryItems = [URLQueryItem(name: "q", value: text)]
        return c.url!
    }

    // MARK: Save / restore the session

    private struct SavedWindow: Codable {
        var url: String
        var x, y, w, h: Double
        var maximized: Bool
        var minimized: Bool
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private func saveNow() {
        saveWork?.cancel()
        // Guest app windows are not saved: a crashing app would take iDesk down on every launch.
        let saved = windows.filter { !$0.isApp }.map { w -> SavedWindow in
            let current = w.fullscreenRestore?.frame ?? w.frame
            let f = (w.isMaximized || w.isSnapped) ? (w.restoreFrame ?? current) : current
            return SavedWindow(url: w.currentURL.absoluteString, x: f.minX, y: f.minY, w: f.width, h: f.height,
                               maximized: w.isMaximized, minimized: w.isMinimized)
        }
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Keys.session)
        }
    }

    private func restoreSession() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Keys.session),
              let saved = try? JSONDecoder().decode([SavedWindow].self, from: data), !saved.isEmpty else { return false }
        let area = desktopArea
        for s in saved {
            guard let url = URL(string: s.url) else { continue }
            let w = min(CGFloat(s.w), area.width), h = min(CGFloat(s.h), area.height)
            let frame = CGRect(x: min(max(0, CGFloat(s.x)), area.maxX - w),
                               y: min(max(0, CGFloat(s.y)), area.maxY - h), width: w, height: h)
            let win = DeskWindow(url: url, frame: frame)
            if s.maximized {
                win.restoreFrame = frame
                win.frame = maximizedFrame
                win.isMaximized = true
            }
            win.isMinimized = s.minimized
            add(win)
        }
        focusedID = windows.last(where: { !$0.isMinimized })?.id
        return !windows.isEmpty
    }
}
