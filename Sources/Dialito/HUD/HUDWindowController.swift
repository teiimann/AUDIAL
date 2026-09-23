import AppKit
import SwiftUI

final class HUDPanel: NSPanel {
    var onDismiss: (() -> Void)?
    override func resignKey() { super.resignKey() }
    override func cancelOperation(_ sender: Any?) { onDismiss?() }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
final class HUDWindowController {
    let panel: HUDPanel
    let music: MusicController
    private var local: Any?, outside: Any?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var scrollX: CGFloat = 0, scrollY: CGFloat = 0
    private var lastGesture = Date.distantPast
    init(music: MusicController) {
        self.music = music
        panel = HUDPanel(contentRect: NSRect(x: 0, y: 0, width: HUDLayout.width, height: HUDLayout.height), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.acceptsMouseMovedEvents = true
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: DialView(music: music))
        music.dismiss = { [weak self] in self?.hide() }
        panel.onDismiss = { [weak self] in self?.hide() }
        local = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged, .scrollWheel, .leftMouseDown]) { [weak self] event in
            guard let self, self.panel.isVisible else { return event }
            guard event.window === self.panel else { return event }
            if event.type == .keyDown || event.type == .keyUp {
                switch HUDInputPolicy.action(keyCode: event.keyCode, keyDown: event.type == .keyDown, modifiers: event.modifierFlags) {
                case .control:
                    self.music.key(event.keyCode, down: event.type == .keyDown, repeated: event.isARepeat)
                    return nil
                case .dismiss:
                    // This first key belongs to the key panel. Do not synthesize text into another app.
                    self.hide()
                    return nil
                case .pass: return event
                }
            }
            if event.type == .scrollWheel {
                guard event.momentumPhase.isEmpty, Date().timeIntervalSince(self.lastGesture) > 0.65 else { return nil }
                if event.phase == .began { self.scrollX = 0; self.scrollY = 0 }
                self.scrollX += event.scrollingDeltaX; self.scrollY += event.scrollingDeltaY
                if max(abs(self.scrollX), abs(self.scrollY)) > 65 {
                    if self.music.mode == .queue { self.music.browseQueue((abs(self.scrollY) > abs(self.scrollX) ? self.scrollY : self.scrollX) > 0 ? -1 : 1) }
                    self.scrollX = 0; self.scrollY = 0; self.lastGesture = Date()
                }
                return nil
            }
            return event
        }
        outside = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in self?.hide() }
        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            self?.hide()
        })
        workspaceObservers.append(workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.hide() })
    }
    func toggle() { panel.isVisible ? hide() : show() }
    func show() {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame { panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.midY - panel.frame.height / 2)) }
        music.mode = .main; music.visible = true; music.reveal(); music.refresh()
        panel.makeKeyAndOrderFront(nil)
    }
    func hide() { guard music.visible else { return }; music.visible = false; music.cancelHoverMode(); music.cancelPointerSeek(); music.endHold(cancel: true); music.hovering = false; panel.orderOut(nil) }
    deinit {
        if let local { NSEvent.removeMonitor(local) }
        if let outside { NSEvent.removeMonitor(outside) }
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
}
