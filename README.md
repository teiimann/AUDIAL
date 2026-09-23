# AUDIAL

A compact 241.5-point native, temporary Apple Music dial for macOS 13+. SwiftUI draws the wheel; an AppKit nonactivating panel floats above the active workspace. No dependencies, accounts, network requests, or private media APIs.

## Run

```sh
./scripts/build.sh
open .build/AUDIAL.app
```

The command-line Swift toolchain is sufficient; full Xcode is optional. Open `Package.swift` in Xcode to develop. The build uses the persistent `DIALITO Local Development` identity in the login Keychain. It is a local signed build, not a notarized distribution build. There is no ad-hoc fallback.

Allow AUDIAL to control Music when macOS asks. This can be changed in System Settings → Privacy & Security → Automation. Play a song in Music to populate the dial. Music does not launch automatically during polling.

## Controls

- Command–M toggles the dial by default, taking precedence over Minimize while AUDIAL is running. The menu bar → Global shortcut also offers Control–Option–Space and Control–Option–D and remembers the choice.
- Center, Space, or Return: play/pause. The cover rotates during playback (one revolution per sixteen seconds); metadata stays upright. Rotation pauses while hidden, paused, or Reduce Motion is enabled.
- Left/right: previous/next on release. Keyboard and pointer presses share sector compression, color, and spring-release feedback. Hold for accelerated seeking, then release to commit the position.
- Down: opens a drawer of up to five actual upcoming songs, read from Music’s queue via Accessibility. The drawer starts as five compact record rims. The nearest record is #1; #5 sits at the back/bottom. Titles are printed along each vinyl’s outer groove, with no list-row backgrounds. Available library artwork textures the disc and its center label. The queue is drawn at 84% scale. The Apple Music link sits below the stack and has its own highlighted spring animation after the last song; selecting it collapses all records without selecting the first one. Down moves away from the center; Up moves toward the first song and collapses the queue when pressed again. The selected disc slides within the stack to expose its artwork and artist; no separate preview circle is drawn. Hover, arrows, and scrolling select a record. Return plays the selected upcoming track after re-reading the queue, or opens the full list when “Вся очередь” is selected.
- Hover only colors and elastically expands the sector. Click the top/bottom sector to toggle its drawer; hovering never opens it.
- The open queue splits the lower sector into Shuffle and Lyrics. Shuffle explicitly sets Music’s `shuffle enabled` Boolean to the opposite state, guards overlapping commands, and labels the current state independently of hover; Lyrics opens Music’s lyrics pane.
- Up: expands the existing top sector into a continuous three-part action arc. Left/right selects an action; Return activates it.
- Escape: immediately dismiss the entire dial, including when actions or queue are expanded.
- Click or drag the thin progress ring to choose a position; release commits the seek. The timestamp appears inside the artwork. Crossing 12 o’clock clamps at the beginning/end instead of jumping.
- Hover the cover for metadata; opening also reveals it for 1.8 seconds.
- Scrolling browses an already open queue. It does not open drawers or skip songs from the main dial.
- Typing a non-control key dismisses the dial. The first key dismisses only (it is not replayed into the previous app); subsequent typing goes to that app. Space, Return, and arrows remain music controls.
- Modifier keys alone never dismiss. Command–M toggles visibility; Escape dismisses. A completed app switch with Command held also dismisses.
- Clicking another application or activating it dismisses; transparent corners inside the HUD do not. Changing Spaces also dismisses. The queue reader separately requires Accessibility permission.
- Outside clicks dismiss. The dial follows the screen containing the pointer when summoned.

Haptic ticks use AppKit's default feedback performer and require supported hardware. Opening the HUD doesn't activate the application. The dial uses live, procedural 30 fps radial bars and orbital highlights while playing, a fixed artwork center, press ripples, and a spring-expanded three-part action arc. Animation pauses while the HUD is hidden or playback is paused; Reduce Motion disables continuous motion. The spectrum-style bars and pulse are decorative playback ambience, not measured frequencies or detected beats. AUDIAL does not capture system audio or request microphone access.

Two saturation-weighted artwork colors tint the entire housing, halo, spectrum, and progress ring; monochrome artwork uses a neutral palette. Palette changes crossfade over 0.9 seconds.

## Verified integration boundaries

Checked against the locally installed Music scripting dictionary (`/System/Applications/Music.app/Contents/Resources/com.apple.Music.sdef`) and macOS SDK MusicKit Swift interface.

| Capability | Implementation |
| --- | --- |
| Current song, artist, duration, position | Music Apple events |
| Album art | Raw artwork data, cached per persistent track ID |
| Play/pause, next/previous, seek | Music scripting commands and player position |
| Favorite | Read/write current track's `favorited` property |
| Show song | `reveal current track`, then Music activation |
| Actual Up Next queue | Opt-in Accessibility reader of Music’s queue table; up to five rows after the explicit Playing Next / На очереди heading. Never infer from playlist order. |
| Add streaming song to library | No general supported scripting command; open Music and explain its Add to Library action |

`SystemMusicPlayer` is marked unavailable on macOS in the installed SDK. MusicKit's application player is a separate playback session and would not fulfill control of the existing Music app. Music's scripting `add` command adds files to playlists; it is not a substitute for adding the current catalog song to the user's cloud library.

No fake five-song list is shown. The opt-in queue reader uses public Accessibility APIs scoped to Music, opens its queue sidebar via its observed queue-button identifier when needed, and reads track labels after the queue heading. It needs System Settings → Privacy & Security → Accessibility → AUDIAL enabled. The permission must be granted by the user. Hovering/browsing does not start playback. Enter re-reads the queue and verifies the selected prefix and current track ID before advancing Music by the selected number of entries, then starting playback. The full-list item opens Music’s queue. Artwork is resolved only from exact local-library metadata matches; unavailable covers use a neutral record, never unrelated artwork.

The bridge was based on the installed Music UI (`Music.miniPlayer.queueButton`, queue `headerContainer`, table rows), with Russian and English heading support. Music UI updates, closed windows, or virtualization can prevent reading; the drawer reports an explicit recovery instruction. In that case open Music’s queue near the Playing Next heading and refresh. The stable certificate-based signing requirement preserves the Accessibility grant across builds. Missing artwork uses a neutral record graphic. Live Music playback and permissions require a manual smoke test with an actual playing track.

## Architecture

- `Playback/AppleMusicAdapter.swift`: serialized background Apple events, errors, cached artwork.
- `Playback/MusicController.swift`: observable playback and interaction state, polling, press/hold behavior.
- `HUD/DialView.swift`: radial controls, draggable progress, and a morphing three-part lower arc.
- `HUD/VinylDrawer.swift`: real queue labels on animated, browsable records.
- `Input/DialPointerSurface.swift`: AppKit tracking and one non-overlapping polar mouse hit map.
- `Input/DialGeometry.swift`: tested sector targeting and circular seek mapping.
- `Playback/MusicQueueReader.swift`: permission-aware, bounded Music-only Accessibility reads with explicit window roots, localized-role-independent container lookup, and support for multiple text roles.
- `Playback/QueueArtworkResolver.swift`: cached exact-label local-library artwork lookup, off the UI thread.
- `HUD/MotionHalo.swift`: procedural spectrum-style bars and traveling highlights, with visibility and Reduce Motion handling.
- `HUD/HUDWindowController.swift`: floating panel, screen selection, local keys/gestures, dismissal.
- `Input/GlobalShortcut.swift`: registered global hotkey, conflict handling, persistent presets.
- `Theme/ArtworkPalette.swift`: downsampled saturation-weighted hue clustering, readable restrained accents.

## Manual verification

1. Launch with Music closed: honest empty state, no unexpected Music launch.
2. Start a song in Music, grant Automation, verify title/art/progress.
3. Toggle via shortcut from another app and a second display. Escape/outside click dismiss.
4. Test click versus hold for pointer and arrow keys, including release and dismissal mid-hold.
5. Check favorite against Music. Confirm Add in Music handoff. Grant queue access manually, compare the five labels against Music, and browse with drag, scroll, and arrows. Test denial/empty/unavailable queue states.
6. Change covers, including monochrome artwork, and inspect theme transitions.
7. Change shortcut preset; verify persistence after relaunch and conflict reporting.

API references: [SystemMusicPlayer](https://developer.apple.com/documentation/musickit/systemmusicplayer), [NSHapticFeedbackManager](https://developer.apple.com/documentation/appkit/nshapticfeedbackmanager).

## Visual previews

Run `.build/release/Dialito --render-preview` after building to render empty, actions, and queue views plus warm/cool synthetic artwork fixtures at two animation phases. These generated PNGs are QA outputs only. The running app draws native SwiftUI and Canvas elements continuously; it does not display these screenshots.

Interaction regression checks: compile `scripts/check-dial.swift` with `Sources/Dialito/Input/DialGeometry.swift` and `Sources/Dialito/Playback/MusicQueueReader.swift`. Covers four sectors, expanded action targeting, seek quadrants/wrap clamping, Russian/English queue headings, history exclusion, and the five-track cap. The actual installed app’s bottom-sector click/expansion was checked through the desktop UI; the installed signed app reads five real upcoming tracks and retains its Accessibility grant after a signed rebuild.

### Local build permissions

The user approved creating `DIALITO Local Development` in the login Keychain, with user-domain trust restricted to code signing. `scripts/setup-signing.py` performs that one-time setup; never regenerate the identity during an update. The private key stays in Keychain; only the public certificate is stored in `~/Library/Application Support/DIALITO/Signing/development.cer`.

`scripts/build.sh` requires this identity and fails rather than silently using ad-hoc signing. The designated requirement binds `app.dialito.controller` to this certificate, not a changing binary hash. Migration from the previous ad-hoc release requires removing the old Accessibility entry and adding `/Applications/AUDIAL.app` once. Subsequent builds use the same identity. AUDIAL still checks `AXIsProcessTrusted()` and respects macOS privacy controls.

## AUDIAL test distribution

`./scripts/build.sh` builds arm64 and x86_64 with separate SwiftPM caches, combines them with `lipo`, and signs `.build/AUDIAL.app`. The hidden build directory avoids an extra Spotlight app entry. The display name is AUDIAL; the internal bundle identifier and local signing identity are intentionally preserved for existing privacy grants.

`./scripts/package.sh` creates `dist/AUDIAL-0.2.0-universal.zip` with the app and Russian installation instructions. This is a locally signed, unnotarized friends-test build for macOS 13+. Intel is cross-compiled, not runtime-tested on Intel hardware. Public distribution should use Developer ID Application signing, hardened runtime with the required Apple Events entitlement, and Apple notarization/stapling. Never distribute the local private key or ask testers to trust its certificate.

Queue selection now uses a 0.24-second spring and non-animated pointer target layout so hover does not follow a slowly moving hit area.
