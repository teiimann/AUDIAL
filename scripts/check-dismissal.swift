import AppKit

@main struct DismissalChecks {
    static func main() {
        for key: UInt16 in [0, 1, 8, 9, 48, 51, 117] {
            precondition(HUDInputPolicy.action(keyCode: key, keyDown: true, modifiers: []) == .dismiss)
            precondition(HUDInputPolicy.action(keyCode: key, keyDown: false, modifiers: []) == .pass)
        }
        for key: UInt16 in [49, 36, 123, 124, 125, 126] {
            precondition(HUDInputPolicy.action(keyCode: key, keyDown: true, modifiers: []) == .control)
            precondition(HUDInputPolicy.action(keyCode: key, keyDown: false, modifiers: []) == .control)
            precondition(HUDInputPolicy.action(keyCode: key, keyDown: true, modifiers: [.command]) == .dismiss)
        }
        precondition(HUDInputPolicy.action(keyCode: 53, keyDown: true, modifiers: [.command]) == .dismiss)
        precondition(HUDInputPolicy.startsShortcut(previous: [], current: [.command]))
        precondition(HUDInputPolicy.startsShortcut(previous: [.shift], current: [.command, .shift]))
        precondition(!HUDInputPolicy.startsShortcut(previous: [.command], current: []))
        precondition(!HUDInputPolicy.startsShortcut(previous: [.control, .option], current: [.option]))
        precondition(!HUDInputPolicy.startsShortcut(previous: [], current: [.shift]))
        precondition(!HUDInputPolicy.startsShortcut(previous: [.command], current: [.command]))
        print("Dismissal checks passed: typing, control keys, modified keys, and shortcut press/release.")
    }
}
