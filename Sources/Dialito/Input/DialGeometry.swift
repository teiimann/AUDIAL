import Foundation

enum DialTarget: Equatable {
    case direction(Int), action(Int), queueTool(Int), progress
}
enum DialGeometry {
    static func target(x: Double, y: Double, expanded: Bool, queueExpanded: Bool = false) -> DialTarget? {
        let radius = hypot(x, y)
        if radius >= 68.5 && radius <= 84 { return .progress }
        let angle = atan2(y, x) * 180 / .pi
        if queueExpanded && angle >= 45 && angle <= 135 && radius >= 90 && radius <= 140 {
            return .queueTool(angle > 90 ? 0 : 1)
        }
        if expanded && angle >= -135 && angle <= -45 && radius >= 90 && radius <= 158 {
            return .action(min(2, max(0, Int((angle + 135) / 30))))
        }
        guard radius >= 90 && radius <= 139 else { return nil }
        let index = (Int(floor((angle + 135) / 90)) + 4) % 4
        if expanded && index == 0 || queueExpanded && index == 2 { return nil }
        return .direction(index)
    }
    static func fraction(x: Double, y: Double) -> Double {
        let raw = (atan2(y, x) + .pi / 2) / (2 * .pi)
        return raw < 0 ? raw + 1 : raw
    }
    static func dragFraction(_ raw: Double, previous: Double) -> Double {
        if previous > 0.8 && raw < 0.2 { return 1 }
        if previous < 0.2 && raw > 0.8 { return 0 }
        return raw
    }
}
