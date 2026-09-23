import AppKit
import Carbon

enum ShortcutPreset: String {
    case commandM, controlOptionSpace, controlOptionD
    var label: String {
        switch self {
        case .commandM: return "⌘M"
        case .controlOptionSpace: return "⌃⌥Space"
        case .controlOptionD: return "⌃⌥D"
        }
    }
    var keyCode: UInt32 {
        switch self {
        case .commandM: return UInt32(kVK_ANSI_M)
        case .controlOptionSpace: return UInt32(kVK_Space)
        case .controlOptionD: return UInt32(kVK_ANSI_D)
        }
    }
    var modifiers: UInt32 { self == .commandM ? UInt32(cmdKey) : UInt32(controlKey | optionKey) }
}

final class GlobalShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPress: (() -> Void)?
    var preset: ShortcutPreset {
        ShortcutPreset(rawValue: UserDefaults.standard.string(forKey: "shortcutPreset") ?? "") ?? .commandM
    }
    var label: String { preset.label }
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, pointer in
            guard let pointer else { return OSStatus(eventNotHandledErr) }
            Unmanaged<GlobalShortcut>.fromOpaque(pointer).takeUnretainedValue().onPress?()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    @discardableResult func register(_ preset: ShortcutPreset) -> Bool {
        let old = hotKey
        var replacement: EventHotKeyRef?
        let result = RegisterEventHotKey(preset.keyCode, preset.modifiers, EventHotKeyID(signature: 0x4449414C, id: 1), GetApplicationEventTarget(), 0, &replacement)
        guard result == noErr else { return false }
        if let old { UnregisterEventHotKey(old) }
        hotKey = replacement
        UserDefaults.standard.set(preset.rawValue, forKey: "shortcutPreset")
        return true
    }
    deinit { if let hotKey { UnregisterEventHotKey(hotKey) }; if let handler { RemoveEventHandler(handler) } }
}
