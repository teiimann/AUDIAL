import AppKit

struct MusicSnapshot {
    var id = "", title = "Nothing playing", artist = "Open Apple Music to begin"
    var duration: Double = 0, position: Double = 0
    var playing = false, favorite = false, shuffled = false
    var artwork: Data?
}

enum MusicAppleEvents {
    static let queue = DispatchQueue(label: "app.dialito.apple-events", qos: .userInitiated)
}

/// Serial Apple events keep slow Music responses off the UI thread.
final class AppleMusicAdapter {
    private let queue = MusicAppleEvents.queue
    private var artworkID = ""
    private func execute(_ source: String) throws -> NSAppleEventDescriptor {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { throw NSError(domain: "Music", code: 1) }
        let result = script.executeAndReturnError(&error)
        if let error { throw NSError(domain: "Music", code: error[NSAppleScript.errorNumber] as? Int ?? 1, userInfo: [NSLocalizedDescriptionKey: error[NSAppleScript.errorMessage] as? String ?? "Music did not respond."]) }
        return result
    }
    func read(completion: @escaping (Result<MusicSnapshot, Error>) -> Void) {
        queue.async {
            do {
                guard NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").count > 0 else {
                    DispatchQueue.main.async { completion(.success(MusicSnapshot())) }; return
                }
                let result = try self.execute("""
                tell application "Music"
                    if player state is stopped then return {}
                    set t to current track
                    return {persistent ID of t, name of t, artist of t, duration of t, player position, player state is playing, favorited of t, shuffle enabled}
                end tell
                """)
                var state = MusicSnapshot()
                if result.numberOfItems >= 7 {
                    state.id = result.atIndex(1)?.stringValue ?? ""
                    state.title = result.atIndex(2)?.stringValue ?? "Unknown song"
                    state.artist = result.atIndex(3)?.stringValue ?? "Unknown artist"
                    state.duration = Double(result.atIndex(4)?.stringValue ?? "") ?? 0
                    state.position = Double(result.atIndex(5)?.stringValue ?? "") ?? 0
                    state.playing = result.atIndex(6)?.booleanValue ?? false
                    state.favorite = result.atIndex(7)?.booleanValue ?? false
                    state.shuffled = result.atIndex(8)?.booleanValue ?? false
                    if state.id != self.artworkID {
                        state.artwork = try? self.execute("tell application \"Music\" to get raw data of artwork 1 of current track").data
                        if state.artwork != nil { self.artworkID = state.id }
                    }
                } else { self.artworkID = "" }
                DispatchQueue.main.async { completion(.success(state)) }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
    func playUpcoming(offset: Int, expectedTrackID: String, completion: @escaping (Error?) -> Void) {
        guard (0..<5).contains(offset), !expectedTrackID.isEmpty,
              expectedTrackID.allSatisfy({ $0.isHexDigit }) else {
            completion(NSError(domain: "Music", code: 2, userInfo: [NSLocalizedDescriptionKey: "Текущий трек изменился. Обновите очередь."]))
            return
        }
        command("""
        if persistent ID of current track is not "\(expectedTrackID)" then error "Текущий трек изменился. Выберите песню снова."
        repeat \(offset + 1) times
            next track
            delay 0.2
        end repeat
        play
        """, completion: completion)
    }
    func command(_ command: String, completion: @escaping (Error?) -> Void) {
        queue.async {
            do { _ = try self.execute("tell application \"Music\"\n\(command)\nend tell"); DispatchQueue.main.async { completion(nil) } }
            catch { DispatchQueue.main.async { completion(error) } }
        }
    }
}
