import AppKit

/// Only the HUD's explicit music controls retain keyboard focus.
enum HUDInputPolicy {
    enum Action: Equatable { case control, dismiss, pass }
    static let shortcutModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
    static func action(keyCode: UInt16, keyDown: Bool, modifiers: NSEvent.ModifierFlags) -> Action {
        if keyCode == 53 { return keyDown ? .dismiss : .pass }
        if modifiers.intersection(shortcutModifiers).isEmpty && [UInt16(49), 36, 123, 124, 125, 126].contains(keyCode) {
            return .control
        }
        return keyDown ? .dismiss : .pass
    }
    static func startsShortcut(previous: NSEvent.ModifierFlags, current: NSEvent.ModifierFlags) -> Bool {
        !current.intersection(shortcutModifiers).subtracting(previous.intersection(shortcutModifiers)).isEmpty
    }
}
