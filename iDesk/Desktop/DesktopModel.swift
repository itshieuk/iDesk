import UIKit
import SwiftUI
import WebKit
import Combine

// MARK: - Layout metrics (shared by drawing and hit testing)

enum Layout {
    static let titleBar: CGFloat = 34
    static let addressBar: CGFloat = 38            // web windows: back, forward, reload, address field
    static let taskbar: CGFloat = 48
    static let resizeGrip: CGFloat = 22
    static let edgeGrab: CGFloat = 10           // how far outside a window's edge it can still be grabbed to resize
    static let minWindowSize = CGSize(width: 360, height: 260)

    // Title bar buttons (close / minimize / maximize), relative to the window frame.
    static func closeButton(in f: CGRect) -> CGRect { CGRect(x: f.minX + 12, y: f.minY + 9, width: 16, height: 16) }
    static func minimizeButton(in f: CGRect) -> CGRect { CGRect(x: f.minX + 34, y: f.minY + 9, width: 16, height: 16) }
    static func maximizeButton(in f: CGRect) -> CGRect { CGRect(x: f.minX + 56, y: f.minY + 9, width: 16, height: 16) }
    static func titleButtons(in f: CGRect) -> CGRect { CGRect(x: f.minX + 8, y: f.minY + 5, width: 70, height: 24) }

    // Tabs of a web window, in its title bar after the three buttons, then a "+" for a new tab.
    static let tabsX: CGFloat = 84
    static func tabRect(_ i: Int, count: Int, in f: CGRect) -> CGRect {
        let avail = f.width - tabsX - 44
        let w = max(44, min(200, avail / CGFloat(max(1, count))))
        return CGRect(x: f.minX + tabsX + CGFloat(i) * w, y: f.minY + 4, width: w - 4, height: titleBar - 6)
    }
    static func tabCloseRect(_ i: Int, count: Int, in f: CGRect) -> CGRect {
        let t = tabRect(i, count: count, in: f)
        return CGRect(x: t.maxX - 22, y: t.midY - 8, width: 16, height: 16)
    }
    static func newTabRect(count: Int, in f: CGRect) -> CGRect {
        let last = tabRect(count - 1, count: count, in: f)
        return CGRect(x: min(last.maxX + 6, f.maxX - 32), y: f.minY + 5, width: 24, height: 24)
    }

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
    static let navX: CGFloat = 56                   // Android navigation buttons: Recent apps, Home, Back
    static let navWidth: CGFloat = 40
    static let navGap: CGFloat = 4
    static let workspaceX: CGFloat = navX + 3 * navWidth + 2 * navGap + 8   // workspace switcher: 1 2 3 4
    static let workspaceCell: CGFloat = 20
    static let workspaceWidth: CGFloat = 4 * workspaceCell
    static let taskItemX: CGFloat = workspaceX + workspaceWidth + 10
    static let taskItemMaxWidth: CGFloat = 200
    static let taskItemMinWidth: CGFloat = 48
    static let taskItemGap: CGFloat = 6
    static let pinnedWidth: CGFloat = 44           // a pinned app that is not open: icon only
    static let buttonHeight: CGFloat = 40
    static let trayWidth: CGFloat = 290
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

    // Recent apps
    static let recentsTile = CGSize(width: 300, height: 230)
    static let recentsGap: CGFloat = 24
    static let recentsTitle: CGFloat = 34          // icon + name above the thumbnail

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

// MARK: - Notifications

/// A notification from an app running in iDesk, shown on the desktop.
struct DeskNotification: Identifiable {
    let id = UUID()
    let app: GuestApp?
    let title: String
    let body: String
    let date = Date()
}

// MARK: - Pointer (separate so moving it does not redraw the whole desktop)

final class CursorModel: ObservableObject {
    @Published var position: CGPoint = CGPoint(x: 200, y: 200)
    @Published var isPressed = false
    @Published var isHidden = false              // while a screenshot is taken
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
        Shortcut(name: String(localized: "Files"), symbol: "folder.fill", url: DesktopPage.files.url.absoluteString, hue: 0.57),
        Shortcut(name: String(localized: "Settings"), symbol: "gearshape.fill", url: DesktopPage.settings.url.absoluteString, hue: 0.0),
    ]

    @Published var windows: [DeskWindow] = []      // order = stacking order (last = topmost)
    @Published var focusedID: UUID? {
        didSet {
            // Code no app can be found for on the call stack is attributed to the app the user works with.
            if let guest = focused?.guestWindow { GuestRuntime.activateApp(with: guest) }
            if focusedID != oldValue { Self.typingTargetChanged() }
        }
    }

    /// Typing now goes somewhere else: the iPhone's input method starts a new word (see KeyCaptureView).
    static func typingTargetChanged() {
        NotificationCenter.default.post(name: KeyCaptureView.resetNotification, object: nil)
    }
    @Published var screenSize: CGSize = CGSize(width: 1280, height: 720)
    @Published var isExternalConnected = false
    @Published var showLauncher = false {
        didSet {
            if !showLauncher { launcherQuery = "" }
            if showLauncher != oldValue { Self.typingTargetChanged() }
        }
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
    /// Recent apps (taskbar button or Win+Tab), like Android's overview: every window with a picture of it.
    /// Stays open until a window is picked, Esc or a click outside.
    @Published private(set) var recents: Switcher?
    @Published private(set) var thumbnails: [UUID: UIImage] = [:]
    /// Asks the iPhone screen to show one of its sheets (from the desktop's right-click menu).
    @Published var phoneSheet: PhoneSheet?
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
    /// How many windows can be open at once (0: no limit). Every app runs inside iDesk's own process, so each
    /// open one makes everything a little slower.
    @Published var maxWindows: Int = UserDefaults.standard.object(forKey: Keys.maxWindows) as? Int ?? 4 {
        didSet { UserDefaults.standard.set(maxWindows, forKey: Keys.maxWindows) }
    }
    /// The taskbar slides away and comes back when the pointer touches the bottom edge of the screen.
    @Published var autoHideTaskbar: Bool = UserDefaults.standard.bool(forKey: Keys.autoHideTaskbar) {
        didSet { UserDefaults.standard.set(autoHideTaskbar, forKey: Keys.autoHideTaskbar); updateHover(cursor.position) }
    }
    @Published private(set) var taskbarRevealed = false
    /// A picture of the window under the pointer on the taskbar.
    @Published private(set) var taskPreview: TaskPreview?
    private var taskPreviewWork: DispatchWorkItem?
    /// Quick panel (click the clock): quick toggles, brightness, notifications.
    @Published var showQuickPanel = false {
        didSet { if showQuickPanel { showLauncher = false; contextMenu = nil; banner = nil } }
    }
    @Published private(set) var notifications: [DeskNotification] = []
    /// The newest notification, shown for a few seconds at the top right.
    @Published private(set) var banner: DeskNotification?
    private var bannerWork: DispatchWorkItem?
    @Published var doNotDisturb: Bool = UserDefaults.standard.bool(forKey: Keys.doNotDisturb) {
        didSet { UserDefaults.standard.set(doNotDisturb, forKey: Keys.doNotDisturb) }
    }
    /// Clock and calendar on the desktop, behind the windows (One UI 8 added widgets to DeX).
    @Published var showWidgets: Bool = UserDefaults.standard.object(forKey: Keys.showWidgets) as? Bool ?? true {
        didSet { UserDefaults.standard.set(showWidgets, forKey: Keys.showWidgets) }
    }
    /// The keyboard shortcuts panel (Win + /).
    @Published var showShortcuts = false
    /// The workspace (virtual desktop) shown, 0…workspaceCount-1. Like Samsung DeX: four of them.
    @Published private(set) var workspace = 0
    static let workspaceCount = 4
    /// A short message on the desktop; goes away by itself.
    @Published private(set) var toast: String?
    private var toastWork: DispatchWorkItem?
    let cursor = CursorModel()

    private enum Keys {
        static let wallpaper = "iDesk.wallpaper"
        static let brightness = "iDesk.externalBrightness"
        static let session = "iDesk.session.v1"
        static let pinned = "iDesk.pinned"
        static let maxWindows = "iDesk.maxWindows"
        static let autoHideTaskbar = "iDesk.autoHideTaskbar"
        static let appFrames = "iDesk.appFrames"
        static let doNotDisturb = "iDesk.doNotDisturb"
        static let showWidgets = "iDesk.showWidgets"
    }

    private enum Drag {
        case none
        case move(UUID, offset: CGPoint)
        case resize(UUID, edges: ResizeEdges, start: CGPoint, startFrame: CGRect)
        case guest(UUID)            // holding a "finger" down in a guest app
    }
    enum Snap { case left, right, maximize, topLeft, topRight, bottomLeft, bottomRight }
    enum PhoneSheet { case apps, settings }

    struct TaskPreview {
        let id: UUID
        let title: String
        let image: UIImage?
        let anchor: CGRect
    }
    enum NavButton: CaseIterable { case recents, home, back }

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
    private var pagesSubscription: AnyCancellable?
    private var isDragging: Bool { if case .none = drag { return false } else { return true } }
    private var isGuestDrag: Bool { if case .guest = drag { return true } else { return false } }

    private init() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.saveNow() }
        appsSubscription = GuestStore.shared.$apps.sink { [weak self] in self?.apps = $0 }
        // Settings and Apps pages follow changes made anywhere (keys, quick panel, the iPhone, installs).
        pagesSubscription = objectWillChange.merge(with: GuestStore.shared.objectWillChange, SigningStore.shared.objectWillChange,
                                                   NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).map { _ in })
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { DesktopPages.refresh() }
        // A guest app opened an in-app browser (GuestRuntimeOpenURLNotification): a web window on the desktop.
        NotificationCenter.default.addObserver(forName: Notification.Name("iDeskGuestOpenURL"),
                                               object: nil, queue: .main) { [weak self] note in
            if let url = note.object as? URL { self?.openWindow(url.absoluteString) }
        }
        // A guest app's notification is due (GuestRuntimeNotificationNotification).
        NotificationCenter.default.addObserver(forName: Notification.Name("iDeskGuestNotification"),
                                               object: nil, queue: .main) { [weak self] note in
            self?.receiveGuestNotification(note.userInfo as? [String: String] ?? [:])
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
        entries += deskWindows.filter { !shown.contains($0.id) }.map { .window($0) }
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
    /// Where windows go: above the taskbar, or the whole screen when the taskbar hides itself.
    var desktopArea: CGRect {
        CGRect(x: 0, y: 0, width: screenSize.width, height: max(0, autoHideTaskbar ? screenSize.height : taskbarTop))
    }
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
        let page = DesktopPage(url)
        // iDesk's own pages (Files, Settings, Apps): one window each, brought to the front if already open;
        // they are light, so the window limit does not apply to them.
        if let page, let w = windows.first(where: { $0.tab(showing: page) != nil }), let i = w.tab(showing: page) {
            w.selectTab(i)
            focus(w)
            return
        }
        guard page != nil || canOpenAnother() else { return }
        let area = desktopArea
        let size = page.map { CGSize(width: min($0.windowSize.width, area.width - 16), height: min($0.windowSize.height, area.height - 16)) }
            ?? CGSize(width: min(1100, area.width * 0.72), height: min(760, area.height * 0.8))
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
        guard canOpenAnother(), let scene = PhoneWindow.current?.windowScene else { return }

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
            // Where the user left this app's window last time, if it still fits.
            let frame = rememberedFrame(of: app) ?? CGRect(origin: origin, size: size)
            let w = DeskWindow(app: app, window: guest, frame: frame)
            add(w)
            focusedID = w.id
        } catch {
            notice = LaunchDiagnostics.explain(error.localizedDescription)
        }
        // Guest apps tend to grab the key window: give the keyboard back to iDesk.
        PhoneWindow.current?.makeKey()
        PhoneWindow.current?.claimKeyboard()
    }

    /// Whether one more window fits under the limit. If not, says so and opens Recent apps to close one.
    private func canOpenAnother() -> Bool {
        guard maxWindows > 0, windows.count >= maxWindows else { return true }
        showToast(String(localized: "Up to \(maxWindows) windows can be open at once, so iDesk stays smooth. Close one to open another."))
        if recents == nil { showRecents() }
        return false
    }

    func showToast(_ text: String) {
        toast = text
        toastWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.toast = nil }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }

    /// Each app's window comes back where it was and at the size it had (Samsung DeX does this since One UI 8.5).
    private func rememberFrame(of w: DeskWindow) {
        guard let app = w.guestApp else { return }
        let current = w.fullscreenRestore?.frame ?? w.frame
        let f = (w.isMaximized || w.isSnapped) ? (w.restoreFrame ?? current) : current
        var frames = UserDefaults.standard.dictionary(forKey: Keys.appFrames) as? [String: String] ?? [:]
        frames[app.id] = NSCoder.string(for: f)
        UserDefaults.standard.set(frames, forKey: Keys.appFrames)
    }

    private func rememberedFrame(of app: GuestApp) -> CGRect? {
        guard let s = (UserDefaults.standard.dictionary(forKey: Keys.appFrames) as? [String: String])?[app.id] else { return nil }
        let f = NSCoder.cgRect(for: s), area = desktopArea
        guard f.width >= Layout.minWindowSize.width, f.height >= Layout.minWindowSize.height,
              f.width <= area.width, f.height <= area.height else { return nil }
        return CGRect(x: min(max(area.minX, f.minX), area.maxX - f.width),
                      y: min(max(area.minY, f.minY), area.maxY - f.height), width: f.width, height: f.height)
    }

    private func add(_ w: DeskWindow) {
        w.workspace = workspace
        w.onChange = { [weak self] in self?.scheduleSave() }
        w.onCloseRequest = { [weak self, weak w] in if let self, let w { self.close(w) } }
        w.onFullscreen = { [weak self, weak w] on in
            guard let self, let w else { return }
            self.setFullscreen(w, on)
        }
        windows.append(w)
    }

    func focus(_ w: DeskWindow) {
        if w.workspace != workspace { setWorkspace(w.workspace) }
        w.isMinimized = false
        if let i = windows.firstIndex(where: { $0.id == w.id }), i != windows.count - 1 {
            windows.append(windows.remove(at: i))
        }
        focusedID = w.id
    }

    func close(_ w: DeskWindow) {
        rememberFrame(of: w)
        w.webView?.stopLoading()
        if w.isApp, isGuestDrag { Self.guestInput { GuestTouch.cancel() }; drag = .none }
        windows.removeAll { $0.id == w.id }
        // Closing an app: it gets the "went to the background" events, so it stops playing and pauses.
        if let guest = w.guestWindow { GuestRuntime.suspendApp(with: guest) }
        focusedID = windows.last(where: { $0.isShown })?.id
        hoverInFlight = false
        scheduleSave()
    }

    func minimize(_ w: DeskWindow) {
        w.isMinimized = true
        if focusedID == w.id { focusedID = windows.last(where: { $0.isShown })?.id }
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
    var hasFullscreen: Bool { windows.contains { $0.isFullscreen && $0.isShown } }

    /// Top edge of the taskbar's hit area; none while a window is fullscreen and the taskbar is hidden.
    private var taskbarHitTop: CGFloat { taskbarVisible ? taskbarTop : .infinity }

    /// Hidden while a window is fullscreen; with auto-hide, shown only when the pointer is at the bottom edge or
    /// something that belongs to it is open.
    var taskbarVisible: Bool {
        !hasFullscreen && (!autoHideTaskbar || taskbarRevealed || showLauncher || showQuickPanel || recents != nil
                           || contextMenu != nil)
    }

    private func updateTaskbarReveal(_ p: CGPoint) {
        guard autoHideTaskbar else { return }
        let reveal = taskbarRevealed ? p.y >= taskbarTop - 8 : p.y >= screenSize.height - 3
        if reveal != taskbarRevealed { withAnimation(.easeOut(duration: 0.18)) { taskbarRevealed = reveal } }
    }

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
        let visible = windows.filter { $0.isShown }
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
        for (i, w) in windows.filter({ $0.isShown }).enumerated() {
            let step = CGFloat(i % 10) * 36
            w.frame = CGRect(origin: CGPoint(x: a.minX + 24 + step, y: a.minY + 24 + step), size: size)
            w.isMaximized = false
            w.isSnapped = false
        }
        scheduleSave()
    }

    /// "Show desktop" button: minimize everything, press again to restore.
    func toggleShowDesktop() {
        let visible = windows.filter { $0.isShown }
        if visible.isEmpty {
            for id in hiddenByShowDesktop { if let w = window(id), w.workspace == workspace { w.isMinimized = false } }
            hiddenByShowDesktop = []
            focusedID = windows.last(where: { $0.isShown })?.id
        } else {
            hiddenByShowDesktop = visible.map(\.id)
            visible.forEach { $0.isMinimized = true }
            focusedID = nil
        }
        scheduleSave()
    }

    // MARK: Workspaces

    /// The windows of the workspace shown, in stacking order.
    var deskWindows: [DeskWindow] { windows.filter { $0.workspace == workspace } }

    func setWorkspace(_ n: Int) {
        guard (0..<Self.workspaceCount).contains(n), n != workspace else { return }
        if isGuestDrag { Self.guestInput { GuestTouch.cancel() } }
        drag = .none
        contextMenu = nil
        showLauncher = false
        closeRecents()
        hiddenByShowDesktop = []
        workspace = n
        for w in windows { w.isOffDesk = w.workspace != n }
        focusedID = windows.last(where: { $0.isShown })?.id
        showToast(String(localized: "Workspace \(n + 1)"))
        updateHover(cursor.position)
        scheduleSave()
    }

    /// Win+Ctrl+← / →, four-finger swipe: the previous / next workspace (wraps around).
    func switchWorkspace(by step: Int) {
        guard isExternalConnected else { return }
        setWorkspace((workspace + step + Self.workspaceCount) % Self.workspaceCount)
    }

    func move(_ w: DeskWindow, toWorkspace n: Int) {
        guard (0..<Self.workspaceCount).contains(n), n != w.workspace else { return }
        w.workspace = n
        w.isOffDesk = n != workspace
        if focusedID == w.id, w.isOffDesk { focusedID = windows.last(where: { $0.isShown })?.id }
        showToast(String(localized: "Moved to workspace \(n + 1)"))
        scheduleSave()
    }

    /// Win+Ctrl+Shift+← / →: the focused window goes to the previous / next workspace, and the desktop follows it.
    func moveFocusedToWorkspace(by step: Int) {
        guard let w = focused else { return }
        w.workspace = (w.workspace + step + Self.workspaceCount) % Self.workspaceCount
        focus(w)
    }

    /// Three-finger swipe left / right: the next / previous app of this workspace, as Android's gesture navigation.
    func switchApp(forward: Bool) {
        let list = deskWindows
        guard list.count > 1 else { return }
        closeRecents()
        showLauncher = false
        focus(forward ? list[0] : list[list.count - 2])
    }

    func workspaceCellRect(_ n: Int) -> CGRect {
        CGRect(x: Layout.workspaceX + CGFloat(n) * Layout.workspaceCell, y: taskbarTop + 4,
               width: Layout.workspaceCell, height: Layout.buttonHeight)
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
        windows.reversed().first { $0.isShown && $0.frame.contains(p) }
    }

    /// Like topWindow but includes the outer border, to catch resize edges.
    private func pointerWindow(at p: CGPoint) -> DeskWindow? {
        let g = Layout.edgeGrab
        return windows.reversed().first { $0.isShown && $0.frame.insetBy(dx: -g, dy: -g).contains(p) }
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

    func navButtonRect(_ b: NavButton) -> CGRect {
        let i = CGFloat(NavButton.allCases.firstIndex(of: b)!)
        return CGRect(x: Layout.navX + i * (Layout.navWidth + Layout.navGap), y: taskbarTop + 4,
                      width: Layout.navWidth, height: Layout.buttonHeight)
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
            updateTaskbarReveal(p)
            updateHover(p)
        case let .move(id, offset):
            guard let w = window(id) else { return }
            // Some of the title bar always stays on screen, so the window can be dragged back.
            let keep: CGFloat = 120
            w.frame.origin = CGPoint(x: min(max(p.x - offset.x, keep - w.frame.width), screenSize.width - keep),
                                     y: max(0, min(p.y - offset.y, taskbarTop - Layout.titleBar)))
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
        updateTaskPreview(p)
        if contextMenu != nil || recents != nil || (showLauncher && launcherRect.contains(p)) || p.y >= taskbarHitTop
            || (showQuickPanel && quickPanelRect.contains(p)) || (banner != nil && bannerRect.contains(p)) {
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

    /// Hovering a window's button on the taskbar for a moment shows a picture of the window above it.
    private func updateTaskPreview(_ p: CGPoint) {
        let item = (p.y >= taskbarHitTop && contextMenu == nil && recents == nil && !showLauncher)
            ? taskLayout.first(where: { $0.rect.contains(p) && $0.entry.window != nil }) : nil
        guard let item, let w = item.entry.window else {
            taskPreviewWork?.cancel()
            if taskPreview != nil { taskPreview = nil }
            return
        }
        if taskPreview?.id == w.id { return }
        taskPreview = nil
        taskPreviewWork?.cancel()
        let work = DispatchWorkItem { [weak self, weak w] in
            guard let self, let w else { return }
            self.thumbnail(of: w) { [weak self] image in
                guard let self, self.taskLayout.first(where: { $0.rect.contains(self.cursor.position) })?.entry.window === w
                else { return }
                self.taskPreview = TaskPreview(id: w.id, title: w.title, image: image, anchor: item.rect)
            }
        }
        taskPreviewWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    /// Press (start of a drag): drag the title bar to move, an edge/corner to resize.
    func mouseDown() {
        cursor.isPressed = true
        let p = cursor.position
        if contextMenu != nil || recents != nil || (showLauncher && launcherRect.contains(p))
            || (showQuickPanel && quickPanelRect.contains(p)) { return }
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
        Self.typingTargetChanged()        // a click may put the caret in another field
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

        if showShortcuts { showShortcuts = false; return }
        if let r = recents { clickRecents(r, at: p); return }
        if showQuickPanel { clickQuickPanel(at: p); return }
        if let b = banner, bannerRect.contains(p) { openNotification(b); return }

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
                if w.webView != nil, clickTabs(w, at: p) { return }
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
        taskPreviewWork?.cancel()
        taskPreview = nil
        if startButtonRect.contains(p) { showLauncher.toggle(); return }
        if showDesktopRect.contains(p) { toggleShowDesktop(); return }
        if navButtonRect(.recents).contains(p) { toggleRecents(); return }
        if trayRect.contains(p) { showQuickPanel = true; return }
        if navButtonRect(.home).contains(p) { goHome(); return }
        if navButtonRect(.back).contains(p) { goBack(); return }
        if let n = (0..<Self.workspaceCount).first(where: { workspaceCellRect($0).contains(p) }) { setWorkspace(n); return }
        switch taskEntry(at: p) {
        case let .pinned(item, nil)?: open(item)
        case let entry?:
            guard let w = entry.window else { return }
            if focusedID == w.id && w.isShown { minimize(w) } else { focus(w) }
        case nil: break
        }
    }

    // MARK: Middle click

    /// Middle button, as in a desktop browser: on a tab it closes the tab, on a link it opens it in a background tab;
    /// on a window's taskbar button it closes the window.
    func middleClick() {
        let p = cursor.position
        flashPress()
        guard contextMenu == nil, recents == nil, !showQuickPanel else { return }
        if p.y >= taskbarHitTop {
            if let w = taskEntry(at: p)?.window { close(w) }
            return
        }
        guard let w = topWindow(at: p), !w.isFullscreen else { return }
        if w.webView != nil, p.y < w.frame.minY + Layout.titleBar {
            let n = w.tabs.count
            if let i = (0..<n).first(where: { Layout.tabRect($0, count: n, in: w.frame).contains(p) }) { closeTab(i, of: w) }
            return
        }
        guard let web = w.webView, isOverContent(p, of: w) else { return }
        WebInput.contextInfo(web, at: localPoint(p, in: w)) { [weak self, weak w] _, href in
            guard let self, let w, let link = href.flatMap(URL.init(string:)) else { return }
            w.newTab(link, activate: false)
            self.scheduleSave()
        }
    }

    // MARK: Right click

    func rightClick() {
        let p = cursor.position
        flashPress()
        contextMenu = nil
        if recents != nil { closeRecents(); return }
        if showQuickPanel { showQuickPanel = false; return }

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
        let anyVisible = windows.contains { $0.isShown }
        return [
            MenuItem("New window", "plus.rectangle.on.rectangle") { [weak self] in self?.newBrowserWindow() },
            .separator,
            MenuItem("Tile windows", "rectangle.split.2x2", enabled: anyVisible) { [weak self] in self?.tileWindows() },
            MenuItem("Cascade windows", "square.stack", enabled: anyVisible) { [weak self] in self?.cascadeWindows() },
            MenuItem(anyVisible ? "Show desktop" : "Show windows again", "menubar.dock.rectangle",
                     enabled: !windows.isEmpty) { [weak self] in self?.toggleShowDesktop() },
            .separator,
            MenuItem("Change wallpaper", "photo") { [weak self] in self?.nextWallpaper() },
            MenuItem(autoHideTaskbar ? "Always show the taskbar" : "Auto-hide the taskbar",
                     autoHideTaskbar ? "dock.rectangle" : "dock.arrow.down.rectangle") { [weak self] in
                self?.autoHideTaskbar.toggle()
            },
            MenuItem(showWidgets ? "Hide widgets" : "Show widgets", "clock") { [weak self] in self?.showWidgets.toggle() },
            MenuItem("Keyboard shortcuts", "keyboard") { [weak self] in self?.showShortcuts = true },
            .separator,
            MenuItem("Apps", "square.and.arrow.down") { [weak self] in self?.openPage(.apps) },
            MenuItem("Settings", "gearshape") { [weak self] in self?.openPage(.settings) },
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
            items += [
                MenuItem("New tab", "plus.square.on.square") { [weak self] in self?.newTab(in: w) },
                MenuItem("Reload", "arrow.clockwise") { web.reload() },
                .separator,
            ]
            if w.tabs.count > 1, let i = (0..<w.tabs.count).first(where: {
                Layout.tabRect($0, count: w.tabs.count, in: w.frame).contains(cursor.position) }) {
                items.insert(contentsOf: [
                    MenuItem("Close tab", "xmark.square") { [weak self] in self?.closeTab(i, of: w) },
                    MenuItem("Close other tabs", "xmark.square.fill") { [weak self] in
                        guard let self else { return }
                        let keep = w.tabs[i]
                        while w.tabs.count > 1 { if !w.closeTab(w.tabs.firstIndex(where: { $0 !== keep }) ?? 0) { break } }
                        self.scheduleSave()
                    },
                    .separator,
                ], at: 0)
            }
        }
        for n in 0..<Self.workspaceCount where n != w.workspace {
            items.append(MenuItem("Move to workspace \(n + 1)", "rectangle.stack") { [weak self] in self?.move(w, toWorkspace: n) })
        }
        items.append(.separator)
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
                MenuItem("Open link in new tab", "plus.square.on.square") { [weak self] in self?.newTab(in: w, url: link) },
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
        guard contextMenu == nil, recents == nil, !showQuickPanel, p.y < taskbarHitTop, let w = topWindow(at: p), isOverContent(p, of: w) else { return }
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
        CGPoint(x: p.x - w.frame.minX - w.guestRect.minX, y: p.y - w.frame.minY - w.chromeHeight - w.guestRect.minY)
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

    // MARK: Tabs

    /// A click in a web window's tab strip: a tab, its ×, or "+". False if it hit none of them.
    private func clickTabs(_ w: DeskWindow, at p: CGPoint) -> Bool {
        let f = w.frame, n = w.tabs.count
        if Layout.newTabRect(count: n, in: f).contains(p) { newTab(in: w); return true }
        for i in 0..<n where Layout.tabRect(i, count: n, in: f).contains(p) {
            if Layout.tabCloseRect(i, count: n, in: f).insetBy(dx: -3, dy: -3).contains(p) { closeTab(i, of: w) }
            else { w.selectTab(i) }
            return true
        }
        return false
    }

    private func newTab(in w: DeskWindow, url: URL = URL(string: "https://www.google.com")!) {
        w.newTab(url)
        focus(w)
        w.addressDraft = ""
        scheduleSave()
    }

    private func closeTab(_ i: Int, of w: DeskWindow) {
        if !w.closeTab(i) { close(w) }
        scheduleSave()
    }

    /// ⌘T: a new tab in the focused browser window (a new window when an app is focused).
    func newTabOrWindow() {
        if let w = focused, w.webView != nil, w.isShown { newTab(in: w) } else { newBrowserWindow() }
    }

    /// Ctrl+Tab (Shift: backwards): the next tab of the focused browser window; with one tab, the window switcher.
    func nextTab(backwards: Bool) {
        guard let w = focused, w.webView != nil, w.tabs.count > 1 else { cycleWindows(); return }
        w.selectTab((w.activeTab + (backwards ? -1 : 1) + w.tabs.count) % w.tabs.count)
    }

    /// ⌘1…9: that tab (9: the last one).
    func selectTab(number n: Int) {
        guard let w = focused, w.webView != nil, !w.tabs.isEmpty else { return }
        w.selectTab(n == 9 ? w.tabs.count - 1 : min(n - 1, w.tabs.count - 1))
    }

    // MARK: Files

    func openFiles() { openPage(.files) }

    /// Files, Settings or Apps in a window on the desktop.
    func openPage(_ page: DesktopPage) {
        showLauncher = false
        openWindow(page.url)
    }

    func refreshFilesPages() { windows.forEach { $0.refreshFilesPages() } }

    /// The iPhone's share sheet for a file: save it to Photos or Files, or send it to another app.
    func shareOnPhone(_ file: URL) {
        guard var top = PhoneWindow.current?.rootViewController else { return }
        while let p = top.presentedViewController, !p.isBeingDismissed { top = p }
        let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = top.view
        top.present(sheet, animated: true)
        showToast(String(localized: "Choose where to save it on the iPhone."))
    }

    private func commitAddress(_ w: DeskWindow) {
        let text = (w.addressDraft ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        w.addressDraft = nil
        guard !text.isEmpty else { return }
        w.load(Self.url(from: text))
    }

    /// The focused web window whose address field is being edited, if any.
    private var editingAddress: DeskWindow? {
        guard let w = focused, w.addressDraft != nil else { return nil }
        return w
    }

    // MARK: Keyboard & navigation (act on the focused window)

    func typeText(_ s: String) {
        if recents != nil { return }
        if showLauncher { launcherQuery += s; return }
        if let w = editingAddress { w.addressDraft? += s.replacingOccurrences(of: "\n", with: ""); return }
        if let guest = focused?.guestWindow { Self.inAppWindows(of: guest) { GuestTouch.insertText(s, in: $0) } }
        else if let web = focused?.webView { WebInput.type(web, text: s) }
    }
    func backspace() {
        if let r = recents {
            if r.ids.indices.contains(r.index), let w = window(r.ids[r.index]) { closeFromRecents(w) }
            return
        }
        if showLauncher { if !launcherQuery.isEmpty { launcherQuery.removeLast() }; return }
        if let w = editingAddress { if w.addressDraft?.isEmpty == false { w.addressDraft?.removeLast() }; return }
        if let guest = focused?.guestWindow { Self.inAppWindows(of: guest) { GuestTouch.deleteBackward(in: $0) } }
        else if let web = focused?.webView { WebInput.backspace(web) }
    }
    func pressEnter() {
        if recents != nil { commitRecents(); return }
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

    /// Android's Back (taskbar button, Esc in an app, Alt+←): closes what is open on top first, then goes back
    /// in the focused window — the previous page of a web window, the previous screen of an app.
    func goBack() {
        if recents != nil { closeRecents(); return }
        if showQuickPanel { showQuickPanel = false; return }
        if contextMenu != nil { contextMenu = nil; return }
        if showLauncher { showLauncher = false; return }
        guard let w = focused, w.isShown else { return }
        if w.addressDraft != nil { w.addressDraft = nil; return }
        if w.isFullscreen { w.exitFullscreen(); return }
        if let web = w.webView { web.goBack(); return }
        if let guest = w.guestWindow { Self.guestInput { GuestRuntime.goBackInApp(with: guest) } }
    }

    /// Home: every window out of the way, the desktop shows (pressed again, they come back).
    func goHome() {
        closeRecents()
        showLauncher = false
        contextMenu = nil
        toggleShowDesktop()
    }
    func goForward() { focused?.webView?.goForward() }
    func reload() { focused?.webView?.reload() }
    /// ⌘W: the tab shown, or the window when it has one tab (or is an app).
    func closeFocused() {
        guard let w = focused else { return }
        if w.webView != nil, w.tabs.count > 1 { closeTab(w.activeTab, of: w) } else { close(w) }
    }
    func toggleLauncher() {
        guard isExternalConnected else { return }
        contextMenu = nil
        showLauncher.toggle()
    }
    func minimizeFocused() { if let w = focused { minimize(w) } }
    func sendKey(_ key: String, _ code: Int, _ shift: Bool) {
        if recents != nil { moveRecentsSelection(key); return }
        if let web = focused?.webView { WebInput.key(web, key: key, keyCode: code, shift: shift) }
    }
    func selectAll() {
        if let guest = focused?.guestWindow { guestEdit(#selector(UIResponderStandardEditActions.selectAll(_:)), guest) }
        else if let web = focused?.webView { WebInput.selectAll(web) }
    }
    /// ⌘C / ⌘X / ⌘V: in an app, its own copy / cut / paste (so images and rich text work too); in a page, the
    /// selected text.
    func copySelection() {
        if let guest = focused?.guestWindow { guestEdit(#selector(UIResponderStandardEditActions.copy(_:)), guest); return }
        guard let web = focused?.webView else { return }
        WebInput.selectedText(web) { s in if let s { UIPasteboard.general.string = s } }
    }
    func cutSelection() {
        if let guest = focused?.guestWindow { guestEdit(#selector(UIResponderStandardEditActions.cut(_:)), guest); return }
        guard let web = focused?.webView else { return }
        WebInput.selectedText(web) { s in
            guard let s, !s.isEmpty else { return }
            UIPasteboard.general.string = s
            WebInput.backspace(web)
        }
    }
    func paste() {
        if editingAddress == nil, !showLauncher, let guest = focused?.guestWindow {
            Self.guestInput {
                if !GuestRuntime.windowsOfApp(with: guest).reversed().contains(where: {
                    GuestTouch.performEditAction(#selector(UIResponderStandardEditActions.paste(_:)), in: $0)
                }), let s = UIPasteboard.general.string { Self.inAppWindows(of: guest) { GuestTouch.insertText(s, in: $0) } }
            }
            return
        }
        if let s = UIPasteboard.general.string, !s.isEmpty { typeText(s) }
    }

    private func guestEdit(_ action: Selector, _ guest: UIWindow) {
        Self.guestInput { Self.inAppWindows(of: guest) { GuestTouch.performEditAction(action, in: $0) } }
    }

    // MARK: Screenshot

    /// PrtSc / Win+Shift+S: a picture of the whole external display, saved to Photos and to Files.
    func takeScreenshot() {
        showQuickPanel = false
        contextMenu = nil
        showShortcuts = false
        guard isExternalConnected, let view = ExternalSceneDelegate.desktopView else { return }
        cursor.isHidden = true
        // Give the desktop a moment to redraw without the panel and the pointer.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            let format = UIGraphicsImageRendererFormat()
            format.scale = view.window?.screen.scale ?? 1
            let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { _ in
                view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
            }
            self.cursor.isHidden = false
            let name = String(localized: "Screenshot") + " " + Self.fileDate.string(from: Date()) + ".png"
            try? image.pngData()?.write(to: FileStore.uniqueURL(in: FileStore.downloads, name: name))
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            self.showToast(String(localized: "Screenshot saved to Photos and Files"))
        }
    }

    private static let fileDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return f
    }()

    // MARK: Notifications & quick panel

    private func receiveGuestNotification(_ info: [String: String]) {
        let path = URL(fileURLWithPath: info["bundlePath"] ?? "").resolvingSymlinksInPath().path
        let app = apps.first { $0.bundleURL.resolvingSymlinksInPath().path == path }
        let title = info["title"].flatMap { $0.isEmpty ? nil : $0 } ?? app?.name ?? "iDesk"
        let body = [info["subtitle"], info["body"]].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        let n = DeskNotification(app: app, title: title, body: body)
        notifications.insert(n, at: 0)
        if notifications.count > 30 { notifications.removeLast(notifications.count - 30) }
        // No banner for the app the user is looking at, or with Do not disturb.
        guard isExternalConnected, !doNotDisturb, !(app != nil && focused?.guestApp == app) else { return }
        banner = n
        bannerWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.banner = nil }
        bannerWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    private func openNotification(_ n: DeskNotification) {
        notifications.removeAll { $0.id == n.id }
        banner = nil
        showQuickPanel = false
        if let app = n.app { openApp(app) }
    }

    var bannerRect: CGRect { CGRect(x: screenSize.width - 340, y: 12, width: 328, height: 72) }

    static let quickTileCount = 4
    private static let quickPad: CGFloat = 14, quickHeader: CGFloat = 52, quickTile: CGFloat = 64,
                       quickSlider: CGFloat = 36, quickGap: CGFloat = 12, quickListHeader: CGFloat = 30,
                       quickRow: CGFloat = 62

    var quickPanelRect: CGRect {
        let rows = notifications.isEmpty ? 0.7 : CGFloat(min(notifications.count, 5))
        let h = Self.quickPad * 2 + Self.quickHeader + Self.quickTile + Self.quickGap + Self.quickSlider + Self.quickGap
            + Self.quickListHeader + rows * Self.quickRow
        return CGRect(x: screenSize.width - 352, y: taskbarTop - h - 8, width: 344, height: h)
    }

    func quickTileRect(_ i: Int) -> CGRect {
        let r = quickPanelRect, gap: CGFloat = 6
        let w = (r.width - Self.quickPad * 2 - gap * CGFloat(Self.quickTileCount - 1)) / CGFloat(Self.quickTileCount)
        return CGRect(x: r.minX + Self.quickPad + CGFloat(i) * (w + gap), y: r.minY + Self.quickPad + Self.quickHeader,
                      width: w, height: Self.quickTile)
    }

    var quickSliderY: CGFloat { quickPanelRect.minY + Self.quickPad + Self.quickHeader + Self.quickTile + Self.quickGap }
    var brightnessDownRect: CGRect { CGRect(x: quickPanelRect.minX + Self.quickPad, y: quickSliderY, width: 36, height: 36) }
    var brightnessUpRect: CGRect { CGRect(x: quickPanelRect.maxX - Self.quickPad - 36, y: quickSliderY, width: 36, height: 36) }
    var notificationsTop: CGFloat { quickSliderY + Self.quickSlider + Self.quickGap }
    var clearNotificationsRect: CGRect {
        CGRect(x: quickPanelRect.maxX - Self.quickPad - 90, y: notificationsTop, width: 90, height: 26)
    }

    func notificationRect(_ i: Int) -> CGRect {
        CGRect(x: quickPanelRect.minX + Self.quickPad, y: notificationsTop + Self.quickListHeader + CGFloat(i) * Self.quickRow,
               width: quickPanelRect.width - Self.quickPad * 2, height: Self.quickRow - 6)
    }

    func notificationCloseRect(_ i: Int) -> CGRect {
        let r = notificationRect(i)
        return CGRect(x: r.maxX - 26, y: r.minY + 6, width: 20, height: 20)
    }

    private func clickQuickPanel(at p: CGPoint) {
        guard quickPanelRect.contains(p) else { showQuickPanel = false; return }
        switch (0..<Self.quickTileCount).first(where: { quickTileRect($0).contains(p) }) {
        case 0?: doNotDisturb.toggle()
        case 1?: autoHideTaskbar.toggle()
        case 2?: takeScreenshot()
        case 3?: showQuickPanel = false; openPage(.settings)
        default:
            if brightnessDownRect.contains(p) { externalBrightness = max(0.2, externalBrightness - 0.1) }
            else if brightnessUpRect.contains(p) { externalBrightness = min(1, externalBrightness + 0.1) }
            else if clearNotificationsRect.contains(p) { notifications = [] }
            else if let i = notifications.prefix(5).indices.first(where: { notificationRect($0).contains(p) }) {
                if notificationCloseRect(i).insetBy(dx: -4, dy: -4).contains(p) { notifications.remove(at: i) }
                else { openNotification(notifications[i]) }
            }
        }
    }

    func toggleQuickPanel() { guard isExternalConnected else { return }; showQuickPanel.toggle() }

    /// Alt+Tab: shows the switcher with the previous window selected; each press selects the next one.
    /// Releasing the key (or a short pause) switches to it.
    func cycleWindows() {
        if var s = switcher {
            s.index = (s.index + 1) % s.ids.count
            switcher = s
        } else {
            let ids = deskWindows.reversed().map(\.id)     // most recent first
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

    // MARK: Recent apps

    func toggleRecents() { if recents == nil { showRecents() } else { closeRecents() } }

    /// Win+Tab / the Recent apps button. Pressed again while open: selects the next window.
    func showRecents() {
        guard isExternalConnected else { return }
        if var r = recents {
            r.index = (r.index + 1) % r.ids.count
            recents = r
            return
        }
        let ids = windows.reversed().map(\.id)
        contextMenu = nil
        showLauncher = false
        switcher = nil
        recents = Switcher(ids: ids, index: ids.count > 1 ? 1 : 0)
        captureThumbnails()
        updateHover(cursor.position)
    }

    func closeRecents() {
        guard recents != nil else { return }
        recents = nil
        thumbnails = [:]          // pictures of every window are big: do not keep them around
    }

    private func commitRecents() {
        guard let r = recents, r.ids.indices.contains(r.index) else { closeRecents(); return }
        let id = r.ids[r.index]
        closeRecents()
        if let w = window(id) { focus(w) }
    }

    private func closeFromRecents(_ w: DeskWindow) {
        close(w)
        guard var r = recents else { return }
        r.ids.removeAll { $0 == w.id }
        thumbnails[w.id] = nil
        if r.ids.isEmpty { closeRecents(); return }
        r.index = min(r.index, r.ids.count - 1)
        recents = r
    }

    private func moveRecentsSelection(_ key: String) {
        guard var r = recents, !r.ids.isEmpty else { return }
        let cols = recentsColumns(r.ids.count)
        switch key {
        case "ArrowLeft": r.index = max(0, r.index - 1)
        case "ArrowRight", "Tab": r.index = min(r.ids.count - 1, r.index + 1)
        case "ArrowUp": r.index = max(0, r.index - cols)
        case "ArrowDown": r.index = min(r.ids.count - 1, r.index + cols)
        default: return
        }
        recents = r
    }

    private func clickRecents(_ r: Switcher, at p: CGPoint) {
        if recentsCloseAllRect(r.ids.count).contains(p) {
            for w in r.ids.compactMap(window) { close(w) }
            closeRecents()
            return
        }
        for i in r.ids.indices {
            guard let w = window(r.ids[i]) else { continue }
            if recentsCloseRect(i, of: r.ids.count).insetBy(dx: -4, dy: -4).contains(p) { closeFromRecents(w); return }
            if recentsTileRect(i, of: r.ids.count).contains(p) { closeRecents(); focus(w); return }
        }
        closeRecents()       // a click on the background, or on the taskbar button again
    }

    func recentsColumns(_ count: Int) -> Int {
        let fit = Int((screenSize.width - 2 * Layout.recentsGap) / (Layout.recentsTile.width + Layout.recentsGap))
        return max(1, min(count, fit, 4))
    }

    /// Tiles centred on the desktop, in rows; they get smaller when there are too many rows to fit.
    func recentsTileRect(_ i: Int, of count: Int) -> CGRect {
        let cols = recentsColumns(count)
        let rows = (count + cols - 1) / cols
        let g = Layout.recentsGap, t = Layout.recentsTile
        let area = desktopArea.insetBy(dx: g, dy: g + 30)
        let scale = min(1, (area.height - g * CGFloat(rows - 1)) / (CGFloat(rows) * t.height))
        let w = t.width * scale, h = t.height * scale
        let totalH = CGFloat(rows) * h + CGFloat(rows - 1) * g
        let row = i / cols, col = i % cols
        // The last row is centred on its own.
        let inRow = row == rows - 1 ? count - row * cols : cols
        let rowW = CGFloat(inRow) * w + CGFloat(inRow - 1) * g
        return CGRect(x: area.midX - rowW / 2 + CGFloat(col) * (w + g),
                      y: area.midY - totalH / 2 + CGFloat(row) * (h + g), width: w, height: h)
    }

    func recentsCloseRect(_ i: Int, of count: Int) -> CGRect {
        let t = recentsTileRect(i, of: count)
        return CGRect(x: t.maxX - 28, y: t.minY + 5, width: 24, height: 24)
    }

    func recentsCloseAllRect(_ count: Int) -> CGRect {
        CGRect(x: desktopArea.midX - 60, y: desktopArea.maxY - 52, width: 120, height: 36)
    }

    /// A picture of every window for Recent apps: web pages from WebKit, apps from their main window.
    private func captureThumbnails() {
        for w in windows {
            let id = w.id
            thumbnail(of: w) { [weak self] image in
                guard let self, self.recents != nil, let image else { return }
                self.thumbnails[id] = image
            }
        }
    }

    /// A small picture of a window's content: web pages from WebKit, apps from their main window.
    func thumbnail(of w: DeskWindow, completion: @escaping (UIImage?) -> Void) {
        if let web = w.webView {
            let config = WKSnapshotConfiguration()
            config.snapshotWidth = NSNumber(value: Double(Layout.recentsTile.width * 2))
            web.takeSnapshot(with: config) { image, _ in completion(image) }
        } else if let guest = w.guestWindow, let main = GuestRuntime.windowsOfApp(with: guest).first,
                  main.bounds.width > 0, main.bounds.height > 0 {
            let format = UIGraphicsImageRendererFormat()
            format.scale = min(2, Layout.recentsTile.width * 2 / main.bounds.width)
            completion(UIGraphicsImageRenderer(bounds: main.bounds, format: format).image { _ in
                main.drawHierarchy(in: main.bounds, afterScreenUpdates: false)
            })
        } else {
            completion(nil)
        }
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
    /// Esc: close the open menu; in an app, Back (as on Samsung DeX); otherwise send Esc to the page.
    func escape() {
        if switcher != nil { switcherCommit?.cancel(); switcher = nil; return }
        if recents != nil { closeRecents(); return }
        if showShortcuts { showShortcuts = false; return }
        if showQuickPanel { showQuickPanel = false; return }
        if contextMenu != nil { contextMenu = nil; return }
        if showLauncher { showLauncher = false; return }
        if let w = editingAddress { w.addressDraft = nil; return }
        if let w = focused, w.isFullscreen { w.exitFullscreen(); return }
        if focused?.isApp == true { goBack(); return }
        sendKey("Escape", 27, false)
    }

    static func url(from text: String) -> URL {
        if let u = URL(string: text), let s = u.scheme?.lowercased(), s == "http" || s == "https" || s == "idesk" { return u }
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
        var workspace: Int?
        var tabs: [String]?
        var activeTab: Int?
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private func saveNow() {
        saveWork?.cancel()
        windows.filter(\.isApp).forEach(rememberFrame)
        // Guest app windows are not saved: a crashing app would take iDesk down on every launch.
        let saved = windows.filter { !$0.isApp }.map { w -> SavedWindow in
            let current = w.fullscreenRestore?.frame ?? w.frame
            let f = (w.isMaximized || w.isSnapped) ? (w.restoreFrame ?? current) : current
            return SavedWindow(url: w.currentURL.absoluteString, x: f.minX, y: f.minY, w: f.width, h: f.height,
                               maximized: w.isMaximized, minimized: w.isMinimized, workspace: w.workspace,
                               tabs: w.tabs.indices.map { w.url(ofTab: $0).absoluteString }, activeTab: w.activeTab)
        }
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Keys.session)
        }
    }

    private func restoreSession() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Keys.session),
              let saved = try? JSONDecoder().decode([SavedWindow].self, from: data), !saved.isEmpty else { return false }
        let area = desktopArea
        for s in maxWindows > 0 ? Array(saved.suffix(maxWindows)) : saved {
            let tabs = (s.tabs ?? [s.url]).compactMap(URL.init(string:))
            guard let url = tabs.first ?? URL(string: s.url) else { continue }
            let w = min(CGFloat(s.w), area.width), h = min(CGFloat(s.h), area.height)
            let frame = CGRect(x: min(max(0, CGFloat(s.x)), area.maxX - w),
                               y: min(max(0, CGFloat(s.y)), area.maxY - h), width: w, height: h)
            let win = DeskWindow(url: url, frame: frame)
            for tab in tabs.dropFirst() { win.newTab(tab, activate: false) }
            win.selectTab(min(max(0, s.activeTab ?? 0), win.tabs.count - 1))
            if s.maximized {
                win.restoreFrame = frame
                win.frame = maximizedFrame
                win.isMaximized = true
            }
            win.isMinimized = s.minimized
            add(win)
            win.workspace = min(max(0, s.workspace ?? 0), Self.workspaceCount - 1)
            win.isOffDesk = win.workspace != workspace
        }
        focusedID = windows.last(where: { $0.isShown })?.id
        return !windows.isEmpty
    }
}
