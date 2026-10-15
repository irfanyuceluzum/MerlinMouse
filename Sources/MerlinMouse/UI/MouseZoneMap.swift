import SwiftUI
import AppKit

/// Magic Mouse üstten görünüm: orta bölge, macOS ikincil tıklama bölgesi ve canlı parmak noktaları.
/// Görsel verilirse onu çizer; yoksa kodla çizilmiş gerçekçi bir fare gösterir.
struct MouseZoneMap: View {
    var touches: [Touch] = []
    /// Orta bölgenin genişlik oranı; 0 ise orta bölge çizilmez.
    var zoneWidth: Double
    var flipped: Bool = false
    var image: NSImage? = nil
    /// TwoButton ise sağ bölge taralı turuncu gösterilir.
    var secondaryRightZone: Bool = false
    var width: CGFloat = 162
    /// Çok küçük boyutlarda (menü paneli) etiketler gizlenir.
    var showLabels: Bool = true

    // Tasarımın 388×720 koordinat sistemi.
    private static let vbW: CGFloat = 388
    private static let vbH: CGFloat = 720
    private static let body = CGRect(x: 27, y: 13, width: 335, height: 667)

    private var height: CGFloat { width * Self.vbH / Self.vbW }

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Canvas { ctx, size in drawMouse(&ctx, size: size) }
            }
            Canvas { ctx, size in drawOverlay(&ctx, size: size) }
        }
        .frame(width: width, height: height)
        .accessibilityElement()
        .accessibilityLabel("Magic Mouse dokunma haritası")
    }

    private func bodyPath(_ s: CGFloat, inset: CGFloat = 0) -> Path {
        let b = Self.body.insetBy(dx: inset, dy: inset)
        return Path(roundedRect: CGRect(x: b.minX * s, y: b.minY * s, width: b.width * s, height: b.height * s),
                    cornerSize: CGSize(width: 135 * s, height: 110 * s), style: .continuous)
    }

    // MARK: Kodla çizilmiş fare

    private func drawMouse(_ ctx: inout GraphicsContext, size: CGSize) {
        let s = size.width / Self.vbW
        let outer = bodyPath(s)
        // Yumuşak gölge
        var shadowCtx = ctx
        shadowCtx.addFilter(.shadow(color: .black.opacity(0.22), radius: 10 * s, x: 0, y: 8 * s))
        shadowCtx.fill(outer, with: .color(Color(white: 0.80)))
        // Açık gri kenar şeridi
        ctx.fill(outer, with: .linearGradient(
            Gradient(colors: [Color(white: 0.90), Color(white: 0.76)]),
            startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: size.width, y: size.height)))
        // Beyaz / gümüş yüzey
        let surface = bodyPath(s, inset: 9)
        ctx.fill(surface, with: .linearGradient(
            Gradient(colors: [Color(white: 1.0), Color(white: 0.955), Color(white: 0.89)]),
            startPoint: CGPoint(x: size.width * 0.85, y: 0), endPoint: CGPoint(x: size.width * 0.15, y: size.height)))
        ctx.stroke(surface, with: .color(Color(white: 0.72).opacity(0.7)), lineWidth: max(0.6, 1.4 * s))
        // Sağ üstte parlaklık
        var glow = ctx
        glow.clip(to: surface)
        glow.fill(Path(ellipseIn: CGRect(x: 170 * s, y: -120 * s, width: 330 * s, height: 360 * s)),
                  with: .radialGradient(Gradient(colors: [Color.white.opacity(0.95), Color.white.opacity(0)]),
                                        center: CGPoint(x: 330 * s, y: 60 * s), startRadius: 0, endRadius: 200 * s))
    }

    // MARK: Bölgeler ve parmaklar

    private func drawOverlay(_ ctx: inout GraphicsContext, size: CGSize) {
        let s = size.width / Self.vbW
        let b = Self.body
        let frontBottom = b.minY + b.height * CGFloat(1 - TouchMonitor.frontLimit)
        let center = zoneWidth > 0 ? b.width * CGFloat(zoneWidth) : 0
        let cx0 = b.midX - center / 2, cx1 = b.midX + center / 2

        var inner = ctx
        inner.clip(to: bodyPath(s))

        if center > 0 {
            inner.fill(Path(CGRect(x: cx0 * s, y: b.minY * s, width: center * s, height: (frontBottom - b.minY) * s)),
                       with: .color(MM.accent.opacity(0.16)))
        }
        if secondaryRightZone {
            let x0 = (center > 0 ? cx1 : b.midX + b.width * 0.15) // sağ bölge orta bölgenin bittiği yerden başlar
            let rect = CGRect(x: x0 * s, y: b.minY * s, width: (b.maxX - x0) * s, height: (frontBottom - b.minY) * s)
            var hatch = inner
            hatch.clip(to: Path(rect))
            hatch.fill(Path(rect), with: .color(Color(red: 224 / 255, green: 123 / 255, blue: 18 / 255).opacity(0.10)))
            var lines = Path()
            var x = rect.minX - rect.height
            while x < rect.maxX {
                lines.move(to: CGPoint(x: x, y: rect.maxY))
                lines.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
                x += 14 * s * 1.41
            }
            hatch.stroke(lines, with: .color(Color(red: 224 / 255, green: 123 / 255, blue: 18 / 255).opacity(0.45)),
                         lineWidth: 5 * s)
        }
        let dash = StrokeStyle(lineWidth: max(1, 3 * s), dash: [10 * s, 7 * s])
        if center > 0 {
            for x in [cx0, cx1] {
                var p = Path()
                p.move(to: CGPoint(x: x * s, y: b.minY * s))
                p.addLine(to: CGPoint(x: x * s, y: frontBottom * s))
                inner.stroke(p, with: .color(MM.accent), style: dash)
            }
        }
        var sep = Path()
        sep.move(to: CGPoint(x: 20 * s, y: frontBottom * s))
        sep.addLine(to: CGPoint(x: 370 * s, y: frontBottom * s))
        inner.stroke(sep, with: .color(Color(red: 0.557, green: 0.557, blue: 0.576)),
                     style: StrokeStyle(lineWidth: max(1, 2 * s), dash: [4 * s, 9 * s]))

        // Etiketler: fare yüzeyi hep açık renk olduğundan sabit koyu yazı.
        let labelY = 130 * s
        if showLabels {
        let leftX = (b.minX + (center > 0 ? cx0 : b.midX - 40) ) / 2 * s
        ctx.draw(Text("Sol").font(.system(size: 30 * s)).foregroundColor(Color(red: 0x48 / 255, green: 0x48 / 255, blue: 0x4D / 255)),
                 at: CGPoint(x: leftX, y: labelY))
        if center > 0 {
            ctx.draw(Text("Orta").font(.system(size: 30 * s, weight: .semibold))
                        .foregroundColor(Color(red: 0x24 / 255, green: 0x49 / 255, blue: 0xB5 / 255)),
                     at: CGPoint(x: b.midX * s, y: labelY))
        }
        let rightFrom = center > 0 ? cx1 : b.midX + 40
        ctx.draw(Text("Sağ").font(.system(size: 30 * s)).foregroundColor(Color(red: 0x8F / 255, green: 0x4A / 255, blue: 0)),
                 at: CGPoint(x: (rightFrom + b.maxX) / 2 * s, y: labelY))

        }

        // Canlı parmaklar
        for t in touches {
            let x = (b.minX + CGFloat(t.x) * b.width) * s
            let y = (b.minY + (1 - CGFloat(t.front(flipped: flipped))) * b.height) * s
            let r = CGRect(x: x - 26 * s, y: y - 30 * s, width: 52 * s, height: 60 * s)
            inner.fill(Path(ellipseIn: r), with: .color(MM.accent.opacity(0.15)))
            inner.stroke(Path(ellipseIn: r), with: .color(MM.accent), lineWidth: max(1, 3.5 * s))
        }
    }
}
