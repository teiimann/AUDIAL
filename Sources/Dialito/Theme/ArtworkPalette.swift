import AppKit
import SwiftUI

struct DialPalette {
    var primary: Color
    var secondary: Color
    var surface: Color
    static let idle = DialPalette(primary: Color(red: 0.47, green: 0.94, blue: 0.83), secondary: Color(red: 0.55, green: 0.57, blue: 0.98), surface: Color(red: 0.04, green: 0.09, blue: 0.11))
}

enum ArtworkPalette {
    static func extract(from image: NSImage) -> DialPalette {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 40, pixelsHigh: 40, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return .idle }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: 40, height: 40))
        NSGraphicsContext.restoreGraphicsState()
        var bins = [(weight: Double, hue: Double, saturation: Double)](repeating: (0, 0, 0), count: 36)
        for x in 0..<40 { for y in 0..<40 {
            guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), c.alphaComponent > 0.5 else { continue }
            let h = c.hueComponent, s = c.saturationComponent, b = c.brightnessComponent
            guard b > 0.09, s > 0.12 else { continue }
            let i = min(35, Int(h * 36)), w = Double(s * s * sqrt(b))
            bins[i].weight += w; bins[i].hue += Double(h) * w; bins[i].saturation += Double(s) * w
        } }
        guard let best = bins.max(by: { $0.weight < $1.weight }), best.weight > 0 else {
            return DialPalette(primary: Color(white: 0.88), secondary: Color(white: 0.58), surface: Color(white: 0.09))
        }
        let hue = best.hue / best.weight
        let contrasting = bins.filter {
            guard $0.weight > best.weight * 0.08 else { return false }
            let distance = abs($0.hue / $0.weight - hue)
            return min(distance, 1 - distance) > 0.09
        }.max(by: { $0.weight < $1.weight })
        let secondHue = contrasting.map { $0.hue / $0.weight } ?? (hue + 0.08).truncatingRemainder(dividingBy: 1)
        let saturation = min(0.85, max(0.5, best.saturation / best.weight))
        return DialPalette(primary: Color(hue: hue, saturation: saturation, brightness: 1), secondary: Color(hue: secondHue, saturation: saturation * 0.85, brightness: 0.94), surface: Color(hue: hue, saturation: 0.58, brightness: 0.16))
    }
}
