import AppKit

let scripts = [
    """
    tell application "Music"
        tell library playlist 1
            set trackIDs to persistent ID of every track
            set trackNames to name of every track
            set trackArtists to artist of every track
            set trackAlbums to album of every track
        end tell
        return {trackIDs, trackNames, trackArtists, trackAlbums}
    end tell
    """,
    "tell application \"Music\" to set shuffle enabled to true",
    "tell application \"Music\" to set shuffle enabled to false",
    "tell application \"Music\" to get raw data of artwork 1 of (first track of library playlist 1 whose persistent ID is \"0123456789ABCDEF\")",
    """
    tell application "Music"
        if persistent ID of current track is not "0123456789ABCDEF" then error "Track changed"
        repeat 2 times
            next track
            delay 0.2
        end repeat
        play
    end tell
    """
]
for source in scripts {
    var error: NSDictionary?
    precondition(NSAppleScript(source: source)!.compileAndReturnError(&error), "Invalid Music script: \(String(describing: error))")
}
print("Queue metadata, artwork, and guarded playback scripts compile against installed Music dictionary. No scripts executed.")
