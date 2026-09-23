import AppKit
import SwiftUI

/// A single polar hit map avoids four overlapping SwiftUI gesture rectangles.
struct DialPointerSurface: NSViewRepresentable {
    var expanded: Bool
    var queueExpanded: Bool
    var enabled: Bool
    var hover: (DialTarget?) -> Void
    var press: (DialTarget?) -> Void
    var down: (DialTarget) -> Void
    var release: (DialTarget, Bool) -> Void
    var seek: (Double, Bool) -> Void
    func makeNSView(context: Context) -> PointerView { PointerView() }
    func updateNSView(_ view: PointerView, context: Context) {
        view.configuration = self
        if !enabled { view.cancel() }
    }
    final class PointerView: NSView {
        var configuration: DialPointerSurface?
        private var tracking: NSTrackingArea?
        private var held: DialTarget?
        private var lastFraction = 0.0
        override var isFlipped: Bool { true }
        override var acceptsFirstResponder: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let tracking { removeTrackingArea(tracking) }
            let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
            addTrackingArea(area); tracking = area
        }
        private func target(_ point: NSPoint) -> DialTarget? {
            guard configuration?.enabled == true else { return nil }
            return DialGeometry.target(x: point.x - bounds.midX, y: point.y - bounds.midY, expanded: configuration?.expanded == true, queueExpanded: configuration?.queueExpanded == true)
        }
        override func hitTest(_ point: NSPoint) -> NSView? {
            let local = convert(point, from: superview)
            return target(local) == nil ? nil : self
        }
        override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }
        override func mouseMoved(with event: NSEvent) { configuration?.hover(target(convert(event.locationInWindow, from: nil))) }
        override func mouseExited(with event: NSEvent) { configuration?.hover(nil) }
        override func mouseDown(with event: NSEvent) {
            let p = convert(event.locationInWindow, from: nil)
            guard let hit = target(p) else { return }
            held = hit; configuration?.press(hit)
            if hit == .progress {
                lastFraction = DialGeometry.fraction(x: p.x - bounds.midX, y: p.y - bounds.midY)
                configuration?.seek(lastFraction, false)
            } else { configuration?.down(hit) }
        }
        override func mouseDragged(with event: NSEvent) {
            guard held == .progress else { return }
            let p = convert(event.locationInWindow, from: nil)
            lastFraction = DialGeometry.dragFraction(DialGeometry.fraction(x: p.x - bounds.midX, y: p.y - bounds.midY), previous: lastFraction)
            configuration?.seek(lastFraction, false)
        }
        override func mouseUp(with event: NSEvent) {
            guard let held else { return }
            self.held = nil; configuration?.press(nil)
            if held == .progress { configuration?.seek(lastFraction, true) }
            else { configuration?.release(held, held == target(convert(event.locationInWindow, from: nil))) }
        }
        func cancel() { held = nil }
    }
}
