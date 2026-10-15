import SwiftUI
import AppKit
import MerlinCore

/// Magic Mouse üstten görünüm: sol/orta/sağ bölge, arka (logo) bölgesi, macOS ikincil tıklama bölgesi ve canlı parmak noktaları.
/// Görsel verilirse onu çizer; yoksa kodla çizilmiş gerçekçi bir fare gösterir.
struct MouseZoneMap: View {
    var touches: [Touch] = []
    /// Bölge düzeni (sol | orta | sağ sınırları ve ön/arka sınırı).
    var layout: ZoneLayout
    /// Doğruysa sınır tutamaçları sürüklenerek `Settings.zoneLayout` güncellenir.
    var editable: Bool = false
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
            if editable { handles }
        }
        .coordinateSpace(name: "zoneMap")
        .frame(width: width, height: height)
        .accessibilityElement()
        .accessibilityLabel(L("Magic Mouse dokunma haritası"))
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

    private static let orange = Color(red: 224 / 255, green: 123 / 255, blue: 18 / 255)

    private func drawOverlay(_ ctx: inout GraphicsContext, size: CGSize) {
        let s = size.width / Self.vbW
        let b = Self.body
        let frontBottom = b.minY + b.height * CGFloat(1 - layout.frontLimit)
        let cx0 = b.minX + b.width * CGFloat(layout.leftEdge)
        let cx1 = b.minX + b.width * CGFloat(layout.rightEdge)
        let ctop = b.minY + b.height * CGFloat(1 - layout.centerTop)
        let midX = (cx0 + cx1) / 2

        var inner = ctx
        inner.clip(to: bodyPath(s))

        if showLabels {
            // Orta bölge
            inner.fill(Path(CGRect(x: cx0 * s, y: ctop * s, width: (cx1 - cx0) * s, height: (frontBottom - ctop) * s)),
                       with: .color(MM.accent.opacity(0.16)))
            // Sağ bölge: ikincil tıklama ise taralı turuncu
            if secondaryRightZone {
                // Sağ sütun + orta bölgenin üstünde kalan sağ yarı.
                var rects = [CGRect(x: cx1 * s, y: b.minY * s, width: (b.maxX - cx1) * s, height: (frontBottom - b.minY) * s)]
                if ctop > b.minY {
                    rects.append(CGRect(x: midX * s, y: b.minY * s, width: (cx1 - midX) * s, height: (ctop - b.minY) * s))
                }
                for rect in rects {
                    var hatch = inner
                    hatch.clip(to: Path(rect))
                    hatch.fill(Path(rect), with: .color(Self.orange.opacity(0.10)))
                    var lines = Path()
                    var x = rect.minX - rect.height
                    while x < rect.maxX {
                        lines.move(to: CGPoint(x: x, y: rect.maxY))
                        lines.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
                        x += 14 * s * 1.41
                    }
                    hatch.stroke(lines, with: .color(Self.orange.opacity(0.45)), lineWidth: 5 * s)
                }
            }
            // Arka (logo) bölgesi
            inner.fill(Path(CGRect(x: b.minX * s, y: frontBottom * s, width: b.width * s, height: (b.maxY - frontBottom) * s)),
                       with: .color(MM.bttDot.opacity(0.12)))

            let dash = StrokeStyle(lineWidth: max(1, 3 * s), dash: [10 * s, 7 * s])
            for x in [cx0, cx1] {
                var p = Path()
                p.move(to: CGPoint(x: x * s, y: ctop * s))
                p.addLine(to: CGPoint(x: x * s, y: frontBottom * s))
                inner.stroke(p, with: .color(MM.accent), style: dash)
            }
            if ctop > b.minY {
                // Orta bölgenin üst kenarı ve üstündeki alanı sola/sağa bölen ince ayırıcı.
                var top = Path()
                top.move(to: CGPoint(x: cx0 * s, y: ctop * s))
                top.addLine(to: CGPoint(x: cx1 * s, y: ctop * s))
                inner.stroke(top, with: .color(MM.accent), style: dash)
                var div = Path()
                div.move(to: CGPoint(x: midX * s, y: b.minY * s))
                div.addLine(to: CGPoint(x: midX * s, y: ctop * s))
                inner.stroke(div, with: .color(Color(red: 0.43, green: 0.43, blue: 0.46).opacity(0.6)),
                             style: StrokeStyle(lineWidth: max(0.8, 1.5 * s), dash: [4 * s, 6 * s]))
            }
            var sep = Path()
            sep.move(to: CGPoint(x: b.minX * s, y: frontBottom * s))
            sep.addLine(to: CGPoint(x: b.maxX * s, y: frontBottom * s))
            inner.stroke(sep, with: .color(Color(red: 0.43, green: 0.43, blue: 0.46)), style: dash)

            // Etiketler: fare yüzeyi hep açık renk olduğundan sabit koyu yazı.
            let labelY = (b.minY + 117) * s
            ctx.draw(Text(L("Sol")).font(.system(size: 30 * s)).foregroundColor(Color(red: 0x48 / 255, green: 0x48 / 255, blue: 0x4D / 255)),
                     at: CGPoint(x: (b.minX + cx0) / 2 * s, y: labelY))
            ctx.draw(Text(L("Orta")).font(.system(size: 30 * s, weight: .semibold))
                        .foregroundColor(Color(red: 0x24 / 255, green: 0x49 / 255, blue: 0xB5 / 255)),
                     at: CGPoint(x: midX * s, y: max(labelY, (ctop + 40) * s)))
            ctx.draw(Text(L("Sağ")).font(.system(size: 30 * s)).foregroundColor(Color(red: 0x8F / 255, green: 0x4A / 255, blue: 0)),
                     at: CGPoint(x: (cx1 + b.maxX) / 2 * s, y: labelY))
            ctx.draw(Text(L("Arka")).font(.system(size: 30 * s))
                        .foregroundColor(Color(red: 0x65 / 255, green: 0x34 / 255, blue: 0xA8 / 255)),
                     at: CGPoint(x: b.midX * s, y: (frontBottom + (b.maxY - frontBottom) * 0.45) * s))
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

    // MARK: Sürüklenebilir tutamaçlar

    private var handles: some View {
        let s = width / Self.vbW
        let b = Self.body
        let frontBottom = b.minY + b.height * CGFloat(1 - layout.frontLimit)
        let cx0 = b.minX + b.width * CGFloat(layout.leftEdge)
        let cx1 = b.minX + b.width * CGFloat(layout.rightEdge)
        let midY = (b.minY + (frontBottom - b.minY) * 0.55) * s
        let ctop = b.minY + b.height * CGFloat(1 - layout.centerTop)
        return ZStack {
            handle(vertical: true)
                .gesture(drag { x, _ in Settings.shared.zoneLayout = Settings.shared.zoneLayout.moving(.left, to: Double((x / s - b.minX) / b.width)) })
                .position(x: cx0 * s, y: midY)
            handle(vertical: true)
                .gesture(drag { x, _ in Settings.shared.zoneLayout = Settings.shared.zoneLayout.moving(.right, to: Double((x / s - b.minX) / b.width)) })
                .position(x: cx1 * s, y: midY)
            handle(vertical: false)
                .gesture(drag { _, y in Settings.shared.zoneLayout = Settings.shared.zoneLayout.moving(.front, to: Double(1 - (y / s - b.minY) / b.height)) })
                .position(x: b.midX * s, y: frontBottom * s)
            handle(vertical: false)
                .gesture(drag { _, y in Settings.shared.zoneLayout = Settings.shared.zoneLayout.moving(.centerTop, to: Double(1 - (y / s - b.minY) / b.height)) })
                .position(x: (cx0 + cx1) / 2 * s, y: ctop * s)
        }
        .frame(width: width, height: height)
    }

    private func drag(_ update: @escaping (CGFloat, CGFloat) -> Void) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("zoneMap"))
            .onChanged { update($0.location.x, $0.location.y) }
    }

    private func handle(vertical: Bool) -> some View {
        ZStack {
            Capsule().fill(MM.card)
                .overlay(Capsule().strokeBorder(MM.accent, lineWidth: 1.5))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .frame(width: vertical ? 9 : 36, height: vertical ? 36 : 9)
        }
        .frame(width: vertical ? 24 : 48, height: vertical ? 48 : 24)
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { (vertical ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push() } else { NSCursor.pop() }
        }
        .accessibilityLabel(vertical ? L("Bölge sınırı, sürükleyerek boyutlandır") : L("Ön / arka sınırı, sürükleyerek boyutlandır"))
    }
}
