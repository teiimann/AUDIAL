import AppKit
import ApplicationServices

struct QueueRecord: Identifiable {
    let id: String
    let label: String
    var title: String? = nil
    var artist: String? = nil
    var artwork: NSImage? = nil
}
enum QueueReadResult {
    case records([QueueRecord]), permissionRequired, unavailable(String)
}

/// Reads only Music's actual queue table, never substitutes playlist order.
final class MusicQueueReader {
    private var deadline = Date.distantFuture
    private let worker = DispatchQueue(label: "app.dialito.queue", qos: .userInitiated)
    static func requestPermission() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        if !AXIsProcessTrusted(), let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
    }
    private func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        guard Date() < deadline else { return nil }
        var result: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success ? result : nil
    }
    private func string(_ element: AXUIElement, _ attribute: String) -> String { value(element, attribute) as? String ?? "" }
    private func children(_ element: AXUIElement) -> [AXUIElement] { value(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] }
    private func find(_ root: AXUIElement, limit: Int = 600, matching predicate: (AXUIElement) -> Bool) -> AXUIElement? {
        var queue = [root], index = 0
        // Breadth first: do not exhaust the budget inside a large library table
        // before reaching the queue sidebar at the same window level.
        while index < queue.count && index < limit && Date() < deadline {
            let item = queue[index]; index += 1
            if predicate(item) { return item }
            // Library outlines may contain thousands of rows. Neither queue chrome
            // nor mini-player buttons live inside their table cells.
            let role = string(item, kAXRoleAttribute)
            if role != kAXOutlineRole && role != kAXTableRole { queue.append(contentsOf: children(item)) }
        }
        return nil
    }
    private func queueContainer(_ root: AXUIElement) -> AXUIElement? {
        find(root) { item in
            let identifier = string(item, kAXIdentifierAttribute)
            // Role descriptions are localized and may not be AXDescription.
            // The queue container ID is stable in the observed Music window.
            return identifier == "headerContainer"
        }
    }
    private func text(_ row: AXUIElement) -> String? {
        guard let field = find(row, limit: 35, matching: { [kAXStaticTextRole, kAXTextFieldRole, kAXTextAreaRole].contains(string($0, kAXRoleAttribute)) }) else { return nil }
        for attribute in [kAXValueAttribute, kAXDescriptionAttribute, kAXTitleAttribute] {
            let result = string(field, attribute).trimmingCharacters(in: .whitespacesAndNewlines)
            if !result.isEmpty { return result }
        }
        return nil
    }
    static func upcomingLabels(from rows: [String]) -> [String]? {
        func normalized(_ s: String) -> String { s.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
        let headings = ["на очереди", "далее", "playing next", "up next", "next up"]
        guard let start = rows.firstIndex(where: { headings.contains(normalized($0)) }) else { return nil }
        let stop = ["история", "history", "autoplay", "автоплеер", "automix"]
        return Array(rows.dropFirst(start + 1).prefix(while: { !stop.contains(normalized($0)) }).prefix(5))
    }
    func showLyrics(completion: @escaping (Bool) -> Void) {
        guard AXIsProcessTrusted() else { completion(false); return }
        worker.async {
            self.deadline = Date().addingTimeInterval(4)
            guard let music = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").first else {
                DispatchQueue.main.async { completion(false) }; return
            }
            let root = AXUIElementCreateApplication(music.processIdentifier)
            AXUIElementSetMessagingTimeout(root, 0.35)
            let windows = self.value(root, kAXWindowsAttribute) as? [AXUIElement] ?? []
            // Do not toggle an already visible lyrics pane closed.
            let visible = windows.contains { window in
                self.find(window, matching: { self.string($0, kAXRoleAttribute) == kAXGroupRole &&
                    ["Текст", "Lyrics"].contains(self.string($0, kAXDescriptionAttribute)) }) != nil
            }
            let button = windows.compactMap { window in self.find(window, matching: {
                self.string($0, kAXIdentifierAttribute) == "Music.miniPlayer.lyricsButton"
            }) }.first
            let success = visible || button.map { AXUIElementPerformAction($0, kAXPressAction as CFString) == .success } == true
            DispatchQueue.main.async { completion(success) }
        }
    }
    func read(completion: @escaping (QueueReadResult) -> Void) {
        guard AXIsProcessTrusted() else { completion(.permissionRequired); return }
        worker.async {
            self.deadline = Date().addingTimeInterval(4)
            func finish(_ result: QueueReadResult) { DispatchQueue.main.async { completion(result) } }
            guard let music = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").first else {
                finish(.unavailable("Откройте Music и запустите трек")); return
            }
            let root = AXUIElementCreateApplication(music.processIdentifier)
            AXUIElementSetMessagingTimeout(root, 0.35)
            let windows = self.value(root, kAXWindowsAttribute) as? [AXUIElement] ?? []
            let searchRoots = windows.isEmpty ? [root] : windows
            var container = searchRoots.compactMap { self.queueContainer($0) }.first
            if container == nil,
               let button = searchRoots.compactMap({ self.find($0, matching: { self.string($0, kAXIdentifierAttribute) == "Music.miniPlayer.queueButton" }) }).first {
                _ = AXUIElementPerformAction(button, kAXPressAction as CFString)
                // Music constructs the queue asynchronously. Bounded wait on the worker only.
                for _ in 0..<4 {
                    Thread.sleep(forTimeInterval: 0.15)
                    container = searchRoots.compactMap { self.queueContainer($0) }.first
                    if container != nil { break }
                }
            }
            guard let container,
                  let table = self.find(container, limit: 80, matching: { self.string($0, kAXRoleAttribute) == kAXTableRole }) else {
                finish(.unavailable("Откройте «На очереди» в окне Music, затем обновите")); return
            }
            for attribute in [kAXVisibleRowsAttribute, kAXRowsAttribute, kAXChildrenAttribute] {
                let rows = self.value(table, attribute) as? [AXUIElement] ?? []
                var labels: [String] = []
                for row in rows.prefix(1000) {
                    if let label = self.text(row) { labels.append(label) }
                    if let found = Self.upcomingLabels(from: labels), found.count == 5 { break }
                }
                if Date() >= self.deadline { finish(.unavailable("Music не ответил вовремя. Откройте его окно и обновите очередь")); return }
                if let upcoming = Self.upcomingLabels(from: labels) {
                    finish(.records(upcoming.enumerated().map { QueueRecord(id: "\($0.offset):\($0.element)", label: $0.element) })); return
                }
            }
            finish(.unavailable("Прокрутите очередь Music к заголовку «На очереди» и обновите"))
        }
    }
}
