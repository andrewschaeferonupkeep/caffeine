// Renders the Caffeine app icon and builds Icon/AppIcon.icns.
// Usage: swift Icon/make-icon.swift   (run from the repo root; needs iconutil, part of Xcode CLT)
import AppKit

let canvas: CGFloat = 1024

func renderIcon(size px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: CGFloat(px) / canvas, y: CGFloat(px) / canvas)
    drawIcon(ctx)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func drawIcon(_ ctx: CGContext) {
    // macOS icon grid: 824pt rounded rect centered in 1024, corner radius ~185.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Drop shadow under the tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(0x6B3A1F))
    ctx.fillPath()
    ctx.restoreGState()

    // Warm espresso gradient background.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: [color(0xF2A65A), color(0xC4622D), color(0x7A3B1B)] as CFArray,
                        locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    let cream = color(0xFFF6EA)

    // Soft shadow for the cup group.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x3A1A08, 0.45))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setFillColor(cream)

    // Saucer.
    ctx.addPath(CGPath(roundedRect: CGRect(x: 232, y: 262, width: 560, height: 44),
                       cornerWidth: 22, cornerHeight: 22, transform: nil))
    ctx.fillPath()

    // Cup body: flat top, rounded bottom.
    let body = CGMutablePath()
    body.move(to: CGPoint(x: 302, y: 600))
    body.addLine(to: CGPoint(x: 662, y: 600))
    body.addCurve(to: CGPoint(x: 552, y: 318), control1: CGPoint(x: 662, y: 440), control2: CGPoint(x: 640, y: 318))
    body.addLine(to: CGPoint(x: 412, y: 318))
    body.addCurve(to: CGPoint(x: 302, y: 600), control1: CGPoint(x: 324, y: 318), control2: CGPoint(x: 302, y: 440))
    body.closeSubpath()
    ctx.addPath(body)
    ctx.fillPath()

    // Handle: thick ring on the right side.
    ctx.setStrokeColor(cream)
    ctx.setLineWidth(40)
    ctx.addEllipse(in: CGRect(x: 610, y: 418, width: 140, height: 130))
    ctx.strokePath()

    ctx.endTransparencyLayer()
    ctx.restoreGState()

    // Coffee surface inside the rim.
    ctx.setFillColor(color(0x5A2D12))
    ctx.fillEllipse(in: CGRect(x: 318, y: 574, width: 328, height: 40))

    // Steam: three wavy strokes.
    ctx.setStrokeColor(color(0xFFF6EA, 0.85))
    ctx.setLineWidth(30)
    ctx.setLineCap(.round)
    for (x, top) in [(402.0, 800.0), (482.0, 840.0), (562.0, 800.0)] {
        let s = CGMutablePath()
        let base: CGFloat = 650
        let h = top - base
        s.move(to: CGPoint(x: x, y: base))
        s.addCurve(to: CGPoint(x: x, y: base + h / 2),
                   control1: CGPoint(x: x + 34, y: base + h * 0.17), control2: CGPoint(x: x + 34, y: base + h * 0.33))
        s.addCurve(to: CGPoint(x: x, y: top),
                   control1: CGPoint(x: x - 34, y: base + h * 0.67), control2: CGPoint(x: x - 34, y: base + h * 0.83))
        ctx.addPath(s)
    }
    ctx.strokePath()
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try! renderIcon(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! renderIcon(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try! renderIcon(size: 1024).write(to: URL(fileURLWithPath: "Icon/AppIcon.png"))

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "Icon/AppIcon.icns"]
try! p.run()
p.waitUntilExit()
guard p.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote Icon/AppIcon.icns and Icon/AppIcon.png")
