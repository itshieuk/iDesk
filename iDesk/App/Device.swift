import UIKit

/// iDesk runs on iPhone and iPad: the texts about the device itself name the one it runs on.
enum Device {
    static let isPad = UIDevice.current.userInterfaceIdiom == .pad

    /// "iPhone" becomes "iPad" on an iPad (the same word in every language iDesk speaks).
    static func words(_ s: String) -> String { isPad ? s.replacingOccurrences(of: "iPhone", with: "iPad") : s }

    /// The hardware model ("iPhone17,1") and iOS version, for reports.
    static var summary: String {
        var info = utsname(); uname(&info)
        let machine = withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        return "\(machine), iOS \(UIDevice.current.systemVersion)"
    }

    /// A new GitHub issue on iDesk's repository, filled in: the user only presses Submit. (iDesk can't file it by
    /// itself: that would need a GitHub token inside the app, which anyone could take.)
    static func newIssue(title: String, label: String, body: String) -> URL? {
        var c = URLComponents(string: "https://github.com/itshieuk/iDesk/issues/new")!
        c.queryItems = [URLQueryItem(name: "title", value: title), URLQueryItem(name: "labels", value: label),
                        URLQueryItem(name: "body", value: body)]
        return c.url
    }
}
