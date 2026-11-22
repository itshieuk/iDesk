import UIKit
import SwiftUI
import Combine

/// "Use a laptop as the display": the desktop runs on the iPhone (shown small, and touchable, like preview mode) and
/// RemoteDisplay sends it to a browser on the laptop, which also sends back its mouse and keyboard.
final class LaptopModeController: UIViewController {
    private let model = DesktopModel.shared
    private var desktopSize = RemoteDisplay.shared.desktopSize
    private var sizeWatch: AnyCancellable?
    private lazy var host = UIHostingController(rootView: DesktopView(model: model))
    private lazy var header = UIHostingController(rootView: LaptopHeader { [weak self] in self?.stop() })
    private var lastPan: CGPoint = .zero

    /// Starts laptop mode on the iPhone (only without a real display: a cable or AirPlay is better).
    static func present() {
        guard !DesktopModel.shared.isExternalConnected, var top = PhoneWindow.current?.rootViewController else { return }
        while let p = top.presentedViewController, !p.isBeingDismissed { top = p }
        let vc = LaptopModeController()
        vc.modalPresentationStyle = .fullScreen
        top.present(vc, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        overrideUserInterfaceStyle = .dark
        model.screenSize = desktopSize

        addChild(header)
        header.view.backgroundColor = .clear
        view.addSubview(header.view)
        header.didMove(toParent: self)

        host.overrideUserInterfaceStyle = .dark
        addChild(host)
        host.view.layer.anchorPoint = .zero
        host.view.bounds = CGRect(origin: .zero, size: desktopSize)
        host.view.backgroundColor = .black
        view.addSubview(host.view)
        host.didMove(toParent: self)
        ExternalSceneDelegate.desktopView = host.view

        // Touching the small desktop works too (see PreviewController): taps click, drags drag, hold = right click.
        let shield = UIView()
        shield.tag = 7
        view.addSubview(shield)
        shield.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned))
        pan.maximumNumberOfTouches = 1
        shield.addGestureRecognizer(pan)
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(held))
        hold.minimumPressDuration = 0.6
        pan.require(toFail: hold)
        shield.addGestureRecognizer(hold)

        model.externalConnected()
        RemoteDisplay.shared.start()
        // The laptop's window has another shape: the desktop takes it (windows are fitted to the new size).
        sizeWatch = RemoteDisplay.shared.$desktopSize.dropFirst().removeDuplicates().sink { [weak self] size in
            guard let self else { return }
            desktopSize = size
            host.view.bounds = CGRect(origin: .zero, size: size)
            model.screenSize = size
            view.setNeedsLayout()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaLayoutGuide.layoutFrame
        let headerHeight: CGFloat = min(330, safe.height * 0.45)
        header.view.frame = CGRect(x: safe.minX, y: safe.minY, width: safe.width, height: headerHeight)
        let area = CGRect(x: safe.minX + 8, y: safe.minY + headerHeight, width: safe.width - 16, height: safe.height - headerHeight - 8)
        let s = min(area.width / desktopSize.width, area.height / desktopSize.height)
        host.view.transform = CGAffineTransform(scaleX: s, y: s)
        let w = desktopSize.width * s, h = desktopSize.height * s
        host.view.layer.position = CGPoint(x: area.midX - w / 2, y: area.minY)
        view.viewWithTag(7)?.frame = CGRect(x: area.midX - w / 2, y: area.minY, width: w, height: h)
    }

    private func stop() {
        sizeWatch = nil
        RemoteDisplay.shared.stop()
        model.externalDisconnected()
        if ExternalSceneDelegate.desktopView === host.view { ExternalSceneDelegate.desktopView = nil }
        dismiss(animated: true)
    }

    private func point(_ g: UIGestureRecognizer) -> CGPoint { g.location(in: host.view) }

    @objc private func tapped(_ g: UITapGestureRecognizer) {
        model.cursor.position = point(g)
        model.click()
    }

    @objc private func held(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began else { return }
        model.cursor.position = point(g)
        model.rightClick()
    }

    @objc private func panned(_ g: UIPanGestureRecognizer) {
        let p = point(g)
        switch g.state {
        case .began:
            let t = g.translation(in: host.view)
            model.cursor.position = CGPoint(x: p.x - t.x, y: p.y - t.y)
            model.mouseDown()
            model.moveCursor(dx: t.x, dy: t.y)
        case .changed:
            model.moveCursor(dx: p.x - lastPan.x, dy: p.y - lastPan.y)
        default:
            model.mouseUp()
        }
        lastPan = p
    }
}

/// The top of the iPhone in laptop mode: the address to open on the laptop, how many are watching, Stop.
private struct LaptopHeader: View {
    @ObservedObject var remote = RemoteDisplay.shared
    let stop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Laptop as the display", systemImage: "laptopcomputer").font(.headline)
                Spacer()
                Button("Stop", role: .destructive, action: stop).buttonStyle(.bordered)
            }
            if let failure = remote.failure {
                Text(verbatim: failure).font(.callout).foregroundStyle(.orange)
            } else if let address = remote.address {
                Text("Open on the laptop:").font(.callout).foregroundStyle(.secondary)
                Text(verbatim: address).font(.system(size: 30, weight: .bold, design: .monospaced)).foregroundStyle(.tint)
                    .textSelection(.enabled).minimumScaleFactor(0.5).lineLimit(1)
                Label(remote.viewers > 0 ? "Connected" : "Waiting for the laptop…",
                      systemImage: remote.viewers > 0 ? "checkmark.circle.fill" : "hourglass")
                    .font(.callout).foregroundStyle(remote.viewers > 0 ? .green : .secondary)
            } else {
                Text("Join the same Wi-Fi as the laptop.").font(.callout).foregroundStyle(.orange)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
