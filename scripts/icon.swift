import AppKit

let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let factor = CGFloat(pixels) / 1024
        let transform = NSAffineTransform()
        transform.scale(by: factor)
        transform.concat()
        let background = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 200, yRadius: 200)
        NSColor(calibratedRed: 0.08, green: 0.17, blue: 0.20, alpha: 1).setFill()
        background.fill()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 512, y: 675))
        line.line(to: NSPoint(x: 512, y: 500))
        line.move(to: NSPoint(x: 320, y: 350))
        line.line(to: NSPoint(x: 320, y: 500))
        line.line(to: NSPoint(x: 704, y: 500))
        line.line(to: NSPoint(x: 704, y: 350))
        line.lineWidth = 48
        line.lineCapStyle = .round
        line.lineJoinStyle = .round
        NSColor(calibratedRed: 0.39, green: 0.88, blue: 0.69, alpha: 1).setStroke()
        line.stroke()
        for point in [NSPoint(x: 512, y: 692), NSPoint(x: 320, y: 330), NSPoint(x: 704, y: 330)] {
            let rect = NSRect(x: point.x - 84, y: point.y - 65, width: 168, height: 130)
            NSColor(calibratedRed: 0.12, green: 0.28, blue: 0.29, alpha: 1).setFill()
            let node = NSBezierPath(roundedRect: rect, xRadius: 30, yRadius: 30)
            node.fill()
            NSColor(calibratedRed: 0.64, green: 1, blue: 0.84, alpha: 1).setStroke()
            node.lineWidth = 16
            node.stroke()
            let dot = NSBezierPath(ovalIn: NSRect(x: point.x - 14, y: point.y - 14, width: 28, height: 28))
            NSColor.white.setFill()
            dot.fill()
        }
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let data = bitmap.representation(using: .png, properties: [:])!
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try data.write(to: URL(fileURLWithPath: output).appendingPathComponent(name))
    }
}
