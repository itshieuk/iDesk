import UIKit
import WebKit

/// A window on the desktop: a browser with tabs, or an app installed from an IPA.
final class DeskWindow: NSObject, ObservableObject, Identifiable, WKUIDelegate, WKNavigationDelegate {
    let id = UUID()
    @Published var frame: CGRect
    @Published var title = String(localized: "New window")
    @Published var isMinimized = false
    @Published var isMaximized = false
    /// The workspace (virtual desktop) it is on, and whether that is another one than the one shown.
    var workspace = 0
    @Published var isOffDesk = false
    /// On screen: neither minimized nor on another workspace.
    var isShown: Bool { !isMinimized && !isOffDesk }
    var isSnapped = false           // snapped to a half or a quarter of the screen
    var snap: DesktopModel.Snap?    // which one, while isSnapped
    var restoreFrame: CGRect?
    let initialURL: URL
    let guestApp: GuestApp?         // window of an app installed from an IPA
    let guestWindow: UIWindow?
    var isApp: Bool { guestWindow != nil }
    var onChange: (() -> Void)?

    // Tabs (web windows)
    @Published private(set) var tabs: [WKWebView] = []
    @Published private(set) var activeTab = 0
    /// The tab shown; nil for an app window.
    var webView: WKWebView? { tabs.indices.contains(activeTab) ? tabs[activeTab] : nil }

    // Fullscreen (requested by the page through the Fullscreen API, see WebFullscreen.swift)
    @Published var isFullscreen = false
    var fullscreenRestore: (frame: CGRect, maximized: Bool, snapped: Bool)?
    var fullscreenFrame: WKFrameInfo?
    var onFullscreen: ((Bool) -> Void)?
    private let fullscreenBridge = WebFullscreenBridge()
    private let filesBridge = FilesBridge()

    /// Height of what is above the content: title bar (with the tabs), plus the address bar of a web window.
    /// None in fullscreen.
    var chromeHeight: CGFloat { isFullscreen ? 0 : Layout.titleBar + (guestWindow == nil ? Layout.addressBar : 0) }

    // Address bar
    /// What is being typed in the address field; nil while the field is not being edited.
    @Published var addressDraft: String?
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isLoading = false
    private var activeObservations: [NSKeyValueObservation] = []
    private var titleObservations: [ObjectIdentifier: NSKeyValueObservation] = [:]

    /// The page shown, as it is saved and restored ("idesk://files" for the Files page).
    var currentURL: URL {
        guard let url = webView?.url else { return initialURL }
        return FileStore.isFilesPage(url) ? FileStore.filesURL : url
    }

    func url(ofTab i: Int) -> URL {
        guard tabs.indices.contains(i), let url = tabs[i].url else { return initialURL }
        return FileStore.isFilesPage(url) ? FileStore.filesURL : url
    }

    /// A window hosting a guest app launched by GuestRuntime.
    init(app: GuestApp, window: UIWindow, frame: CGRect) {
        self.frame = frame
        self.initialURL = app.bundleURL
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
        super.init()
        fullscreenBridge.window = self
        filesBridge.window = self
        newTab(url)
    }

    deinit {
        for tab in tabs { Self.detach(tab) }
    }

    // MARK: Tabs

    func newTab(_ url: URL, activate: Bool = true) {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.preferredContentMode = .desktop   // request desktop websites
        config.userContentController.addUserScript(WebFullscreen.script)
        config.userContentController.add(fullscreenBridge, name: WebFullscreen.messageName)
        config.userContentController.add(filesBridge, name: FilesBridge.messageName)
        let tab = WKWebView(frame: CGRect(origin: .zero, size: frame.size), configuration: config)
        tab.uiDelegate = self
        tab.navigationDelegate = self
        titleObservations[ObjectIdentifier(tab)] = tab.observe(\.title) { [weak self] _, _ in
            DispatchQueue.main.async { self?.tabTitleChanged() }
        }
        tabs.append(tab)
        Self.load(url, in: tab)
        if activate || tabs.count == 1 { selectTab(tabs.count - 1) }
        onChange?()
    }

    func selectTab(_ i: Int) {
        guard tabs.indices.contains(i) else { return }
        if isFullscreen, i != activeTab { exitFullscreen() }
        activeTab = i
        addressDraft = nil
        let tab = tabs[i]
        activeObservations = [
            tab.observe(\.url) { [weak self] _, _ in DispatchQueue.main.async { self?.onChange?(); self?.objectWillChange.send() } },
            tab.observe(\.canGoBack, options: [.initial]) { [weak self] wv, _ in DispatchQueue.main.async { self?.canGoBack = wv.canGoBack } },
            tab.observe(\.canGoForward, options: [.initial]) { [weak self] wv, _ in DispatchQueue.main.async { self?.canGoForward = wv.canGoForward } },
            tab.observe(\.isLoading, options: [.initial]) { [weak self] wv, _ in DispatchQueue.main.async { self?.isLoading = wv.isLoading } },
        ]
        tabTitleChanged()
        onChange?()
    }

    /// Closes a tab; false if it was the last one (the caller closes the window instead).
    @discardableResult
    func closeTab(_ i: Int) -> Bool {
        guard tabs.count > 1, tabs.indices.contains(i) else { return false }
        let tab = tabs.remove(at: i)
        tab.stopLoading()
        Self.detach(tab)
        titleObservations[ObjectIdentifier(tab)] = nil
        selectTab(i < activeTab || activeTab >= tabs.count ? max(0, activeTab - 1) : activeTab)
        return true
    }

    func title(ofTab i: Int) -> String {
        guard tabs.indices.contains(i) else { return "" }
        let t = tabs[i].title ?? ""
        return t.isEmpty ? (tabs[i].url?.host ?? String(localized: "New tab")) : t
    }

    private func tabTitleChanged() {
        if webView != nil { title = title(ofTab: activeTab) }
        objectWillChange.send()
    }

    private static func detach(_ tab: WKWebView) {
        tab.configuration.userContentController.removeScriptMessageHandler(forName: WebFullscreen.messageName)
        tab.configuration.userContentController.removeScriptMessageHandler(forName: FilesBridge.messageName)
    }

    /// Opens an address in the tab shown; "idesk://files" is the Files page.
    func load(_ url: URL) {
        guard let webView else { return }
        Self.load(url, in: webView)
    }

    private static func load(_ url: URL, in webView: WKWebView) {
        if FileStore.isFilesPage(url) {
            webView.loadFileURL(FileStore.writeFilesPage(), allowingReadAccessTo: FileStore.downloads)
        } else {
            webView.load(URLRequest(url: url))
        }
    }

    /// Reloads the Files pages after a download or a deletion.
    func refreshFilesPages() {
        for tab in tabs where tab.url.map(FileStore.isFilesPage) == true {
            tab.loadFileURL(FileStore.writeFilesPage(), allowingReadAccessTo: FileStore.downloads)
        }
    }

    /// Asks the page to leave fullscreen (it reports back so iDesk restores the window).
    func exitFullscreen() {
        guard let webView else { onFullscreen?(false); return }
        webView.evaluateJavaScript(WebFullscreen.exitScript, in: fullscreenFrame, in: .page) { [weak self] result in
            // The page did not answer (navigated away, iframe gone…): leave on our own.
            if case .failure = result, self?.isFullscreen == true { self?.onFullscreen?(false) }
        }
    }

    // MARK: Navigation

    // Navigating while in fullscreen: the new page is no longer fullscreen.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if isFullscreen, webView === self.webView { onFullscreen?(false) }
    }

    // target=_blank links and window.open: a new tab, as in a desktop browser.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { newTab(url) }
        return nil
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if navigationAction.shouldPerformDownload { decisionHandler(.download); return }
        if let url = navigationAction.request.url, url.scheme == FileStore.filesURL.scheme {
            decisionHandler(.cancel)
            Self.load(url, in: webView)
            return
        }
        decisionHandler(.allow)
    }

    /// Files the page cannot show (or that the site marks as attachments) are downloaded to Files.
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
        let disposition = (navigationResponse.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition")
        let attachment = disposition?.lowercased().hasPrefix("attachment") == true
        decisionHandler(navigationResponse.isForMainFrame && (attachment || !navigationResponse.canShowMIMEType)
                        ? .download : .allow)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = Downloads.shared
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = Downloads.shared
    }
}
