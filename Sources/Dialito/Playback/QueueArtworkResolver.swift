import AppKit

/// Resolves real local-library artwork by the full queue label. Never guesses covers.
final class QueueArtworkResolver {
    private struct Song { let id: String; let title: String; let artist: String; let album: String }
    private var uniqueTitles: [String: Song] = [:]
    private var songs: [String: Song] = [:]
    private var refreshedAt = Date.distantPast
    private var images: [String: Data] = [:]
    private let worker = MusicAppleEvents.queue
    private func normalize(_ value: String) -> String {
        value.replacingOccurrences(of: "\u{FFFC}", with: "").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
    private func execute(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let value = NSAppleScript(source: "with timeout of 10 seconds\n\(source)\nend timeout")?.executeAndReturnError(&error)
        if let error { NSLog("AUDIAL artwork error: %@", error) }
        return error == nil ? value : nil
    }
    private func buildIndex() {
        guard Date().timeIntervalSince(refreshedAt) > 120 else { return }
        guard let columns = execute("""
        tell application "Music"
            tell library playlist 1
                set trackIDs to persistent ID of every track
                set trackNames to name of every track
                set trackArtists to artist of every track
                set trackAlbums to album of every track
            end tell
            return {trackIDs, trackNames, trackArtists, trackAlbums}
        end tell
        """), columns.numberOfItems == 4,
              let ids = columns.atIndex(1), let names = columns.atIndex(2), let artists = columns.atIndex(3), let albums = columns.atIndex(4) else { return }
        var index: [String: Song] = [:]
        var titles: [String: Song] = [:], ambiguous = Set<String>()
        if ids.numberOfItems > 0 {
            for i in 1...ids.numberOfItems {
                let song = Song(id: ids.atIndex(i)?.stringValue ?? "", title: names.atIndex(i)?.stringValue ?? "", artist: artists.atIndex(i)?.stringValue ?? "", album: albums.atIndex(i)?.stringValue ?? "")
                guard !song.id.isEmpty, !song.title.isEmpty else { continue }
                let titleKey = normalize(song.title)
                if let previous = titles[titleKey], previous.id != song.id { ambiguous.insert(titleKey) }
                titles[titleKey] = song
                index[normalize("\(song.title) \(song.artist) — \(song.album)")] = song
                index[normalize("\(song.title) \(song.artist)")] = song
            }
        }
        uniqueTitles = titles.filter { !ambiguous.contains($0.key) }
        songs = index; refreshedAt = Date()
        NSLog("AUDIAL artwork index: %d keys", index.count)
    }
    func resolve(_ records: [QueueRecord], completion: @escaping ([QueueRecord]) -> Void) {
        worker.async {
            UserDefaults.standard.set("Loading metadata", forKey: "QueueArtworkDiagnostics")
            self.buildIndex()
            let results: [(QueueRecord, Song?, Data?)] = records.map { record in
                let key = self.normalize(record.label)
                let withoutAlbum = record.label.components(separatedBy: " — ").first ?? record.label
                guard let song = self.songs[key] ?? self.songs[self.normalize(withoutAlbum)] ?? self.uniqueTitles[key] else { return (record, nil, nil) }
                guard song.id.allSatisfy({ $0.isHexDigit }) else { return (record, song, nil) }
                if self.images[song.id] == nil,
                   let data = self.execute("tell application \"Music\" to get raw data of artwork 1 of (first track of library playlist 1 whose persistent ID is \"\(song.id)\")")?.data {
                    self.images[song.id] = data
                }
                return (record, song, self.images[song.id])
            }
            UserDefaults.standard.set("Index: \(self.songs.count), matches: \(results.filter { $0.1 != nil }.count), images: \(results.filter { $0.2 != nil }.count)", forKey: "QueueArtworkDiagnostics")
            NSLog("AUDIAL artwork matches: %d; images: %d", results.filter { $0.1 != nil }.count, results.filter { $0.2 != nil }.count)
            if self.images.count > 30 { self.images = [:] }
            DispatchQueue.main.async {
                completion(results.map { original, song, data in
                    var record = original
                    record.title = song?.title ?? original.title; record.artist = song?.artist ?? original.artist
                    record.artwork = data.flatMap(NSImage.init(data:))
                    return record
                })
            }
        }
    }
}
