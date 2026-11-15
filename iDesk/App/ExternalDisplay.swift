import UIKit

/// Resolution and overscan of the external display.
///
/// A 4K monitor runs at its full resolution by default, which makes everything on the desktop tiny; picking a lower
/// mode (1920×1080…) makes the monitor scale the picture up, so the desktop looks bigger and stays sharp. Some TVs
/// crop the edges of the picture (overscan): iOS can shrink the picture to fit inside them.
enum ExternalDisplay {
    private static weak var screen: UIScreen?
    private static let modeKey = "iDesk.displayMode"        // "1920x1080", or absent for the display's own choice
    private static let overscanKey = "iDesk.overscan"       // true: shrink the picture to fit a TV's visible area

    static func connected(_ screen: UIScreen) {
        self.screen = screen
        apply()
    }

    static func disconnected() { screen = nil }

    /// The resolutions the display offers, largest first (each size once).
    static var resolutions: [CGSize] {
        guard let screen else { return [] }
        var seen = Set<String>()
        return screen.availableModes.map(\.size)
            .filter { seen.insert(name(of: $0)).inserted }
            .sorted { $0.width * $0.height > $1.width * $1.height }
    }

    static var resolution: CGSize? {
        get {
            guard let s = UserDefaults.standard.string(forKey: modeKey) else { return nil }
            let parts = s.split(separator: "x").compactMap { Double($0) }
            return parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : nil
        }
        set {
            if let newValue { UserDefaults.standard.set(name(of: newValue), forKey: modeKey) }
            else { UserDefaults.standard.removeObject(forKey: modeKey) }
            apply()
        }
    }

    static var fitsOverscan: Bool {
        get { UserDefaults.standard.object(forKey: overscanKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: overscanKey); apply() }
    }

    static var currentResolution: CGSize? { screen?.currentMode?.size }

    static func name(of size: CGSize) -> String { "\(Int(size.width))x\(Int(size.height))" }

    private static func apply() {
        guard let screen else { return }
        let wanted = resolution.flatMap { size in screen.availableModes.first { $0.size == size } } ?? screen.preferredMode
        if let wanted, screen.currentMode != wanted { screen.currentMode = wanted }
        screen.overscanCompensation = fitsOverscan ? .scale : .none
    }
}
