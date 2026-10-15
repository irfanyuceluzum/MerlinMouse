import Foundation

extension Zone {
    /// Bir parmağın konumunu (x: 0 sol → 1 sağ, y: 0 arka → 1 ön) bölgeye çevirir.
    public static func classify(x: Float, y: Float, layout: ZoneLayout) -> Zone {
        if Double(y) < layout.frontLimit { return .rear }
        let dx = Double(x)
        if dx < layout.leftEdge { return .left }
        // Orta bölgenin üstündeki ön uç: orta sütunun sol yarısı sola, sağ yarısı sağa katılır.
        if Double(y) > layout.centerTop, dx <= layout.rightEdge {
            return dx < (layout.leftEdge + layout.rightEdge) / 2 ? .left : .right
        }
        return dx <= layout.rightEdge ? .center : .right
    }
}

/// Basış anındaki parmaklardan eşleştirilecek tetik adaylarını üretir.
public enum PressResolver {
    /// Sıra öncelik sırasıdır: önce Fn, sonra parmak sayısına göre basış.
    /// Yalnız öndeki parmaklar (y >= frontLimit) sayılır; arka bölge basış için aday değildir.
    public static func candidates(fingers: [TouchPoint], fnDown: Bool, layout: ZoneLayout) -> [Trigger] {
        var out: [Trigger] = []
        if fnDown {
            out.append(Trigger(kind: .press, fingers: 0, modifier: .fn))
        }
        let front = fingers.filter { Double($0.y) >= layout.frontLimit }
        let n = front.count
        if n >= 2 {
            out.append(Trigger(kind: .press, fingers: min(n, 4)))
        } else if n == 1 {
            let zone = Zone.classify(x: front[0].x, y: front[0].y, layout: layout)
            // Tek parmakla sol bölge normal sol tıklamadır; aday yok.
            if zone != .left && zone != .rear {
                out.append(Trigger(kind: .press, fingers: 1, zone: zone))
            }
        }
        return out
    }
}
