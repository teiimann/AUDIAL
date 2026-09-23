import SwiftUI

enum HUDLayout {
    static let width: CGFloat = 391
    static let height: CGFloat = 820
    static let dialRadius: CGFloat = 120.75
}

struct ArcSegment: Shape {
    var start: Double, end: Double, inner: CGFloat
    var expansion: CGFloat = 0
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(inner, expansion) }
        set { inner = newValue.first; expansion = newValue.second }
    }
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY), r = min(rect.width, rect.height) / 2 + expansion
        var p = Path()
        p.addArc(center: c, radius: r, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        p.addArc(center: c, radius: inner, startAngle: .degrees(end), endAngle: .degrees(start), clockwise: true)
        p.closeSubpath(); return p
    }
}

struct DialView: View {
    @ObservedObject var music: MusicController
    var previewTime: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered: Int?
    @State private var pressed: Int?
    @State private var queueToolHover: Int?
    @State private var progressHover = false
    @State private var ripple = false
    @State private var appeared = false
    private var expanded: Bool { music.mode == .actions }
    private var reveal: Bool { music.metadata || music.hovering || music.message != nil || music.seeking || expanded }
    var body: some View {
        ZStack {
            if music.mode == .queue { queue.transition(.asymmetric(insertion: .offset(y: 45).combined(with: .opacity), removal: .opacity)) }
            ZStack {
                Circle().fill(Color(white: 0.075))
                Circle().strokeBorder(Color(white: 0.025), lineWidth: 3)
                Circle().stroke(music.accent.opacity(ripple ? 0 : 0.6), lineWidth: 1)
                    .scaleEffect(ripple && !reduceMotion ? 1.17 : 0.98)
                    .allowsHitTesting(false)
                MotionHalo(palette: music.palette, playing: music.track.playing, active: music.visible, frozenTime: previewTime)
                ForEach([1, 2, 3], id: \.self) { index in
                    if index != 2 || music.mode != .queue { control(index) }
                }
                Circle().fill(.black.opacity(0.75)).frame(width: 150, height: 150).allowsHitTesting(false)
                progress
                album
            }
            .frame(width: HUDLayout.dialRadius * 2, height: HUDLayout.dialRadius * 2)
            .compositingGroup()
            .shadow(color: music.accent.opacity(music.track.playing ? 0.25 : 0.08), radius: 18, x: -7, y: -4)
            .shadow(color: music.palette.secondary.opacity(music.track.playing ? 0.22 : 0.06), radius: 20, x: 8, y: 8)
            .shadow(color: .black.opacity(0.65), radius: 14, y: 12)
            .scaleEffect(appeared || previewTime != nil ? 1 : 0.86)
            topMorph
            if music.mode == .queue { queueTools }
            if previewTime == nil { pointerSurface }
        }
        .frame(width: HUDLayout.width, height: HUDLayout.height)
        .foregroundStyle(.white).preferredColorScheme(.dark)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7), value: music.mode)
        .onChange(of: music.feedback) { _ in
            var reset = Transaction(); reset.disablesAnimations = true
            withTransaction(reset) { ripple = false }
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: reduceMotion ? 0 : 0.65)) { ripple = true }
            }
        }
        .onChange(of: music.visible) { visible in
            if !visible { appeared = false; pressed = nil }
            else { withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.68)) { appeared = true } }
        }
        .onAppear { withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.68)) { appeared = true } }
    }
    private var progress: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.1), lineWidth: 1)
            Circle().trim(from: 0, to: music.progress)
                .stroke(AngularGradient(colors: [music.palette.secondary, music.accent], center: .center, startAngle: .degrees(0), endAngle: .degrees(360)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle().fill(.white).frame(width: progressHover || music.seeking ? 8 : 4, height: progressHover || music.seeking ? 8 : 4)
                .shadow(color: music.accent, radius: 4)
                .offset(y: -73).rotationEffect(.degrees(music.progress * 360))
                .opacity(music.track.duration > 0 ? 1 : 0)
        }.frame(width: 146, height: 146)
            .animation(music.seeking ? nil : .linear(duration: 0.85), value: music.progress)
            .allowsHitTesting(false)
    }
    private func control(_ index: Int) -> some View {
        let symbols = [music.track.favorite ? "heart.fill" : "heart", "forward.end.fill", "music.note.list", "backward.end.fill"]
        let labels = ["Song actions", "Next song. Hold to seek", "Up Next", "Previous song. Hold to seek"]
        let angle = Double(index) * 90 - 90
        let isPressed = pressed == index || music.controlPressed == index
        let selected = hovered == index || isPressed || music.controlFlash == index
        return ZStack {
            ArcSegment(start: angle - 45, end: angle + 45, inner: 90, expansion: selected ? (isPressed ? 3 : 15) : 0)
                .fill(selected ? music.accent : Color(white: 0.16))
                .overlay(ArcSegment(start: angle - 45, end: angle + 45, inner: 90, expansion: selected ? (isPressed ? 3 : 15) : 0).stroke(Color(white: 0.025), style: StrokeStyle(lineWidth: 3, lineJoin: .round)))
            Image(systemName: symbols[index])
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(selected ? Color.black.opacity(0.85) : .white.opacity(0.82))
                .scaleEffect(isPressed ? 0.78 : selected ? 1.16 : 1)
                .rotationEffect(.degrees(reduceMotion ? 0 : selected ? (index == 3 ? -10 : 10) : 0))
                .offset(x: cos(angle * .pi / 180) * (selected ? 113 : 105.5), y: sin(angle * .pi / 180) * (selected ? 113 : 105.5))
        }
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.43), value: selected)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.5), value: isPressed)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore).accessibilityLabel(labels[index]).accessibilityAddTraits(.isButton)
        .accessibilityAction { if index == 1 || index == 3 { music.command(index == 1 ? "next track" : "previous track") } else { music.openMode(index == 0 ? .actions : .queue) } }
        .help(labels[index])
    }
    private var album: some View {
        Button(action: music.toggle) {
            ZStack {
                if let image = music.artwork {
                    SpinningArtwork(image: image, spinning: music.track.playing && music.visible && !reduceMotion && previewTime == nil)
                        .id(music.track.id).transition(.opacity)
                } else {
                    ZStack {
                        AngularGradient(colors: [music.palette.surface, music.accent.opacity(0.55), music.palette.surface, music.palette.secondary.opacity(0.6), music.palette.surface], center: .center)
                        ForEach(0..<12) { i in Circle().stroke(.white.opacity(i % 3 == 0 ? 0.09 : 0.035), lineWidth: 0.5).padding(CGFloat(i * 4 + 5)) }
                        Circle().fill(.black.opacity(0.55)).frame(width: 39, height: 39)
                        Image(systemName: "waveform").font(.system(size: 16, weight: .light)).foregroundStyle(music.accent)
                    }
                }
                if reveal {
                    LinearGradient(colors: [.clear, .black.opacity(0.22), .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                    VStack(spacing: 3) {
                        Spacer()
                        if music.seeking {
                            Text(timestamp(music.track.position)).font(.system(size: 20, weight: .light, design: .monospaced))
                        } else if let message = music.message {
                            Text(message).font(.system(size: 10, weight: .medium)).multilineTextAlignment(.center).lineLimit(3)
                        } else if expanded {
                            Text(music.actionLabel).font(.system(size: 10, weight: .medium)).lineLimit(2).multilineTextAlignment(.center)
                        } else {
                            Text(music.track.title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                            Text(music.track.artist).font(.system(size: 9)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                        }

                    }.padding(.horizontal, 15).padding(.bottom, 18)
                    .transition(.opacity.combined(with: .offset(y: 8)))
                } else if !music.track.playing {
                    Image(systemName: "play.fill").font(.system(size: 19)).shadow(radius: 10)
                }
            }.frame(width: 136, height: 136).clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8), value: reveal)
        }.buttonStyle(.plain)
        .onHover { value in withAnimation(.easeInOut(duration: 0.25)) { music.hovering = value } }
        .accessibilityLabel("\(music.track.title), \(music.track.artist). \(music.track.playing ? "Pause" : "Play")")
    }
    private var topMorph: some View {
        let diameter: CGFloat = expanded ? 316 : HUDLayout.dialRadius * 2
        return ZStack {
            ArcSegment(start: -135, end: -45, inner: 90)
                .fill(Color(white: 0.16))
            ArcSegment(start: -135, end: -45, inner: 90)
                .fill(expanded ? Color(white: 0.16) : hovered == 0 ? music.accent : Color(white: 0.16))
            ArcSegment(start: -135, end: -45, inner: 90)
                .stroke(Color(white: 0.025), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
            if expanded {
                ForEach(0..<3) { i in
                    let angle = Double(-120 + i * 30)
                    let selected = music.actionIndex == i
                    ZStack {
                        ArcSegment(start: angle - 15, end: angle + 15, inner: 90)
                            .fill(selected ? music.accent : Color(white: 0.16))
                            .overlay(ArcSegment(start: angle - 15, end: angle + 15, inner: 90).stroke(Color(white: 0.025), lineWidth: 2))
                        Image(systemName: [music.track.favorite ? "heart.fill" : "heart", "plus", "arrow.up.right"][i])
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(selected ? Color.black.opacity(0.85) : .white)
                            .offset(x: cos(angle * .pi / 180) * 127, y: sin(angle * .pi / 180) * 127)
                    }.scaleEffect(reduceMotion ? 1 : selected ? 1.025 : 1)
                        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.44), value: selected)
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .bottom)))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(["Favorite", "Add in Music", "Show in Music"][i])
                        .accessibilityAddTraits(.isButton).accessibilityAction { music.action(i) }
                }
            } else {
                Image(systemName: music.track.favorite ? "heart.fill" : "heart")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(hovered == 0 ? Color.black.opacity(0.85) : .white.opacity(0.82))
                    .offset(y: -105.5)
                    .transition(.opacity)
                    .accessibilityLabel("Song actions").accessibilityAddTraits(.isButton)
                    .accessibilityAction { music.openMode(.actions) }
            }
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(!expanded && !reduceMotion ? (pressed == 0 ? 0.97 : hovered == 0 ? 1.055 : 1) : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.52), value: expanded)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.43), value: hovered)
        .allowsHitTesting(false)
    }
    private var queueTools: some View {
        ZStack {
            ForEach(0..<2) { index in
                let angle = Double(112.5 - Double(index) * 45)
                let active = index == 0 && music.shuffleEnabled
                ZStack {
                    ArcSegment(start: angle - 22.5, end: angle + 22.5, inner: 90)
                        .fill(active ? music.accent : Color(white: queueToolHover == index ? 0.24 : 0.16))
                        .overlay(ArcSegment(start: angle - 22.5, end: angle + 22.5, inner: 90).stroke(Color(white: 0.025), lineWidth: 2))
                    VStack(spacing: 3) {
                        Image(systemName: index == 0 ? (music.shuffleEnabled ? "shuffle" : "arrow.down") : "quote.bubble")
                            .font(.system(size: 16, weight: .bold))
                        if index == 0 {
                            Text(music.shuffleChanging ? "…" : music.shuffleEnabled ? "Перемешано" : "По порядку")
                                .font(.system(size: 7, weight: .semibold, design: .rounded))
                        }
                    }.foregroundStyle(active ? Color.black : Color.white)
                        .offset(x: cos(angle * .pi / 180) * 115, y: sin(angle * .pi / 180) * 115)

                }.scaleEffect(reduceMotion ? 1 : queueToolHover == index ? 1.025 : 1)
                    .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.5), value: queueToolHover)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(index == 0 ? "Shuffle: \(music.shuffleEnabled ? "on" : "off")" : "Lyrics in Music")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { index == 0 ? music.toggleShuffle() : music.showLyrics() }
            }
        }.frame(width: 280, height: 280).allowsHitTesting(false)
    }
    private var pointerSurface: some View {
        DialPointerSurface(expanded: expanded, queueExpanded: music.mode == .queue, enabled: music.visible,
            hover: { target in
                withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.43)) {
                    if case .direction(let index) = target { hovered = index } else { hovered = nil }
                    if case .action(let index) = target { music.actionIndex = index }
                    if case .queueTool(let index) = target { queueToolHover = index } else { queueToolHover = nil }
                    progressHover = target == .progress
                }
                music.cancelHoverMode()
            }, press: { target in
                withAnimation(.spring(response: 0.23, dampingFraction: 0.6)) {
                    if case .direction(let index) = target { pressed = index } else { pressed = nil }
                }
            }, down: { target in
                if case .direction(let index) = target, index == 1 || index == 3 { music.beginHold(index == 1 ? 1 : -1) }
            }, release: { target, inside in
                switch target {
                case .direction(let index):
                    if index == 1 || index == 3 { music.endHold(cancel: !inside) }
                    else if inside { music.openMode(index == 0 ? .actions : .queue) }
                case .action(let index): if inside { music.action(index) }
                case .queueTool(let index): if inside { index == 0 ? music.toggleShuffle() : music.showLyrics() }
                case .progress: break
                }
            }, seek: { fraction, commit in music.seek(to: fraction, commit: commit) })
            .frame(width: 340, height: 340)
            .accessibilityHidden(true)
    }
    private var queue: some View {
        VinylDrawer(music: music)
    }
    private func timestamp(_ seconds: Double) -> String { let s = Int(max(0, seconds)); return String(format: "%d:%02d", s / 60, s % 60) }
}

private struct TactileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.91 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

private struct SpinningArtwork: View {
    let image: NSImage
    let spinning: Bool
    @State private var phase: Double = 0
    @State private var epoch = Date()
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !spinning)) { timeline in
            let angle = phase + (spinning ? timeline.date.timeIntervalSince(epoch) * 22.5 : 0)
            Image(nsImage: image).resizable().scaledToFill().frame(width: 136, height: 136)
                .clipShape(Circle()).rotationEffect(.degrees(angle))
        }
        .onChange(of: spinning) { value in
            if !value { phase = (phase + Date().timeIntervalSince(epoch) * 22.5).truncatingRemainder(dividingBy: 360) }
            epoch = Date()
        }
        .onAppear { epoch = Date() }
    }
}
