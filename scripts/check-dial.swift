import AppKit

@main struct DialChecks {
    static func main() {
        precondition(DialGeometry.target(x: 110, y: 0, expanded: false) == .direction(1))
        precondition(DialGeometry.target(x: -110, y: 0, expanded: false) == .direction(3))
        precondition(DialGeometry.target(x: 0, y: -110, expanded: false) == .direction(0))
        precondition(DialGeometry.target(x: 0, y: 110, expanded: false) == .direction(2))
        precondition(DialGeometry.target(x: 0, y: -145, expanded: true) == .action(1))
        precondition(DialGeometry.target(x: -70, y: -120, expanded: true) == .action(0))
        precondition(DialGeometry.target(x: 70, y: -120, expanded: true) == .action(2))
        precondition(DialGeometry.target(x: 0, y: 145, expanded: false) == nil)
        precondition(DialGeometry.target(x: 0, y: 0, expanded: true) == nil)
        precondition(DialGeometry.target(x: 73, y: 0, expanded: false) == .progress)
        precondition(DialGeometry.target(x: -45, y: 110, expanded: false, queueExpanded: true) == .queueTool(0))
        precondition(DialGeometry.target(x: 45, y: 110, expanded: false, queueExpanded: true) == .queueTool(1))
        precondition(DialGeometry.target(x: 0, y: 145, expanded: false, queueExpanded: true) == nil)
        precondition(DialGeometry.fraction(x: 0, y: -73) == 0)
        precondition(DialGeometry.fraction(x: 73, y: 0) == 0.25)
        precondition(DialGeometry.fraction(x: 0, y: 73) == 0.5)
        precondition(DialGeometry.fraction(x: -73, y: 0) == 0.75)
        precondition(DialGeometry.dragFraction(0.01, previous: 0.99) == 1)
        precondition(DialGeometry.dragFraction(0.99, previous: 0.01) == 0)
        precondition(MusicQueueReader.upcomingLabels(from: ["History track", "На очереди", "A", "B", "C", "D", "E", "F"]) == ["A", "B", "C", "D", "E"])
        precondition(MusicQueueReader.upcomingLabels(from: ["A", "B", "C"]) == nil)
        precondition(MusicQueueReader.upcomingLabels(from: ["Playing Next", "A", "AutoPlay", "Not next"]) == ["A"])
        precondition(MusicQueueReader.upcomingLabels(from: ["На очереди"]) == [])
        print("Dial checks passed: radial controls, action sectors, seek angles/wrap, queue order and no-history fallback.")
    }
}
