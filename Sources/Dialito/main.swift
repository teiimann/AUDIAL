import AppKit
import SwiftUI
import ImageIO

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let music = MusicController()
    private var hud: HUDWindowController!
    private let shortcut = GlobalShortcut()
    private var status: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        hud = HUDWindowController(music: music)
        shortcut.onPress = { [weak self] in self?.hud.toggle() }
        if !shortcut.register(shortcut.preset) { music.notify("Shortcut in use. Choose another in the menu.") }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "AUDIAL")
        status.button?.toolTip = "AUDIAL — открыть, скрыть или выйти"
        rebuildMenu(); music.start(); hud.show()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { hud.show() }
        return false
    }
    private func rebuildMenu() {
        let menu = NSMenu()
        let title = NSMenuItem(title: "AUDIAL", action: nil, keyEquivalent: ""); title.isEnabled = false; menu.addItem(title)
        add("Показать / скрыть · \(shortcut.label)", #selector(toggle), to: menu)
        add("Скрыть круг · Esc", #selector(hide), to: menu)
        menu.addItem(.separator())
        let shortcuts = NSMenu()
        let m = add("⌘M", #selector(useCommandM), to: shortcuts); m.state = shortcut.preset == .commandM ? .on : .off
        let a = add("⌃⌥Space", #selector(useSpace), to: shortcuts); a.state = shortcut.preset == .controlOptionSpace ? .on : .off
        let b = add("⌃⌥D", #selector(useD), to: shortcuts); b.state = shortcut.preset == .controlOptionD ? .on : .off
        let parent = NSMenuItem(title: "Горячая клавиша", action: nil, keyEquivalent: ""); parent.submenu = shortcuts; menu.addItem(parent)
        add("Открыть Apple Music", #selector(openMusic), to: menu)
        menu.addItem(.separator()); add("Выйти из AUDIAL", #selector(quit), to: menu)
        status.menu = menu
    }
    @discardableResult private func add(_ title: String, _ action: Selector, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item); return item
    }
    @objc private func hide() { hud.hide() }
    @objc private func toggle() { hud.toggle() }
    @objc private func openMusic() { music.openMusic() }
    @objc private func useCommandM() { changeShortcut(.commandM) }
    @objc private func useSpace() { changeShortcut(.controlOptionSpace) }
    @objc private func useD() { changeShortcut(.controlOptionD) }
    private func changeShortcut(_ preset: ShortcutPreset) {
        if preset == shortcut.preset { return }
        if !shortcut.register(preset) { music.notify("Shortcut already in use"); hud.show() }
        rebuildMenu()
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

@MainActor func renderPreviews() {
    let model = MusicController()
    func render(_ name: String, time: Double = 0) {
        let renderer = ImageRenderer(content: DialView(music: model, previewTime: time))
        renderer.scale = 2
        if let image = renderer.nsImage, let data = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: data), let png = bitmap.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath + "/build/" + name + ".png"))
        }
    }
    for (name, mode) in [("dial", DialMode.main), ("actions", DialMode.actions), ("queue", DialMode.queue)] {
        model.mode = mode; render(name)
    }
    model.queueRecords = (1...5).map { QueueRecord(id: "fixture-\($0)", label: "Preview track \($0) · Vinyl study") }
    model.mode = .queue
    render("queue-five-fixture")
    model.queueIndex = 3
    render("queue-selected-fixture")
    // Synthetic artwork fixtures only for visual QA; never used by live playback.
    model.mode = .main
    model.track.title = "Color study"
    model.track.artist = "Preview fixture"
    model.track.playing = true
    model.track.duration = 240; model.track.position = 92
    for (name, color) in [("warm", NSColor.systemOrange), ("cool", NSColor.systemBlue)] {
        let art = NSImage(size: NSSize(width: 256, height: 256), flipped: false) { rect in
            color.setFill(); rect.fill()
            NSGradient(starting: color, ending: .black)?.draw(in: NSBezierPath(ovalIn: rect.insetBy(dx: 15, dy: 15)), angle: 35)
            NSColor.systemPink.setFill()
            NSBezierPath(ovalIn: NSRect(x: 140, y: 130, width: 95, height: 95)).fill()
            return true
        }
        model.artwork = art; model.palette = ArtworkPalette.extract(from: art)
        render("preview-" + name, time: 0.2)
        render("preview-" + name + "-motion", time: 0.65)
        if name == "cool", CommandLine.arguments.contains("--animate") {
            let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath + "/build/motion-preview.gif")
            if let gif = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, 36, nil) {
                CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
                for frame in 0..<36 {
                    let content = DialView(music: model, previewTime: Double(frame) / 18)
                        .background(Color(red: 0.035, green: 0.04, blue: 0.055))
                    let renderer = ImageRenderer(content: content)
                    renderer.scale = 2
                    if let image = renderer.cgImage {
                        CGImageDestinationAddImage(gif, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 18]] as CFDictionary)
                    }
                }
                _ = CGImageDestinationFinalize(gif)
            }
        }
    }
}

if CommandLine.arguments.contains("--render-preview") {
    MainActor.assumeIsolated { renderPreviews() }
    exit(0)
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
