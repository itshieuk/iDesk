import UIKit
import SwiftUI
import WebKit

/// iDesk's own pages, shown in ordinary desktop windows so they work with the pointer and keyboard like any page:
/// Files (idesk://files), Settings (idesk://settings) and Apps (idesk://apps).
enum DesktopPage: String {
    case files, settings, apps

    var url: URL { URL(string: "idesk://\(rawValue)")! }

    init?(_ url: URL?) {
        guard let url else { return nil }
        if url.scheme == "idesk", let page = DesktopPage(rawValue: url.host ?? "") { self = page; return }
        if url.isFileURL, FileStore.isFilesPage(url) { self = .files; return }
        return nil
    }

    /// Default window size for the page.
    var windowSize: CGSize {
        switch self {
        case .files: return CGSize(width: 820, height: 640)
        case .settings: return CGSize(width: 640, height: 760)
        case .apps: return CGSize(width: 700, height: 680)
        }
    }

    /// Loads the page into a tab. Settings and Apps are drawn from a state iDesk sends (see DesktopPages.state).
    func load(in webView: WKWebView) {
        switch self {
        case .files: webView.loadFileURL(FileStore.writeFilesPage(), allowingReadAccessTo: FileStore.downloads)
        case .settings, .apps: webView.loadHTMLString(DesktopPages.html(self), baseURL: url)
        }
    }
}

/// Builds the Settings and Apps pages and handles their buttons (on the main thread).
enum DesktopPages {
    static let messageName = "ideskPage"

    // MARK: State sent to the pages

    static func state(_ page: DesktopPage) -> [String: Any] {
        page == .apps ? appsState() : settingsState()
    }

    private static func settingsState() -> [String: Any] {
        let m = DesktopModel.shared
        let wallpapers = Wallpapers.all.map { colors in colors.map(cssColor) }
        return [
            "connected": m.isExternalConnected,
            "brightness": Int((m.externalBrightness * 100).rounded()),
            "resolutions": ExternalDisplay.resolutions.map(ExternalDisplay.name),
            "resolution": ExternalDisplay.resolution.map(ExternalDisplay.name) ?? "",
            "current": ExternalDisplay.currentResolution.map { "\(Int($0.width)) × \(Int($0.height))" } ?? "",
            "overscan": ExternalDisplay.fitsOverscan,
            "wallpaper": m.wallpaper,
            "wallpapers": wallpapers,
            "custom": customWallpaperThumbnail() ?? NSNull(),
            "autoHide": m.autoHideTaskbar,
            "widgets": m.showWidgets,
            "dnd": m.doNotDisturb,
            "maxWindows": m.maxWindows,
            "pointer": String(format: "%.1f×", Double(InputSettings.pointerSpeed)),
            "scroll": String(format: "%.1f×", Double(InputSettings.scrollSpeed)),
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
        ]
    }

    private static func appsState() -> [String: Any] {
        let store = GuestStore.shared, m = DesktopModel.shared
        let apps: [[String: Any]] = store.apps.map { app in
            let (status, tone) = status(of: app)
            let open = m.windows.contains { $0.guestApp == app }
            return [
                "id": app.id, "name": app.name, "icon": icon(of: app) ?? NSNull(),
                "status": status, "tone": tone, "open": open,
                "pinned": m.isPinned(Shortcut(name: app.name, symbol: "", url: "", hue: 0, app: app)),
                // A bundled app can only leave iDesk with the next reinstall: "remove" marks it, "keep" unmarks it.
                "removal": !app.isBundled || app.hasPendingUpdate ? "delete" : (app.pendingRemoval ? "keep" : "remove"),
            ]
        }
        var adding: Any = NSNull()
        if let p = store.installProgress, p.total > 1 {
            adding = String(localized: "Adding \(p.done + 1) of \(p.total)…")
        } else if store.isInstalling {
            adding = String(localized: "Adding…")
        }
        #if targetEnvironment(simulator)
        let canExport = false
        #else
        let canExport = store.hasPendingExport
        #endif
        return [
            "apps": apps,
            "total": store.totalSize > 0 ? ByteCountFormatter.string(fromByteCount: Int64(store.totalSize), countStyle: .file) : "",
            "adding": adding,
            "export": exportProgress.map { Int($0 * 100) } ?? NSNull(),
            "canExport": canExport && exportProgress == nil,
            "reinstallOnly": store.apps.contains(where: \.pendingRemoval)
                && !store.apps.contains(where: { !$0.isBundled || $0.hasPendingUpdate }),
        ]
    }

    /// Same wording as the Apps sheet on the iPhone.
    private static func status(of app: GuestApp) -> (String, String) {
        let size = ByteCountFormatter.string(fromByteCount: Int64(app.size), countStyle: .file)
        #if targetEnvironment(simulator)
        return (app.id, "muted")
        #else
        if app.pendingRemoval { return (String(localized: "Removed when iDesk is reinstalled · \(size)"), "bad") }
        if app.isBundled && !app.hasPendingUpdate { return (String(localized: "Ready · \(size)"), "good") }
        if GuestStore.canLoadOutsideBundle {
            return SigningStore.shared.identity == nil
                ? (String(localized: "Needs a certificate (Advanced)"), "warn")
                : (String(localized: "Ready (signed on device)"), "good")
        }
        return (String(localized: "Waiting to be installed into iDesk · \(size)"), "warn")
        #endif
    }

    private static var icons: [String: String] = [:]
    private static func icon(of app: GuestApp) -> String? {
        if let cached = icons[app.bundleURL.path] { return cached }
        guard let data = app.icon?.pngData() else { return nil }
        let url = "data:image/png;base64," + data.base64EncodedString()
        icons[app.bundleURL.path] = url
        return url
    }

    private static var customThumbnail: (image: UIImage, url: String)?
    private static func customWallpaperThumbnail() -> String? {
        guard let image = DesktopModel.shared.customWallpaper else { return nil }
        if let c = customThumbnail, c.image === image { return c.url }
        let size = CGSize(width: 192, height: 192 * image.size.height / max(1, image.size.width))
        let small = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = small.jpegData(compressionQuality: 0.7) else { return nil }
        let url = "data:image/jpeg;base64," + data.base64EncodedString()
        customThumbnail = (image, url)
        return url
    }

    private static func cssColor(_ color: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return "rgb(\(Int(r * 255)),\(Int(g * 255)),\(Int(b * 255)))"
    }

    // MARK: Updating open pages

    /// Sends the current state to every tab showing Settings or Apps.
    static func refresh() {
        for w in DesktopModel.shared.windows {
            for tab in w.tabs {
                guard let page = DesktopPage(tab.url), page != .files, !tab.isLoading else { continue }
                tab.evaluateJavaScript("window.render && render(\(json(state(page))))")
            }
        }
    }

    private static func json(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: Buttons

    private static var exportProgress: Double?

    static func handle(_ page: DesktopPage, action: String, value: String) {
        let m = DesktopModel.shared
        switch (page, action) {
        case (.settings, "brightness"):
            m.externalBrightness = min(1, max(0.2, m.externalBrightness + (Double(value) ?? 0)))
        case (.settings, "resolution"):
            let parts = value.split(separator: "x").compactMap { Double($0) }
            ExternalDisplay.resolution = parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : nil
        case (.settings, "overscan"):
            ExternalDisplay.fitsOverscan.toggle()
        case (.settings, "wallpaper"):
            if let i = Int(value) { m.wallpaper = i }
        case (.settings, "photo"):
            PhotoPicker.present { data in m.setCustomWallpaper(data) }
            m.showToast(String(localized: "Choose a photo on the iPhone."))
        case (.settings, "autoHide"): m.autoHideTaskbar.toggle()
        case (.settings, "widgets"): m.showWidgets.toggle()
        case (.settings, "dnd"): m.doNotDisturb.toggle()
        case (.settings, "maxWindows"):
            if let n = Int(value) { m.maxWindows = n }
        case (.settings, "pointer"):
            change(InputSettings.pointerKey, by: Double(value) ?? 0, default: InputSettings.defaultPointer, in: 0.6...4)
        case (.settings, "scroll"):
            change(InputSettings.scrollKey, by: Double(value) ?? 0, default: InputSettings.defaultScroll, in: 0.8...6)
        case (.settings, "resetSpeeds"):
            UserDefaults.standard.removeObject(forKey: InputSettings.pointerKey)
            UserDefaults.standard.removeObject(forKey: InputSettings.scrollKey)
        case (.apps, "open"):
            if let app = GuestStore.shared.apps.first(where: { $0.id == value }) { m.openApp(app) }
        case (.apps, "pin"):
            if let app = GuestStore.shared.apps.first(where: { $0.id == value }) {
                m.togglePin(Shortcut(name: app.name, symbol: "app.fill", url: "", hue: 0.5, app: app))
            }
        case (.apps, "delete"):
            if let app = GuestStore.shared.apps.first(where: { $0.id == value }) {
                if let w = m.windows.first(where: { $0.guestApp == app }) { m.close(w) }
                GuestStore.shared.remove(app)
            }
        case (.apps, "remove"), (.apps, "keep"):
            if let app = GuestStore.shared.apps.first(where: { $0.id == value }) { GuestStore.shared.toggleRemoval(app) }
        case (.apps, "add"):
            DocumentPicker.present(completion: addPicked)
            m.showToast(String(localized: "Choose the IPA files on the iPhone."))
        case (.apps, "export"):
            export()
        case (.apps, "advanced"):
            m.phoneSheet = .apps
            m.showToast(String(localized: "Certificates are on the iPhone screen."))
        default:
            break
        }
        refresh()
    }

    private static func change(_ key: String, by step: Double, default value: Double, in range: ClosedRange<Double>) {
        let current = UserDefaults.standard.object(forKey: key) as? Double ?? value
        UserDefaults.standard.set(min(range.upperBound, max(range.lowerBound, current + step)), forKey: key)
    }

    private static func addPicked(_ urls: [URL]) {
        let m = DesktopModel.shared
        let files = CertificateFiles.collect(urls)
        guard !files.ipas.isEmpty else {
            m.showToast(String(localized: "No IPA file chosen. Certificates are imported in Apps on the iPhone."))
            return
        }
        GuestStore.shared.install(ipas: files.ipas) { results in
            let added = results.filter { (try? $0.result.get()) != nil }.count
            #if targetEnvironment(simulator)
            m.showToast(GuestStore.summary(of: results))
            #else
            if GuestStore.canLoadOutsideBundle || added < results.count {
                m.showToast(GuestStore.summary(of: results))
            } else {
                export()      // as on the iPhone: package everything at once for the signing app
            }
            #endif
            refresh()
        }
        refresh()
    }

    /// Packages iDesk with the new apps, then opens the share sheet on the iPhone to pick the signing app.
    private static func export() {
        guard exportProgress == nil else { return }
        exportProgress = 0
        refresh()
        GuestStore.shared.exportForESign(progress: { value in
            DispatchQueue.main.async { if exportProgress != nil { exportProgress = value; refresh() } }
        }, completion: { result in
            exportProgress = nil
            refresh()
            switch result {
            case .success(let file):
                ShareSheet.present(file)
                DesktopModel.shared.showToast(String(localized: "Pick ESign (or your signing app) on the iPhone."))
            case .failure(let error):
                DesktopModel.shared.showToast(String(localized: "Could not create the file: \(error.localizedDescription)"))
            }
        })
    }

    // MARK: HTML

    static func html(_ page: DesktopPage) -> String {
        let strings: [String: String] = page == .apps ? [
            "title": String(localized: "Apps"),
            "sub": String(localized: "Apps installed from IPA files. They open as windows on this desktop."),
            "add": String(localized: "Add IPA files…"),
            "empty": String(localized: "No apps yet. Add a decrypted IPA file, or download one and install it from Files."),
            "open": String(localized: "Open"), "focus": String(localized: "Show"),
            "pin": String(localized: "Pin"), "unpin": String(localized: "Unpin"),
            "delete": String(localized: "Delete"), "remove": String(localized: "Remove from iDesk"),
            "keep": String(localized: "Keep"), "confirm": String(localized: "Click again"),
            "export": String(localized: "Install new apps into iDesk"),
            "reinstall": String(localized: "Reinstall iDesk (remove selected apps)"),
            "exportNote": String(localized: "iOS only runs code inside an installed app: package iDesk with the new apps, then sign and install it with ESign (or Feather, Scarlet…) on the iPhone."),
            "preparing": String(localized: "Preparing the install file…"),
            "advanced": String(localized: "Certificate (advanced)…"),
            "note": String(localized: "Several apps can run at once; each one uses memory, so iOS may close iDesk if too many are open."),
        ] : [
            "title": String(localized: "Settings"),
            "display": String(localized: "Display"), "brightness": String(localized: "Brightness"),
            "resolution": String(localized: "Resolution"), "auto": String(localized: "Automatic"),
            "resolutionNote": String(localized: "On a 4K screen, a lower resolution makes everything bigger. Now:"),
            "overscan": String(localized: "Fit the picture inside a TV's edges (overscan)"),
            "wallpaper": String(localized: "Wallpaper"), "photo": String(localized: "Choose a photo on the iPhone…"),
            "desktop": String(localized: "Desktop"),
            "autoHide": String(localized: "Auto-hide the taskbar"), "widgets": String(localized: "Clock and calendar widgets"),
            "dnd": String(localized: "Do not disturb (no notification pop-ups)"),
            "windows": String(localized: "Windows"), "maxWindows": String(localized: "Open at most"),
            "noLimit": String(localized: "No limit"),
            "windowsNote": String(localized: "Every app runs inside iDesk, so many open windows make everything slower."),
            "trackpad": String(localized: "Trackpad on the iPhone"), "pointer": String(localized: "Pointer speed"),
            "scroll": String(localized: "Scrolling speed"), "reset": String(localized: "Reset to defaults"),
            "about": String(localized: "Version"),
        ]
        let initial = json(state(page)), t = json(strings)
        return """
        <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
        <title>\(strings["title"] ?? "")</title>
        <style>
        :root { color-scheme: dark; }
        * { box-sizing: border-box; }
        body { margin: 0; padding: 26px 30px 40px; background: #161618; color: #eee; font: 15px -apple-system, sans-serif;
               user-select: none; -webkit-user-select: none; }
        h1 { font-size: 24px; margin: 0 0 4px; }
        h2 { font-size: 13px; text-transform: uppercase; letter-spacing: .04em; color: #8e8e93; margin: 26px 0 8px; }
        .sub, .note { color: #999; font-size: 13px; }
        .card { background: #232326; border-radius: 12px; padding: 4px 16px; }
        .row { display: flex; align-items: center; gap: 12px; min-height: 52px; border-top: 1px solid #2f2f33; }
        .row:first-child { border-top: 0; }
        .row .label { flex: 1; }
        button { background: #34343a; color: #eee; border: 0; border-radius: 8px; padding: 8px 13px; font: inherit;
                 font-size: 14px; cursor: pointer; }
        button:hover { background: #45454c; }
        button.primary { background: #0a84ff; color: #fff; }
        button.primary:hover { background: #3797ff; }
        button.danger { color: #ff8a80; }
        button:disabled { opacity: .45; }
        .round { width: 34px; height: 34px; padding: 0; border-radius: 17px; font-size: 18px; }
        .value { min-width: 56px; text-align: center; font-variant-numeric: tabular-nums; color: #ccc; }
        .switch { width: 46px; height: 28px; border-radius: 14px; background: #48484e; position: relative; flex: none; }
        .switch::after { content: ''; position: absolute; top: 3px; left: 3px; width: 22px; height: 22px; border-radius: 11px;
                         background: #fff; transition: left .15s; }
        .switch.on { background: #30d158; } .switch.on::after { left: 21px; }
        .seg { display: flex; gap: 6px; flex-wrap: wrap; }
        .seg button.on { background: #0a84ff; color: #fff; }
        .walls { display: flex; gap: 10px; flex-wrap: wrap; padding: 12px 0; }
        .wall { width: 110px; height: 62px; border-radius: 9px; border: 2px solid transparent; background-size: cover;
                background-position: center; cursor: pointer; }
        .wall.on { border-color: #0a84ff; } .wall:hover { border-color: #666; } .wall.on:hover { border-color: #0a84ff; }
        .app { display: flex; align-items: center; gap: 14px; padding: 12px 0; border-top: 1px solid #2f2f33; }
        .app:first-child { border-top: 0; }
        .app img, .app .noicon { width: 46px; height: 46px; border-radius: 11px; flex: none; background: #2a8; }
        .app .info { flex: 1; min-width: 0; }
        .app .name { font-weight: 600; }
        .app .status { font-size: 12px; margin-top: 3px; }
        .good { color: #30d158; } .warn { color: #ff9f0a; } .bad { color: #ff6961; } .muted { color: #8e8e93; }
        .actions { display: flex; gap: 6px; flex-wrap: wrap; justify-content: flex-end; }
        .head { display: flex; align-items: flex-end; gap: 12px; }
        .head .grow { flex: 1; }
        .bar { height: 8px; border-radius: 4px; background: #3a3a40; overflow: hidden; margin-top: 8px; }
        .bar div { height: 100%; background: #0a84ff; }
        </style></head><body><div id="root"></div>
        <script>
        const T = \(t);
        function send(action, value) {
          window.webkit.messageHandlers.\(messageName).postMessage({ action: action, value: value === undefined ? '' : String(value) });
        }
        function esc(s) { return String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
        // Destructive buttons ask for a second click (a page cannot show a dialog on the desktop).
        function twice(button, action, value) {
          if (!button.dataset.armed) {
            button.dataset.armed = '1'; const text = button.textContent; button.textContent = T.confirm;
            setTimeout(() => { delete button.dataset.armed; button.textContent = text; }, 3000);
            return;
          }
          send(action, value);
        }
        \(page == .apps ? appsScript : settingsScript)
        render(\(initial));
        </script></body></html>
        """
    }

    private static let settingsScript = #"""
    function toggle(key, on, label) {
      return `<div class="row" onclick="send('${key}')"><div class="label">${esc(label)}</div><div class="switch ${on ? 'on' : ''}"></div></div>`;
    }
    function stepper(key, label, value, step) {
      return `<div class="row"><div class="label">${esc(label)}</div>
        <button class="round" onclick="send('${key}', -${step})">−</button><div class="value">${esc(value)}</div>
        <button class="round" onclick="send('${key}', ${step})">+</button></div>`;
    }
    function render(s) {
      const key = JSON.stringify(s); if (key === window.__shown) return; window.__shown = key;
      let h = `<h1>${esc(T.title)}</h1>`;
      if (s.connected) {
        h += `<h2>${esc(T.display)}</h2><div class="card">${stepper('brightness', T.brightness, s.brightness + '%', 0.1)}`;
        if (s.resolutions.length > 1) {
          h += `<div class="row"><div class="label">${esc(T.resolution)}</div><div class="seg">`
            + `<button class="${s.resolution === '' ? 'on' : ''}" onclick="send('resolution', '')">${esc(T.auto)}</button>`;
          s.resolutions.forEach(r => {
            h += `<button class="${s.resolution === r ? 'on' : ''}" onclick="send('resolution', '${r}')">${r.replace('x', '×')}</button>`;
          });
          h += `</div></div>`;
        }
        h += toggle('overscan', s.overscan, T.overscan) + `</div>`;
        if (s.current) h += `<p class="note">${esc(T.resolutionNote)} ${esc(s.current)}</p>`;
      }
      h += `<h2>${esc(T.wallpaper)}</h2><div class="card"><div class="walls">`;
      s.wallpapers.forEach((c, i) => {
        h += `<div class="wall ${s.wallpaper === i ? 'on' : ''}" style="background-image:linear-gradient(135deg, ${c.join(',')})" onclick="send('wallpaper', ${i})"></div>`;
      });
      if (s.custom) h += `<div class="wall ${s.wallpaper < 0 ? 'on' : ''}" style="background-image:url(${s.custom})" onclick="send('wallpaper', -1)"></div>`;
      h += `</div><div class="row"><div class="label"></div><button onclick="send('photo')">${esc(T.photo)}</button></div></div>`;
      h += `<h2>${esc(T.desktop)}</h2><div class="card">` + toggle('autoHide', s.autoHide, T.autoHide)
        + toggle('widgets', s.widgets, T.widgets) + toggle('dnd', s.dnd, T.dnd) + `</div>`;
      h += `<h2>${esc(T.windows)}</h2><div class="card"><div class="row"><div class="label">${esc(T.maxWindows)}</div><div class="seg">`;
      [2, 3, 4, 6, 8, 0].forEach(n => {
        h += `<button class="${s.maxWindows === n ? 'on' : ''}" onclick="send('maxWindows', ${n})">${n ? n : esc(T.noLimit)}</button>`;
      });
      h += `</div></div></div><p class="note">${esc(T.windowsNote)}</p>`;
      h += `<h2>${esc(T.trackpad)}</h2><div class="card">` + stepper('pointer', T.pointer, s.pointer, 0.2)
        + stepper('scroll', T.scroll, s.scroll, 0.4)
        + `<div class="row"><div class="label"></div><button onclick="send('resetSpeeds')">${esc(T.reset)}</button></div></div>`;
      h += `<p class="note">iDesk ${esc(T.about)} ${esc(s.version)}</p>`;
      document.getElementById('root').innerHTML = h;
    }
    """#

    private static let appsScript = #"""
    function render(s) {
      const key = JSON.stringify(s); if (key === window.__shown) return; window.__shown = key;
      let h = `<div class="head"><div class="grow"><h1>${esc(T.title)}</h1><div class="sub">${esc(T.sub)}</div></div>`;
      h += `<button class="primary" ${s.adding ? 'disabled' : ''} onclick="send('add')">${esc(s.adding || T.add)}</button></div>`;
      if (s.export !== null) {
        h += `<h2>${esc(T.preparing)}</h2><div class="card" style="padding:14px 16px"><div class="bar"><div style="width:${s.export}%"></div></div></div>`;
      } else if (s.canExport) {
        h += `<h2></h2><div class="card" style="padding:14px 16px"><button class="primary" onclick="send('export')">${esc(s.reinstallOnly ? T.reinstall : T.export)}</button>
          <p class="note">${esc(T.exportNote)}</p></div>`;
      }
      h += `<h2>${esc(s.total)}</h2><div class="card">`;
      if (!s.apps.length) h += `<p class="note" style="padding:10px 0">${esc(T.empty)}</p>`;
      s.apps.forEach(a => {
        const id = esc(a.id).replace(/'/g, '');
        h += `<div class="app">${a.icon ? `<img src="${a.icon}">` : '<div class="noicon"></div>'}
          <div class="info"><div class="name">${esc(a.name)}</div><div class="status ${a.tone}">${esc(a.status)}</div></div>
          <div class="actions"><button class="primary" onclick="send('open','${id}')">${esc(a.open ? T.focus : T.open)}</button>
          <button onclick="send('pin','${id}')">${esc(a.pinned ? T.unpin : T.pin)}</button>
          <button class="danger" onclick="twice(this,'${a.removal}','${id}')">${esc(T[a.removal])}</button></div></div>`;
      });
      h += `</div><p class="note">${esc(T.note)}</p>`;
      h += `<p><button onclick="send('advanced')">${esc(T.advanced)}</button></p>`;
      document.getElementById('root').innerHTML = h;
    }
    """#
}

/// Buttons on the Settings and Apps pages. Only iDesk's own pages may use it.
final class PageBridge: NSObject, WKScriptMessageHandler {
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let url = message.webView?.url, url.scheme == "idesk",
              let page = DesktopPage(url), page != .files,
              let body = message.body as? [String: String], let action = body["action"] else { return }
        DesktopPages.handle(page, action: action, value: body["value"] ?? "")
    }
}
