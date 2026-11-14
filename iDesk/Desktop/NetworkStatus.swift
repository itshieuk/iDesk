import Foundation
import Network

/// How the iPhone is connected, for the network icon in the taskbar tray.
final class NetworkStatus: ObservableObject {
    enum Kind { case wifi, cellular, wired, other, offline }

    static let shared = NetworkStatus()
    @Published private(set) var kind: Kind = .other
    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let kind: Kind
            if path.status != .satisfied { kind = .offline }
            else if path.usesInterfaceType(.wifi) { kind = .wifi }
            else if path.usesInterfaceType(.wiredEthernet) { kind = .wired }
            else if path.usesInterfaceType(.cellular) { kind = .cellular }
            else { kind = .other }
            DispatchQueue.main.async { if self?.kind != kind { self?.kind = kind } }
        }
        monitor.start(queue: DispatchQueue(label: "iDesk.network"))
    }

    var symbol: String {
        switch kind {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .wired: return "cable.connector"
        case .other: return "network"
        case .offline: return "wifi.slash"
        }
    }
}
