// Renders the Mac Cleaner app icon at 1024px.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// macOS icon grid: 824pt squircle centred in a 1024 canvas.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 186, yRadius: 186)

// Drop shadow under the tile.
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = color(0x0B1A3A, 0.45)
shadow.shadowBlurRadius = 28
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.set()
color(0x1E3A8A).setFill()
tilePath.fill()
NSGraphicsContext.restoreGraphicsState()

// Background: deep indigo to bright teal, diagonal.
NSGraphicsContext.saveGraphicsState()
tilePath.addClip()
NSGradient(colors: [color(0x2B2F9E), color(0x2563EB), color(0x14C8C8)], atLocations: [0, 0.55, 1],
           colorSpace: .sRGB)!.draw(in: tile, angle: 60)

// Soft glow behind the gauge.
let glowCenter = CGPoint(x: 512, y: 500)
NSGradient(colors: [color(0xFFFFFF, 0.28), color(0xFFFFFF, 0)])!
    .draw(fromCenter: glowCenter, radius: 0, toCenter: glowCenter, radius: 360, options: [])

// Top sheen.
let sheen = NSBezierPath(ovalIn: NSRect(x: 40, y: 600, width: 944, height: 520))
color(0xFFFFFF, 0.08).setFill()
sheen.fill()
NSGraphicsContext.restoreGraphicsState()

// Disk gauge: faint full track + bright "freed space" arc with round caps.
let center = CGPoint(x: 512, y: 500)
let radius: CGFloat = 270
ctx.setLineCap(.round)
ctx.setLineWidth(62)
ctx.setStrokeColor(color(0xFFFFFF, 0.22).cgColor)
ctx.addArc(center: center, radius: radius, startAngle: .pi * 1.25, endAngle: -.pi * 0.25, clockwise: true)
ctx.strokePath()

ctx.saveGState()
ctx.addArc(center: center, radius: radius, startAngle: .pi * 1.25, endAngle: .pi * 0.15, clockwise: true)
ctx.replacePathWithStrokedPath()
ctx.clip()
let arcGradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
    colors: [color(0xFFFFFF).cgColor, color(0xB8FFF4).cgColor] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(arcGradient, start: CGPoint(x: 200, y: 300), end: CGPoint(x: 800, y: 800), options: [])
ctx.restoreGState()

// Sparkles in the middle of the gauge.
let config = NSImage.SymbolConfiguration(pointSize: 300, weight: .semibold)
    .applying(.init(paletteColors: [.white]))
if let sparkles = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let s = sparkles.size
    let scale = 330 / max(s.width, s.height)
    let rect = NSRect(
        x: center.x - s.width * scale / 2, y: center.y - s.height * scale / 2,
        width: s.width * scale, height: s.height * scale)
    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = color(0x0B1A3A, 0.35)
    glow.shadowBlurRadius = 18
    glow.shadowOffset = NSSize(width: 0, height: -6)
    glow.set()
    sparkles.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
