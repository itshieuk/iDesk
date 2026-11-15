import UIKit
import WebKit

/// Downloads and screenshots, kept in Documents/Downloads and listed by the Files page ("idesk://files"),
/// which is an ordinary web window showing a page iDesk writes, so clicking, scrolling and typing work as in any page.
enum FileStore {
    static let filesURL = URL(string: "idesk://files")!
    private static let pageName = ".iDesk-files.html"

    static var downloads: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// "idesk://files", or the page iDesk writes for it. A file opened from Files (a downloaded web page) is not:
    /// it must not get the Files buttons (delete, share).
    static func isFilesPage(_ url: URL) -> Bool {
        if url.scheme == filesURL.scheme { return url.host == filesURL.host }
        guard url.isFileURL else { return false }
        return url.standardizedFileURL.path == downloads.appendingPathComponent(pageName).standardizedFileURL.path
    }

    /// A name that is not taken yet: "file.pdf", "file 2.pdf", …
    static func uniqueURL(in folder: URL, name: String) -> URL {
        let clean = name.replacingOccurrences(of: "/", with: "-")
        let base = (clean as NSString).deletingPathExtension, ext = (clean as NSString).pathExtension
        var url = folder.appendingPathComponent(clean.isEmpty ? "download" : clean)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
            n += 1
        }
        return url
    }

    struct Item {
        let url: URL
        let size: Int
        let date: Date
    }

    static func items() -> [Item] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: downloads, includingPropertiesForKeys: keys,
                                                                 options: [.skipsHiddenFiles])) ?? []
        return urls.compactMap { url in
            let v = try? url.resourceValues(forKeys: Set(keys))
            guard v?.isDirectory != true else { return nil }
            return Item(url: url, size: v?.fileSize ?? 0, date: v?.contentModificationDate ?? .distantPast)
        }
        .sorted { $0.date > $1.date }
    }

    /// Writes the Files page for the current contents of Downloads and returns its address.
    static func writeFilesPage() -> URL {
        let page = downloads.appendingPathComponent(pageName)
        try? html(items()).write(to: page, atomically: true, encoding: .utf8)
        return page
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func symbol(for ext: String) -> String {
        switch ext.lowercased() {
        case "png", "jpg", "jpeg", "gif", "heic", "webp": return "🖼️"
        case "mp4", "mov", "m4v", "webm": return "🎬"
        case "mp3", "m4a", "wav", "aac", "flac": return "🎵"
        case "pdf": return "📕"
        case "zip", "rar", "7z", "gz": return "🗜️"
        case "ipa": return "📦"
        case "txt", "md", "csv", "json": return "📝"
        default: return "📄"
        }
    }

    private static func html(_ items: [Item]) -> String {
        let size = ByteCountFormatter()
        let date = DateFormatter()
        date.dateStyle = .medium
        date.timeStyle = .short
        let rows = items.map { item -> String in
            let name = item.url.lastPathComponent
            let href = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            let js = escape(name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'"))
            let install = item.url.pathExtension.lowercased() == "ipa"
                ? "<button onclick=\"act('install','\(js)')\">\(escape(String(localized: "Install")))</button>" : ""
            return """
            <tr><td class="icon">\(symbol(for: item.url.pathExtension))</td>
            <td class="name"><a href="\(href)">\(escape(name))</a><div class="meta">\(escape(size.string(fromByteCount: Int64(item.size)))) · \(escape(date.string(from: item.date)))</div></td>
            <td class="actions">\(install)<button onclick="act('share','\(js)')">\(escape(String(localized: "Save to iPhone…")))</button><button class="danger" onclick="act('delete','\(js)',this)">\(escape(String(localized: "Delete")))</button></td></tr>
            """
        }.joined(separator: "\n")
        let empty = "<p class=\"empty\">\(escape(String(localized: "Nothing here yet. Files you download and screenshots appear here.")))</p>"
        return """
        <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
        <title>\(escape(String(localized: "Files")))</title>
        <style>
        :root { color-scheme: dark; }
        body { margin: 0; padding: 28px 32px; background: #161618; color: #eee; font: 15px -apple-system, sans-serif; }
        h1 { font-size: 24px; margin: 0 0 4px; }
        .sub { color: #999; margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; }
        tr { border-top: 1px solid #2a2a2e; }
        td { padding: 10px 6px; vertical-align: middle; }
        .icon { font-size: 26px; width: 40px; text-align: center; }
        .name a { color: #8ab4ff; text-decoration: none; font-weight: 500; word-break: break-all; }
        .meta { color: #888; font-size: 12px; margin-top: 3px; }
        .actions { text-align: right; white-space: nowrap; }
        button { background: #2c2c30; color: #eee; border: 0; border-radius: 7px; padding: 7px 11px; margin-left: 6px;
                 font: inherit; font-size: 13px; }
        button:hover { background: #3a3a40; }
        .danger { color: #ff8a80; }
        .empty { color: #999; margin-top: 40px; text-align: center; }
        </style>
        <script>
        // Delete asks to be clicked twice, since a page cannot show a dialog on the desktop.
        function act(action, name, button) {
          if (action === 'delete' && button && !button.dataset.armed) {
            button.dataset.armed = '1';
            button.textContent = \(jsString(String(localized: "Click again to delete")));
            setTimeout(function () { delete button.dataset.armed; button.textContent = \(jsString(String(localized: "Delete"))); }, 3000);
            return;
          }
          window.webkit.messageHandlers.\(FilesBridge.messageName).postMessage({ action: action, name: name });
        }
        </script></head><body>
        <h1>\(escape(String(localized: "Files")))</h1>
        <div class="sub">\(escape(String(localized: "Downloads and screenshots. Click a file to open it.")))</div>
        \(items.isEmpty ? empty : "<table>\(rows)</table>")
        </body></html>
        """
    }

    private static func jsString(_ s: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: [s])) ?? Data("[\"\"]".utf8)
        let array = String(decoding: data, as: UTF8.self)
        return String(array.dropFirst().dropLast())
    }
}

/// Buttons on the Files page: share (save to Photos / Files / another app on the iPhone), delete, install an IPA.
/// Only the Files page itself may use it: any other page asking is ignored.
final class FilesBridge: NSObject, WKScriptMessageHandler {
    static let messageName = "ideskFiles"
    weak var window: DeskWindow?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let url = message.webView?.url, url.isFileURL, FileStore.isFilesPage(url),
              let body = message.body as? [String: String], let action = body["action"], let name = body["name"],
              !name.contains("/") else { return }
        let file = FileStore.downloads.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        let model = DesktopModel.shared
        switch action {
        case "share":
            model.shareOnPhone(file)
        case "delete":
            try? FileManager.default.removeItem(at: file)
            model.refreshFilesPages()
        case "install":
            model.showToast(String(localized: "Installing \(name)…"))
            GuestStore.shared.install(ipas: [file]) { results in
                model.showToast(GuestStore.summary(of: results))
            }
        default:
            break
        }
    }
}

/// Downloads from web pages go to Documents/Downloads.
final class Downloads: NSObject, WKDownloadDelegate {
    static let shared = Downloads()
    private var names: [ObjectIdentifier: String] = [:]

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String,
                  completionHandler: @escaping @MainActor (URL?) -> Void) {
        let url = FileStore.uniqueURL(in: FileStore.downloads, name: suggestedFilename)
        names[ObjectIdentifier(download)] = url.lastPathComponent
        DesktopModel.shared.showToast(String(localized: "Downloading \(url.lastPathComponent)…"))
        completionHandler(url)
    }

    func downloadDidFinish(_ download: WKDownload) {
        let name = names.removeValue(forKey: ObjectIdentifier(download)) ?? ""
        DesktopModel.shared.showToast(String(localized: "Downloaded \(name). Open it from Files."))
        DesktopModel.shared.refreshFilesPages()
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let name = names.removeValue(forKey: ObjectIdentifier(download)) ?? ""
        DesktopModel.shared.showToast(String(localized: "Could not download \(name)."))
    }
}
