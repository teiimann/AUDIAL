import SwiftUI
import AppKit

enum DialMode { case main, queue, actions }
final class MusicController: ObservableObject {
    @Published var track = MusicSnapshot()
    @Published var artwork: NSImage?
    @Published var palette = DialPalette.idle
    @Published var visible = false
    @Published var feedback = 0
    @Published var controlPressed: Int?
    @Published var controlFlash: Int?
    private var controlFlashWork: DispatchWorkItem?
    var accent: Color { palette.primary }
    @Published var mode = DialMode.main
    @Published var metadata = true
    @Published var hovering = false
    @Published var actionIndex = 0
    @Published var message: String?
    @Published var seeking = false
    @Published var queueRecords: [QueueRecord] = []
    @Published var queueIndex = 0
    @Published var queueLoading = false
    @Published var queueNeedsPermission = false
    @Published var queueMessage: String?
    @Published var queueActivating = false
    @Published var shuffleChanging = false
    @Published var shuffleEnabled = false
    private var shuffleRevision = 0
    private var lastShuffleTap = Date.distantPast
    private let artworkResolver = QueueArtworkResolver()
    private var resolvingArtwork = false
    private var artworkReadAt = Date.distantPast
    private var hoverWork: DispatchWorkItem?
    private var pendingHoverMode: DialMode?
    private let queueReader = MusicQueueReader()
    private var queueRequest = UUID()
    private var lastQueueHoverPoint: NSPoint?
    private var queueReadAt = Date.distantPast
    private var seekRevision = 0
    private var seekPending = false
    private let adapter = AppleMusicAdapter()
    private var polling: Timer?, holdTimer: Timer?, revealWork: DispatchWorkItem?, messageWork: DispatchWorkItem?
    private var busy = false, heldAt = Date(), direction = 0, held = false
    var dismiss: (() -> Void)?
    var progress: Double { track.duration > 0 ? min(1, max(0, track.position / track.duration)) : 0 }
    var actionLabel: String { [track.favorite ? "Remove favorite" : "Favorite song", "Add in Apple Music", "Show in Apple Music"][actionIndex] }
    func start() {
        refresh()
        polling = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func refresh() {
        guard !busy, !seeking, !seekPending else { return }; busy = true
        let revision = seekRevision
        let shuffleVersion = shuffleRevision
        adapter.read { [weak self] result in
            guard let self else { return }; self.busy = false
            guard !self.seeking, revision == self.seekRevision else { return }
            switch result {
            case .success(let next):
                let changed = next.id != self.track.id
                self.track = next
                if !self.shuffleChanging && shuffleVersion == self.shuffleRevision { self.shuffleEnabled = next.shuffled }
                if self.mode == .queue && !self.queueLoading && (changed || Date().timeIntervalSince(self.queueReadAt) > 4) { self.loadQueue() }
                if changed {
                    withAnimation(.easeInOut(duration: 0.7)) { self.artwork = nil; self.palette = .idle }
                    self.reveal()
                }
                if let data = next.artwork, let image = NSImage(data: data) {
                    withAnimation(.easeInOut(duration: 0.9)) {
                        self.artwork = image
                        self.palette = ArtworkPalette.extract(from: image)
                    }
                }
            case .failure(let error): self.notify((error as NSError).code == -1743 ? "Allow Music in Privacy → Automation" : "Music unavailable. Try again.")
            }
        }
    }
    func command(_ text: String) {
        adapter.command(text) { [weak self] error in
            if let error { self?.notify(error.localizedDescription) } else { self?.refresh() }
        }
    }
    func pulse() { feedback += 1; NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
    func toggle() { pulse(); command("playpause") }
    func openMode(_ value: DialMode) { endHold(cancel: true); pulse(); withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { mode = mode == value ? .main : value }; if mode == .queue { queueIndex = 0; loadQueue() }; reveal() }
    func expandMode(_ value: DialMode) {
        guard mode != value else { return }
        openMode(value)
    }
    func hoverMode(_ value: DialMode) {
        guard mode != value, pendingHoverMode != value else { return }
        cancelHoverMode(); pendingHoverMode = value
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.visible else { return }
            self.pendingHoverMode = nil; self.expandMode(value)
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14, execute: work)
    }
    func cancelHoverMode() { hoverWork?.cancel(); hoverWork = nil; pendingHoverMode = nil }
    func reveal() {
        revealWork?.cancel(); withAnimation(.easeOut(duration: 0.25)) { metadata = true }
        let work = DispatchWorkItem { [weak self] in withAnimation(.easeInOut(duration: 0.4)) { self?.metadata = false } }
        revealWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }
    func notify(_ text: String) {
        messageWork?.cancel(); message = text
        let work = DispatchWorkItem { [weak self] in self?.message = nil }
        messageWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }
    func beginHold(_ value: Int) {
        guard direction == 0 else { return }
        seekRevision += 1; seekPending = false
        controlPressed = value > 0 ? 1 : 3
        direction = value; heldAt = Date(); held = false
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self, Date().timeIntervalSince(self.heldAt) > 0.4, self.track.duration > 0 else { return }
            if !self.held { self.pulse() }; self.held = true; self.seeking = true
            let speed = min(18, 3 + Date().timeIntervalSince(self.heldAt) * 2)
            self.track.position = min(self.track.duration, max(0, self.track.position + Double(self.direction) * speed * 0.15))
        }
    }
    func endHold(cancel: Bool = false) {
        guard direction != 0 else { return }
        holdTimer?.invalidate(); holdTimer = nil
        let previous = direction; direction = 0; seeking = false
        controlPressed = nil
        controlFlashWork?.cancel()
        if cancel { controlFlash = nil }
        else {
            controlFlash = previous > 0 ? 1 : 3
            let work = DispatchWorkItem { [weak self] in self?.controlFlash = nil }
            controlFlashWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: work)
        }
        guard !cancel else { return }
        pulse()
        if held { commitSeek() }
        else { command(previous < 0 ? "previous track" : "next track") }
    }
    func seek(to fraction: Double, commit: Bool) {
        guard track.duration > 0, fraction.isFinite else { return }
        if !seeking { seekRevision += 1; seekPending = false; pulse() }
        seeking = true
        track.position = max(0, min(1, fraction)) * track.duration
        if commit { seeking = false; commitSeek(); pulse() }
    }
    private func commitSeek() {
        seekPending = true
        let revision = seekRevision
        let escapedID = track.id.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = "if persistent ID of current track is \"\(escapedID)\" then\nset player position to \(track.position)\nend if"
        adapter.command(script) { [weak self] error in
            guard let self, self.seekRevision == revision else { return }
            self.seekPending = false
            if let error { self.notify(error.localizedDescription) }
            self.refresh()
        }
    }
    func cancelPointerSeek() {
        if seeking { seeking = false; seekRevision += 1; seekPending = false; refresh() }
    }
    func loadQueue() {
        let request = UUID(); queueRequest = request
        queueLoading = true; queueMessage = nil; queueReadAt = Date()
        let trackID = track.id
        queueReader.read { [weak self] result in
            guard let self, self.queueRequest == request else { return }
            self.queueLoading = false
            guard self.track.id == trackID else { self.queueRecords = []; return }
            self.queueNeedsPermission = false
            switch result {
            case .records(let records):
                let changed = self.queueRecords.map(\.label) != records.map(\.label)
                let cached = Dictionary(self.queueRecords.map { ($0.label, $0) }, uniquingKeysWith: { first, _ in first })
                self.queueRecords = records.map { record in
                    var enriched = record
                    if let old = cached[record.label] {
                        enriched.artwork = old.artwork; enriched.title = old.title; enriched.artist = old.artist
                    }
                    return enriched
                }
                if changed { self.queueIndex = 0; self.artworkReadAt = .distantPast }
                self.queueIndex = min(self.queueIndex, records.count)
                self.queueMessage = records.isEmpty ? "В очереди пока нет треков" : nil
                self.resolveQueueArtwork()
            case .permissionRequired:
                self.queueRecords = []; self.queueNeedsPermission = true
                self.queueMessage = "Разрешите AUDIAL в «Универсальном доступе». Если осталась запись старой версии, удалите её и добавьте AUDIAL из «Программ»."
            case .unavailable(let reason): self.queueRecords = []; self.queueMessage = reason
            }
        }
    }
    func connectQueue() { MusicQueueReader.requestPermission(); loadQueue() }
    private func resolveQueueArtwork() {
        guard !resolvingArtwork, !queueRecords.isEmpty,
              queueRecords.contains(where: { $0.artwork == nil }), Date().timeIntervalSince(artworkReadAt) > 30 else { return }
        resolvingArtwork = true; artworkReadAt = Date()
        let labels = queueRecords.map(\.label)
        artworkResolver.resolve(queueRecords) { [weak self] records in
            guard let self else { return }
            self.resolvingArtwork = false
            guard self.queueRecords.map(\.label) == labels else { return }
            self.queueRecords = records
        }
    }
    func hoverQueue(_ index: Int) {
        let point = NSEvent.mouseLocation
        if let previous = lastQueueHoverPoint, hypot(point.x - previous.x, point.y - previous.y) < 3 { return }
        selectQueue(index)
    }
    func selectQueue(_ index: Int) {
        guard !queueRecords.isEmpty else { return }
        lastQueueHoverPoint = NSEvent.mouseLocation
        let next = max(0, min(queueRecords.count, index))
        if next != queueIndex { pulse(); queueIndex = next }
    }
    func browseQueue(_ delta: Int) {
        if queueIndex == 0 && delta < 0 { openMode(.queue); return }
        selectQueue(queueIndex < 0 ? 0 : queueIndex + delta)
    }
    func activateQueueSelection() {
        guard !queueActivating else { return }
        guard queueRecords.indices.contains(queueIndex) else { openFullQueue(); return }
        let index = queueIndex, expectedID = track.id
        let labels = Array(queueRecords.prefix(index + 1).map(\.label))
        queueActivating = true
        queueReader.read { [weak self] result in
            guard let self else { return }
            guard case .records(let fresh) = result, Array(fresh.prefix(index + 1).map(\.label)) == labels,
                  self.track.id == expectedID else {
                self.queueActivating = false; self.notify("Очередь изменилась — выберите трек снова"); self.loadQueue(); return
            }
            self.adapter.playUpcoming(offset: index, expectedTrackID: expectedID) { [weak self] error in
                guard let self else { return }
                self.queueActivating = false
                if let error { self.notify(error.localizedDescription) }
                else { self.mode = .main; self.queueRecords = []; self.queueIndex = 0; self.pulse(); self.refresh() }
            }
        }
    }
    func toggleShuffle() {
        guard !shuffleChanging, Date().timeIntervalSince(lastShuffleTap) > 0.6 else { return }
        lastShuffleTap = Date()
        let previous = shuffleEnabled, desired = !shuffleEnabled
        shuffleRevision += 1
        shuffleChanging = true
        withAnimation(.easeInOut(duration: 0.18)) { shuffleEnabled = desired }
        pulse()
        adapter.command("set shuffle enabled to \(desired ? "true" : "false")") { [weak self] error in
            guard let self else { return }
            if let error {
                self.shuffleEnabled = previous; self.shuffleChanging = false
                self.notify(error.localizedDescription)
            } else {
                // Ignore reads already in flight and let Music finish updating its queue.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
                    guard let self else { return }
                    self.shuffleChanging = false; self.shuffleRevision += 1
                    self.refresh(); self.loadQueue()
                }
            }
        }
    }
    func showLyrics() {
        pulse()
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app"))
        queueReader.showLyrics { [weak self] success in
            if !success { self?.notify("Откройте «Текст» в Music") }
        }
    }
    func openFullQueue() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app"))
        queueReader.read { _ in }
    }
    func action(_ index: Int) {
        pulse()
        if index == 0 { command("set favorited of current track to not (favorited of current track)") }
        else {
            openMusic()
            if index == 1 { notify("Use ••• → Add to Library in Music") }
        }
    }
    func openMusic() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app"))
        if !track.id.isEmpty { command("reveal current track") }
    }
    func key(_ code: UInt16, down: Bool, repeated: Bool) {
        if !down { if code == 123 || code == 124 { endHold() }; return }
        guard !repeated else { return }
        switch code {
        case 53: dismiss?()
        case 49: toggle()
        case 36: if mode == .actions { action(actionIndex) } else if mode == .queue { activateQueueSelection() } else { toggle() }
        case 123, 124:
            if mode == .actions { actionIndex = (actionIndex + (code == 123 ? 2 : 1)) % 3; pulse() }
            else if mode == .main { beginHold(code == 123 ? -1 : 1) }
            else if mode == .queue { browseQueue(code == 123 ? -1 : 1) }
        case 126: if mode == .queue { browseQueue(-1) } else { openMode(.actions) }
        case 125: if mode == .queue { browseQueue(1) } else { openMode(.queue) }
        default: break
        }
    }
}
