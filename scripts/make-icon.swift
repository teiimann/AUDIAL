import AppKit

let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let black = NSColor(calibratedWhite: 0.045, alpha: 1)
        let white = NSColor(calibratedWhite: 0.96, alpha: 1)
        black.setFill()
        NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944), xRadius: 215, yRadius: 215).fill()
        // AUDIAL's broken record silhouette, redrawn as resolution-independent paths.
        let ring = NSBezierPath()
        ring.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 298, startAngle: 58, endAngle: 408, clockwise: false)
        ring.lineWidth = 91
        ring.lineCapStyle = .butt
        white.setStroke(); ring.stroke()
        for radius: CGFloat in [319, 280] {
            let groove = NSBezierPath()
            groove.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: radius, startAngle: 150, endAngle: 278, clockwise: false)
            groove.lineWidth = 15; groove.lineCapStyle = .round
            black.setStroke(); groove.stroke()
        }
        let needle = NSBezierPath()
        needle.move(to: NSPoint(x: 573, y: 585))
        needle.line(to: NSPoint(x: 647, y: 685))
        needle.lineWidth = 28; needle.lineCapStyle = .round
        white.setStroke(); needle.stroke()
        white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 478, y: 478, width: 68, height: 68)).fill()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination + "/icon_\(size)x\(size)\(suffix).png"))
    }
}
