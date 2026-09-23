import SwiftUI

/// The fixed hit strips follow the same top-to-bottom order as the arrow keys.
/// Animated records never move their own hover targets.
struct VinylDrawer: View {
    @ObservedObject var music: MusicController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var selected: Int { music.queueRecords.indices.contains(music.queueIndex) ? music.queueIndex : -1 }
    private func centerY(_ index: Int) -> CGFloat { 71 + CGFloat(index) * 23 + (selected >= 0 && index >= selected ? 90 : 0) }
    var body: some View {
        ZStack {
            if music.queueRecords.isEmpty { emptyState }
            else {
                ForEach(Array(music.queueRecords.enumerated()), id: \.element.id) { index, record in
                    vinyl(record, index: index)
                        .frame(width: 204, height: 204)
                        .offset(y: centerY(index))
                        .shadow(color: .black.opacity(0.6), radius: selected == index ? 7 : 3, y: 5)
                        .zIndex(Double(5 - index))
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                // Only invisible, stationary hit strips; the lettering belongs to each disc.
                ForEach(Array(music.queueRecords.enumerated()), id: \.element.id) { index, record in
                    Button { music.selectQueue(index); music.activateQueueSelection() } label: {
                        Color.clear.frame(width: 174, height: 23).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .offset(y: centerY(index) + 87).zIndex(20)
                        .transaction { $0.animation = nil }
                        .onHover { if $0 { music.hoverQueue(index) } }
                        .accessibilityLabel(record.title ?? record.label)
                }
                if selected >= 0 {
                Button { music.activateQueueSelection() } label: {
                    Color.clear.frame(width: 104, height: 70).contentShape(Rectangle())
                }.buttonStyle(.plain).offset(y: centerY(selected) + 20).zIndex(20)
                    .accessibilityLabel("Воспроизвести \(music.queueRecords[selected].title ?? music.queueRecords[selected].label)")
                }
                Button { music.openFullQueue() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "music.note.list")
                        Text("APPLE MUSIC").tracking(2)
                        Image(systemName: "arrow.up.right").font(.system(size: 7, weight: .bold))
                    }.font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(selected < 0 ? Color.black : .white.opacity(0.8))
                        .padding(.horizontal, 13).padding(.vertical, 5)
                        .background(Capsule().fill(selected < 0 ? music.accent : Color(white: 0.08)))
                        .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 0.7))
                }.buttonStyle(.plain)
                    .scaleEffect(reduceMotion ? 1 : selected < 0 ? 1.12 : 1)
                    .rotationEffect(.degrees(reduceMotion ? 0 : selected < 0 ? -3 : 0))
                    .shadow(color: selected < 0 ? music.accent.opacity(0.4) : .clear, radius: 10)
                    .offset(y: selected < 0 ? 300 : 382).zIndex(22)
                    .help("Вся очередь в Music").accessibilityLabel("Вся очередь")
                    .onHover { if $0 { music.hoverQueue(music.queueRecords.count) } }
            }
        }
        .scaleEffect(0.84).offset(y: 22)
        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.8), value: music.queueIndex)
        .simultaneousGesture(DragGesture(minimumDistance: 18).onEnded { value in
            if abs(value.translation.height) > 18 { music.browseQueue(value.translation.height > 0 ? 1 : -1) }
        })
    }
    private func vinyl(_ record: QueueRecord, index: Int) -> some View {
        ZStack {
            Circle().fill(Color(white: 0.045))
            if let image = record.artwork {
                Image(nsImage: image).resizable().scaledToFill().frame(width: 198, height: 198)
                    .clipShape(Circle()).opacity(selected == index ? 0.65 : 0.32)
            }
            Circle().stroke(selected == index ? music.accent.opacity(0.75) : Color(white: 0.29), lineWidth: 1.2)
            ForEach(0..<17) { groove in
                Circle().stroke(Color(white: groove % 4 == 0 ? 0.21 : 0.13), lineWidth: 0.65)
                    .padding(CGFloat(6 + groove * 2))
            }
            // Two quiet reflections on the grooves, not a gradient-filled control.
            Circle().trim(from: 0.57, to: 0.69).stroke(.white.opacity(0.12), lineWidth: 25).padding(21)
            Circle().trim(from: 0.07, to: 0.17).stroke(.white.opacity(0.07), lineWidth: 25).padding(21)
            Circle().fill(index % 2 == 0 ? music.accent : music.palette.secondary).frame(width: 90, height: 90)
            if let image = record.artwork {
                Image(nsImage: image).resizable().scaledToFill().frame(width: 86, height: 86).clipShape(Circle())
            } else {
                Text("SIDE A").font(.system(size: 10, weight: .black, design: .rounded)).tracking(2)
                    .foregroundStyle(.black.opacity(0.8)).offset(y: -18)
                Text("AUDIAL").font(.system(size: 6, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.7)).offset(y: 21)
            }
            if selected == index, let artist = record.artist {
                VStack(spacing: 2) {
                    Text(artist).font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1).foregroundStyle(.white)
                }.frame(width: 130).padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.8))).offset(y: 62)
            }
            RecordInscription(title: (record.title ?? record.label.components(separatedBy: " — ").first ?? record.label),
                              color: selected == index ? music.accent : .white.opacity(0.88))
            Circle().stroke(.black.opacity(0.4), lineWidth: 1).frame(width: 87, height: 87)
            Circle().fill(Color(white: 0.045)).frame(width: 10, height: 10)
                .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
        }.compositingGroup()
    }
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "opticaldisc").font(.system(size: 26, weight: .medium)).foregroundStyle(music.accent)
            Text(music.queueLoading ? "Читаю очередь…" : music.queueMessage ?? "Очередь Music")
                .font(.system(size: 10, weight: .medium, design: .rounded)).multilineTextAlignment(.center).lineLimit(4)
            if !music.queueLoading {
                Button(music.queueNeedsPermission ? "Открыть настройки" : "Обновить") {
                    music.queueNeedsPermission ? music.connectQueue() : music.loadQueue()
                }.buttonStyle(.plain).font(.system(size: 10, weight: .bold)).foregroundStyle(music.accent)
            }
        }.padding(16).frame(width: 205)
            .background(RoundedRectangle(cornerRadius: 24).fill(Color(white: 0.1)))
            .offset(y: 212)
    }
}

/// Typeset on the outer groove, following the circular face rather than a list row.
private struct RecordInscription: View {
    let title: String
    let color: Color
    var body: some View {
        Canvas { context, size in
            let font = NSFont.systemFont(ofSize: 10, weight: .semibold)
            func width(_ s: String) -> CGFloat { (s as NSString).size(withAttributes: [.font: font]).width }
            var caption = title
            if width(caption) > 137 {
                while !caption.isEmpty && width(caption + "…") > 137 { caption.removeLast() }
                caption += "…"
            }
            let radius: CGFloat = 91
            var advance = -width(caption) / 2
            for character in caption {
                let glyph = String(character), w = width(glyph)
                let angle = (advance + w / 2) / radius
                var glyphContext = context
                glyphContext.translateBy(x: size.width / 2 + sin(angle) * radius,
                                         y: size.height / 2 + cos(angle) * radius)
                glyphContext.rotate(by: .radians(Double(-angle)))
                glyphContext.addFilter(.shadow(color: .black, radius: 2))
                glyphContext.draw(Text(glyph).font(.system(size: 10, weight: .semibold)).foregroundColor(color), at: .zero)
                advance += w
            }
        }.allowsHitTesting(false)
    }
}
