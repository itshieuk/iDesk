import UIKit

/// A transparent view over a desktop shown on the device's own screen (preview mode, laptop mode): touches stop here
/// and go through DesktopModel, as with an external display. Tap = click, drag = drag, hold = right click, two fingers
/// = scroll. (The desktop itself can't have interaction disabled: UIKit ignores actions in a guest app when any
/// superview has interaction disabled.)
final class DesktopTouchShield: UIView {
    /// The desktop's view: touches are placed in its coordinates.
    weak var desktop: UIView?
    private let model = DesktopModel.shared
    private var last: CGPoint = .zero

    init(desktop: UIView) {
        self.desktop = desktop
        super.init(frame: .zero)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned))
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
        let scroll = UIPanGestureRecognizer(target: self, action: #selector(scrolled))
        scroll.minimumNumberOfTouches = 2
        addGestureRecognizer(scroll)
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(held))
        hold.minimumPressDuration = 0.6
        pan.require(toFail: hold)
        addGestureRecognizer(hold)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func point(_ g: UIGestureRecognizer) -> CGPoint { g.location(in: desktop) }

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
            let t = g.translation(in: desktop)
            model.cursor.position = CGPoint(x: p.x - t.x, y: p.y - t.y)
            model.mouseDown()
            model.moveCursor(dx: t.x, dy: t.y)
        case .changed:
            model.moveCursor(dx: p.x - last.x, dy: p.y - last.y)
        default:
            model.mouseUp()
        }
        last = p
    }

    @objc private func scrolled(_ g: UIPanGestureRecognizer) {
        let p = point(g)
        if g.state == .began { model.cursor.position = p }
        else if g.state == .changed { model.scroll(dx: -(p.x - last.x), dy: -(p.y - last.y)) }
        last = p
    }
}
