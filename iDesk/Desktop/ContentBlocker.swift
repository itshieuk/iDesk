import WebKit

/// Blocks ads and trackers in web windows (Settings → Browser): requests to known ad and tracking servers are not
/// made, and the empty ad boxes they leave are hidden. On by default. Ads served from a site's own servers (for
/// example YouTube's) are not blocked.
enum ContentBlocker {
    static let key = "iDesk.blockAds"

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            applyToOpenTabs()
        }
    }

    private static var ruleList: WKContentRuleList?
    private static var compiling = false

    /// Compiles the rules once (WebKit keeps the compiled list on disk), then adds them to the tabs already open.
    static func prepare() {
        guard ruleList == nil, !compiling, let store = WKContentRuleListStore.default() else { return }
        compiling = true
        let id = "iDesk.blocker.v\(version)"
        store.lookUpContentRuleList(forIdentifier: id) { list, _ in
            if let list { finish(list); return }
            store.compileContentRuleList(forIdentifier: id, encodedContentRuleList: rulesJSON) { list, error in
                if let error { NSLog("iDesk: ad blocker rules failed: \(error)") }
                finish(list)
            }
        }
    }

    private static func finish(_ list: WKContentRuleList?) {
        DispatchQueue.main.async {
            compiling = false
            ruleList = list
            applyToOpenTabs()
        }
    }

    /// A new tab: the rules, when on.
    static func apply(to controller: WKUserContentController) {
        guard let ruleList else { prepare(); return }
        controller.remove(ruleList)
        if isEnabled { controller.add(ruleList) }
    }

    private static func applyToOpenTabs() {
        for w in DesktopModel.shared.windows {
            for tab in w.tabs { apply(to: tab.configuration.userContentController) }
        }
    }

    // MARK: Rules

    private static let version = 1

    /// Ad networks and trackers (international and Vietnamese). Blocked only as third-party requests, so the
    /// companies' own sites still open.
    private static let domains = [
        "doubleclick.net", "googlesyndication.com", "googleadservices.com", "adservice.google.com",
        "google-analytics.com", "amazon-adsystem.com", "adnxs.com", "taboola.com", "outbrain.com", "criteo.com",
        "criteo.net", "pubmatic.com", "rubiconproject.com", "openx.net", "casalemedia.com", "advertising.com",
        "adsrvr.org", "moatads.com", "scorecardresearch.com", "quantserve.com", "zedo.com", "smartadserver.com",
        "yieldmo.com", "sharethrough.com", "teads.tv", "media.net", "popads.net", "popcash.net", "propellerads.com",
        "adsterra.com", "exoclick.com", "juicyads.com", "mgid.com", "revcontent.com", "adform.net", "bidswitch.net",
        "33across.com", "indexww.com", "sonobi.com", "lijit.com", "contextweb.com", "gumgum.com",
        "onclickads.net", "hotjar.com", "yandex.ru/ads", "adcolony.com", "applovin.com", "unityads.unity3d.com",
        "admicro.vn", "adtimaserver.vn", "eclick.vn", "ambientplatform.vn", "yomedia.vn", "adnetwork.vn",
        "adpia.vn", "novanet.vn", "adx.vn", "vietad.vn",
    ]

    /// Boxes ad scripts draw into, hidden even when their request was blocked.
    private static let hiddenSelectors = [
        "ins.adsbygoogle", ".adsbygoogle", "div[id^=\"div-gpt-ad\"]", "iframe[id^=\"google_ads_iframe\"]",
        "[id^=\"taboola-\"]", ".trc_related_container", ".OUTBRAIN", "[data-google-query-id]",
    ]

    private static var rulesJSON: String {
        var rules: [[String: Any]] = Array(Set(domains)).sorted().map { domain in
            let parts = domain.split(separator: "/", maxSplits: 1).map(String.init)
            let host = NSRegularExpression.escapedPattern(for: parts[0])
            let path = parts.count > 1 ? "/" + NSRegularExpression.escapedPattern(for: parts[1]) : "[:/]"
            return [
                "trigger": ["url-filter": "^[^:]+://+([^:/]+\\.)?\(host)\(path)", "load-type": ["third-party"]],
                "action": ["type": "block"],
            ]
        }
        rules.append([
            "trigger": ["url-filter": ".*"],
            "action": ["type": "css-display-none", "selector": hiddenSelectors.joined(separator: ", ")],
        ])
        let data = (try? JSONSerialization.data(withJSONObject: rules)) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}

/// The text size of web pages and iDesk's pages (Settings → Display), and each tab's own zoom (Win + = / − / 0).
/// Done with CSS zoom on the page: the page lays itself out again for the window's width, as in a desktop browser,
/// instead of being magnified past the window's edges (which is what WKWebView.pageZoom does on iOS).
enum PageZoom {
    static let key = "iDesk.pageZoom"
    static let levels: [Double] = [0.9, 1, 1.15, 1.3, 1.5]

    static var standard: CGFloat {
        CGFloat(UserDefaults.standard.object(forKey: key) as? Double ?? 1)
    }

    /// Tabs zoomed with Win + = / −; the others follow the standard size.
    private static var tabZoom: [ObjectIdentifier: CGFloat] = [:]

    static func zoom(of web: WKWebView) -> CGFloat { tabZoom[ObjectIdentifier(web)] ?? standard }

    static func set(_ zoom: CGFloat, for web: WKWebView) {
        tabZoom[ObjectIdentifier(web)] = abs(zoom - standard) < 0.01 ? nil : zoom
        apply(to: web)
    }

    /// A new standard size: every tab not zoomed on its own follows it.
    static func set(_ value: Double) {
        UserDefaults.standard.set(value, forKey: key)
        for w in DesktopModel.shared.windows { for tab in w.tabs { apply(to: tab) } }
    }

    static func forget(_ web: WKWebView) { tabZoom[ObjectIdentifier(web)] = nil }

    /// Sets the page's zoom now and again once its document is there (called when a page starts and finishes).
    static func apply(to web: WKWebView) {
        let z = zoom(of: web)
        let value = abs(z - 1) < 0.01 ? "''" : "'\(z)'"
        web.evaluateJavaScript("""
        (function (z) {
          const set = () => { const d = document.documentElement; if (d && d.style.zoom !== z) d.style.zoom = z; };
          window.__ideskZoom = z ? parseFloat(z) : 1;
          set(); document.addEventListener('DOMContentLoaded', set);
        })(\(value))
        """)
    }
}
