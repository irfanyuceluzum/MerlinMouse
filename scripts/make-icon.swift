// Merlin Mouse uygulama simgesini çizer ve Resources/AppIcon.icns üretir.
// Kullanım (proje kökünde): swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("MerlinMouse.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// 1024×1024 tuval üzerinde çizer; küçük boyutlar ölçeklenerek alınır.
func drawIcon(in ctx: CGContext) {
    let canvas = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    ctx.clear(canvas)

    // macOS simge ızgarası: 824×824 içerik, yumuşak köşe.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    // Zemin gölgesi
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.shadowBlurRadius = 30
    shadow.set()
    color(0x1E2E8A).setFill()
    tilePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Zemin: derin laciverten tasarımdaki maviye
    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()
    NSGradient(colors: [color(0x16205E), color(0x2F5BD3), color(0x5B7CFA)],
               atLocations: [0, 0.62, 1], colorSpace: .sRGB)!
        .draw(in: tile, angle: 90)
    // Üstte ince parlaklık
    NSGradient(colors: [NSColor.white.withAlphaComponent(0), NSColor.white.withAlphaComponent(0.16)])!
        .draw(in: NSRect(x: tile.minX, y: tile.midY + 120, width: tile.width, height: tile.height / 2 - 120), angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    // Magic Mouse (üstten): yaklaşık 1:2 oranında yuvarlak gövde
    let mouse = CGRect(x: 512 - 165, y: 512 - 300, width: 330, height: 600)
    let mousePath = NSBezierPath(roundedRect: mouse, xRadius: 160, yRadius: 175)
    NSGraphicsContext.saveGraphicsState()
    let mouseShadow = NSShadow()
    mouseShadow.shadowColor = NSColor.black.withAlphaComponent(0.40)
    mouseShadow.shadowOffset = NSSize(width: 0, height: -18)
    mouseShadow.shadowBlurRadius = 36
    mouseShadow.set()
    NSColor.white.setFill()
    mousePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    mousePath.addClip()
    NSGradient(colors: [color(0xFFFFFF), color(0xF1F3F8), color(0xDCE1EC)],
               atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
        .draw(in: mouse, angle: -70)

    // Orta tuş bölgesi: ön yarıda parlayan şerit
    let zone = CGRect(x: 512 - 46, y: mouse.maxY - 300, width: 92, height: 236)
    let zonePath = NSBezierPath(roundedRect: zone, xRadius: 46, yRadius: 46)
    let glow = NSShadow()
    glow.shadowColor = color(0x4767EE, 0.85)
    glow.shadowOffset = .zero
    glow.shadowBlurRadius = 40
    NSGraphicsContext.saveGraphicsState()
    glow.set()
    NSGradient(colors: [color(0x7FA0FF), color(0x2F5BD3)])!.draw(in: zonePath, angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    // Ön ve arka yarıyı ayıran ince çizgi
    color(0xC9CFDD).setStroke()
    let seam = NSBezierPath()
    seam.move(to: NSPoint(x: mouse.minX, y: mouse.midY - 10))
    seam.line(to: NSPoint(x: mouse.maxX, y: mouse.midY - 10))
    seam.lineWidth = 3
    seam.setLineDash([6, 10], count: 2, phase: 0)
    seam.stroke()
    NSGraphicsContext.restoreGraphicsState()

    // İnce kenar
    color(0xFFFFFF, 0.9).setStroke()
    mousePath.lineWidth = 3
    mousePath.stroke()

    // Merlin yıldızı: dört kollu ışıltı
    func sparkle(center: NSPoint, radius: CGFloat, alpha: CGFloat) {
        let p = NSBezierPath()
        let inner = radius * 0.22
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4 + .pi / 2
            let r = i % 2 == 0 ? radius : inner
            let pt = NSPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            i == 0 ? p.move(to: pt) : p.line(to: pt)
        }
        p.close()
        NSGraphicsContext.saveGraphicsState()
        let s = NSShadow()
        s.shadowColor = color(0xBFD0FF, alpha)
        s.shadowBlurRadius = radius * 0.6
        s.set()
        NSColor.white.withAlphaComponent(alpha).setFill()
        p.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
    sparkle(center: NSPoint(x: 735, y: 760), radius: 78, alpha: 1)
    sparkle(center: NSPoint(x: 818, y: 640), radius: 34, alpha: 0.85)
    sparkle(center: NSPoint(x: 268, y: 330), radius: 26, alpha: 0.6)
}

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext
    cg.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawIcon(in: cg)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try render(size: 1024).write(to: root.appendingPathComponent("Resources/AppIcon-1024.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Hazır: Resources/AppIcon.icns" : "iconutil hata: \(iconutil.terminationStatus)")
