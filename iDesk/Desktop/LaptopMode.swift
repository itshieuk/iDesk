import UIKit
import SwiftUI
import Combine

/// "Use a laptop as the display": the desktop runs on the iPhone (shown small, and touchable, like preview mode) and
/// RemoteDisplay sends it to a browser on the laptop, which also sends back its mouse and keyboard.
final class LaptopModeController: UIViewController {
    private let model = DesktopModel.shared
    private var desktopSize = RemoteDisplay.shared.desktopSize
    private var sizeWatch: AnyCancellable?
    private var viewerWatch: AnyCancellable?
    private lazy var host = UIHostingController(rootView: DesktopView(model: model))
    private lazy var header = UIHostingController(rootView: LaptopHeader { [weak self] in self?.stop() })
    private lazy var footer = UIHostingController(rootView: LaptopFooter())
    /// Landscape: the desktop fills the iPhone like a display; this small button leaves laptop mode.
    private let closeButton = UIButton(type: .system)
    /// Upright, under the small desktop: the iPhone is its trackpad too.
    private let trackpad = TrackpadView()
    /// The rounded, lit frame the small desktop sits in.
    private let card = UIView()
    /// Clips the phone preview to rounded corners without rounding `host.view` itself (which RemoteDisplay captures).
    private let desktopClip = UIView()

    /// Starts laptop mode on the iPhone (only without a real display: a cable or AirPlay is better).
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }
    override var prefersStatusBarHidden: Bool { isLandscape }
    override var prefersHomeIndicatorAutoHidden: Bool { isLandscape }
    private var isLandscape: Bool { view.bounds.width > view.bounds.height }

    static func present() {
        guard !ExternalDisplay.isConnected, var top = PhoneWindow.current?.rootViewController else { return }
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

        for hc in [header, footer] as [UIViewController] {
            addChild(hc)
            hc.view.backgroundColor = .clear
            view.addSubview(hc.view)
            hc.didMove(toParent: self)
        }
        card.backgroundColor = UIColor(white: 0.08, alpha: 1)
        card.layer.cornerRadius = 16
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor(white: 1, alpha: 0.12).cgColor
        card.layer.shadowColor = UIColor.systemBlue.cgColor
        card.layer.shadowOpacity = 0.25
        card.layer.shadowRadius = 24
        view.addSubview(card)

        desktopClip.backgroundColor = .black
        desktopClip.clipsToBounds = true
        desktopClip.layer.cornerCurve = .continuous
        view.addSubview(desktopClip)

        host.overrideUserInterfaceStyle = .dark
        addChild(host)
        host.view.layer.anchorPoint = .zero
        host.view.bounds = CGRect(origin: .zero, size: desktopSize)
        host.view.backgroundColor = .black
        host.view.layer.masksToBounds = true
        host.view.layer.cornerRadius = 0
        if #available(iOS 16.4, *) { host.safeAreaRegions = [] }
        desktopClip.addSubview(host.view)
        host.didMove(toParent: self)
        ExternalSceneDelegate.desktopView = host.view

        // Touching the small desktop works too.
        let shield = DesktopTouchShield(desktop: host.view)
        shield.tag = 7
        view.addSubview(shield)

        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold))
        config.baseBackgroundColor = UIColor(white: 0, alpha: 0.45)
        config.baseForegroundColor = UIColor(white: 1, alpha: 0.8)
        config.cornerStyle = .capsule
        closeButton.configuration = config
        closeButton.addAction(UIAction { [weak self] _ in self?.stop() }, for: .touchUpInside)
        view.addSubview(closeButton)
        trackpad.backgroundColor = UIColor(white: 0.12, alpha: 1)
        trackpad.layer.cornerRadius = 22
        trackpad.layer.cornerCurve = .continuous
        view.addSubview(trackpad)

        model.externalConnected()
        RemoteDisplay.shared.start()
        // The laptop's window has another shape: the desktop takes it (windows are fitted to the new size).
        sizeWatch = RemoteDisplay.shared.$desktopSize.dropFirst().removeDuplicates().sink { [weak self] _ in
            self?.view.setNeedsLayout()
        }
        viewerWatch = RemoteDisplay.shared.$viewers.removeDuplicates().sink { [weak self] _ in
            DispatchQueue.main.async { self?.view.setNeedsLayout() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let landscape = isLandscape
        // The desktop's shape: the laptop's window while a laptop shows it; otherwise, sideways, the iPhone's own
        // screen (it is the display then, edge to edge).
        var wanted = RemoteDisplay.shared.desktopSize
        let screen = view.bounds.inset(by: UIEdgeInsets(top: 0, left: view.safeAreaInsets.left, bottom: 0, right: view.safeAreaInsets.right))
        if landscape, RemoteDisplay.shared.viewers == 0, screen.height > 0 {
            let h: CGFloat = 720
            wanted = CGSize(width: (h * screen.width / screen.height / 2).rounded() * 2, height: h)
        }
        if wanted != desktopSize {
            desktopSize = wanted
            host.view.bounds = CGRect(origin: .zero, size: wanted)
            model.screenSize = wanted
        }
        header.view.isHidden = landscape
        footer.view.isHidden = landscape
        card.isHidden = landscape
        trackpad.isHidden = landscape
        closeButton.isHidden = !landscape
        let area: CGRect
        if landscape {
            // Sideways: the iPhone is the display, edge to edge (clear of the Dynamic Island).
            area = screen
            closeButton.frame = CGRect(x: view.safeAreaLayoutGuide.layoutFrame.maxX - 40, y: 14, width: 30, height: 30)
        } else {
            let safe = view.safeAreaLayoutGuide.layoutFrame
            let headerHeight: CGFloat = 140, footerHeight: CGFloat = 54
            header.view.frame = CGRect(x: safe.minX, y: safe.minY, width: safe.width, height: headerHeight)
            footer.view.frame = CGRect(x: safe.minX, y: safe.maxY - footerHeight, width: safe.width, height: footerHeight)
            area = CGRect(x: safe.minX + 14, y: safe.minY + headerHeight, width: safe.width - 28,
                          height: safe.height - headerHeight - footerHeight)
        }
        let s = min(area.width / desktopSize.width, area.height / desktopSize.height)
        let w = desktopSize.width * s, h = desktopSize.height * s
        // Upright: right under the address; sideways: in the middle of the screen.
        let frame = CGRect(x: area.midX - w / 2, y: landscape ? area.midY - h / 2 : area.minY + 6, width: w, height: h)
        desktopClip.frame = frame
        desktopClip.layer.cornerRadius = landscape ? 0 : 12
        host.view.bounds = CGRect(origin: .zero, size: desktopSize)
        host.view.transform = CGAffineTransform(scaleX: s, y: s)
        host.view.layer.position = .zero
        card.frame = frame.insetBy(dx: -1, dy: -1)
        view.viewWithTag(7)?.frame = frame
        if !landscape {
            let safe = view.safeAreaLayoutGuide.layoutFrame
            trackpad.frame = CGRect(x: safe.minX + 14, y: frame.maxY + 14, width: safe.width - 28,
                                    height: max(0, safe.maxY - 54 - frame.maxY - 14))
        }
        view.bringSubviewToFront(closeButton)
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }

    private func stop() {
        sizeWatch = nil
        viewerWatch = nil
        RemoteDisplay.shared.stop()
        if ExternalSceneDelegate.desktopView === host.view { ExternalSceneDelegate.desktopView = nil }
        // The phone's own desktop (PreviewController) stays alive underneath: hand the display role back to it.
        if let preview = PhoneWindow.current?.rootViewController as? PreviewController {
            model.externalConnected()
            preview.reclaimDesktopView()
        } else {
            model.externalDisconnected()
        }
        dismiss(animated: true)
    }
}

/// The top of the iPhone in laptop mode: title and Stop, the address to open on the laptop, and its state.
private struct LaptopHeader: View {
    @ObservedObject var remote = RemoteDisplay.shared
    let stop: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "laptopcomputer").font(.system(size: 17, weight: .semibold)).foregroundStyle(.tint)
                Text("Laptop as the display").font(.headline)
                Spacer()
                Button(action: stop) {
                    Text("Stop").font(.subheadline.weight(.semibold)).foregroundStyle(.red)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(Color.red.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
            if let failure = remote.failure {
                Text(verbatim: failure).font(.footnote).foregroundStyle(.orange)
            } else if let address = remote.address {
                Button {
                    UIPasteboard.general.string = address
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    HStack(spacing: 12) {
                        Circle().fill(remote.viewers > 0 ? Color.green : Color.orange).frame(width: 9, height: 9)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: address.replacingOccurrences(of: "http://", with: ""))
                                .font(.system(.title3, design: .monospaced).weight(.semibold))
                                .lineLimit(1).minimumScaleFactor(0.6)
                            Text(remote.viewers > 0 ? "Connected" : "Open it in the laptop's browser")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
            } else {
                Text("Join the same Wi-Fi as the laptop.").font(.footnote).foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
    }
}

private struct LaptopFooter: View {
    var body: some View {
        Label("Turn sideways to use the iPhone as the screen", systemImage: "rotate.right")
            .font(.footnote).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
