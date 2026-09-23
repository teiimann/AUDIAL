import SwiftUI

/// Procedural playback ambience, not an FFT or measurement of Apple Music audio.
struct MotionHalo: View {
    var palette: DialPalette
    var playing: Bool
    var active: Bool
    var frozenTime: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playing || !active || reduceMotion || frozenTime != nil)) { timeline in
            let time = frozenTime ?? (playing && !reduceMotion ? timeline.date.timeIntervalSinceReferenceDate : 0)
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for i in 0..<80 {
                    let angle = Double(i) / 80 * .pi * 2 - .pi / 2
                    let wave = (sin(time * 2.6 + Double(i) * 0.37) + sin(time * 4.1 - Double(i) * 0.21) + 2) / 4
                    let envelope = pow((sin(time * 3.4) + 1) / 2, 6)
                    let length = playing && !reduceMotion ? 2 + wave * 7 + envelope * 4 : 2.0
                    let radius = 77.0
                    var bar = Path()
                    bar.move(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
                    bar.addLine(to: CGPoint(x: center.x + cos(angle) * (radius + length), y: center.y + sin(angle) * (radius + length)))
                    let color = i < 40 ? palette.primary : palette.secondary
                    context.stroke(bar, with: .color(color.opacity(playing ? 0.55 + wave * 0.4 : 0.3)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
                // Broken orbital highlights travel independently of the progress ring.
                for i in 0..<3 {
                    let start = time * (i == 1 ? -9 : 7) + Double(i) * 120
                    var orbit = Path()
                    orbit.addArc(center: center, radius: min(size.width, size.height) / 2 - 1, startAngle: .degrees(start), endAngle: .degrees(start + 28), clockwise: false)
                    context.stroke(orbit, with: .color((i == 1 ? palette.secondary : palette.primary).opacity(playing ? 0.55 : 0.18)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
