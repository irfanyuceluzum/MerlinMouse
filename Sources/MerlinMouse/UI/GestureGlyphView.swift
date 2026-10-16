import SwiftUI
import MerlinCore

/// Tetiği anlatan küçük simge (28×36 pt); çizim tarifi `GestureGlyph`'ten gelir. Magic Mouse'ta fare gövdesi,
/// trackpad'de ortada yatay yuvarlatılmış dikdörtgen gövde (26×18, köşe 4) çizilir.
struct GestureGlyphView: View {
    let trigger: Trigger
    var device: InputDeviceKind = .magicMouse

    var body: some View {
        let g = GestureGlyph(trigger: trigger, device: device)
        let w = CGFloat(GestureGlyph.width), h = CGFloat(GestureGlyph.height)
        let dot = CGFloat(GestureGlyph.dotDiameter)
        return ZStack {
            if device == .trackpad {
                trackpadBody
            } else {
                mouseBody(g)
            }

            ForEach(Array(g.rings.enumerated()), id: \.offset) { _, r in
                Circle().stroke(MM.accent.opacity(0.45), lineWidth: 1)
                    .frame(width: CGFloat(r.radius * 2), height: CGFloat(r.radius * 2))
                    .position(x: CGFloat(r.x), y: CGFloat(r.y))
            }
            ForEach(Array(g.dots.enumerated()), id: \.offset) { _, d in
                Group {
                    if d.hollow {
                        Circle().strokeBorder(MM.accent, lineWidth: 1.5)
                    } else {
                        Circle().fill(MM.accent)
                    }
                }
                .frame(width: dot, height: dot)
                .position(x: CGFloat(d.x), y: CGFloat(d.y))
            }
            ForEach(Array(g.labels.enumerated()), id: \.offset) { _, l in
                Text(verbatim: l.text)
                    .font(.system(size: CGFloat(l.size), weight: .semibold))
                    .foregroundStyle(MM.accent)
                    .fixedSize()
                    .position(x: CGFloat(l.x), y: CGFloat(l.y))
            }
        }
        .frame(width: w, height: h)
        .accessibilityHidden(true)
    }

    private var trackpadBody: some View {
        let bw = CGFloat(GestureGlyph.trackpadBodyWidth), bh = CGFloat(GestureGlyph.trackpadBodyHeight)
        let bx = CGFloat(GestureGlyph.trackpadBodyX), by = CGFloat(GestureGlyph.trackpadBodyY)
        let shape = RoundedRectangle(cornerRadius: CGFloat(GestureGlyph.trackpadBodyRadius), style: .continuous)
        return shape.fill(MM.card)
            .overlay(shape.strokeBorder(MM.text2, lineWidth: CGFloat(GestureGlyph.bodyStroke)))
            .frame(width: bw, height: bh)
            .position(x: bx + bw / 2, y: by + bh / 2)
    }

    private func mouseBody(_ g: GestureGlyph) -> some View {
        let bw = CGFloat(GestureGlyph.bodyWidth), bh = CGFloat(GestureGlyph.bodyHeight)
        let bx = CGFloat(GestureGlyph.bodyX), by = CGFloat(GestureGlyph.bodyY)
        let shell = UnevenRoundedRectangle(topLeadingRadius: CGFloat(GestureGlyph.bodyTopRadius),
                                           bottomLeadingRadius: CGFloat(GestureGlyph.bodyBottomRadius),
                                           bottomTrailingRadius: CGFloat(GestureGlyph.bodyBottomRadius),
                                           topTrailingRadius: CGFloat(GestureGlyph.bodyTopRadius),
                                           style: .continuous)
        let rearHeight = by + bh - CGFloat(GestureGlyph.rearTop)
        return ZStack(alignment: .bottom) {
            shell.fill(MM.card)
            if g.rear {
                Rectangle().fill(MM.bttDot.opacity(0.22)).frame(height: rearHeight)
            }
            if let edge = g.edge {
                // Kenar kaydırma şeridi: gövde boyunca, gövdeye kırpılmış yeşil şerit.
                Rectangle().fill(MM.okDot.opacity(0.22))
                    .frame(width: CGFloat(GestureGlyph.edgeStripeWidth))
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: edge == .left ? .leading : .trailing)
            }
        }
        .clipShape(shell)
        .overlay(shell.strokeBorder(MM.text2, lineWidth: CGFloat(GestureGlyph.bodyStroke)))
        .frame(width: bw, height: bh)
        .position(x: bx + bw / 2, y: by + bh / 2)
    }
}
