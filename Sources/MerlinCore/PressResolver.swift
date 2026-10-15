import Foundation

extension Zone {
    /// Tek parmağın x konumunu (0…1) bölgeye çevirir; `zoneWidth` orta bölgenin oranıdır.
    public static func classify(x: Float, zoneWidth: Double) -> Zone {
        let half = zoneWidth / 2
        let dx = Double(x) - 0.5
        if abs(dx) <= half { return .center }
        return dx < 0 ? .left : .right
    }
}

/// Basış anındaki parmaklardan eşleştirilecek tetik adaylarını üretir.
public enum PressResolver {
    /// Sıra öncelik sırasıdır: önce Fn, sonra parmak sayısına göre basış.
    public static func candidates(frontFingerXs: [Float], fnDown: Bool, zoneWidth: Double) -> [Trigger] {
        var out: [Trigger] = []
        if fnDown {
            out.append(Trigger(kind: .press, fingers: 0, modifier: .fn))
        }
        let n = frontFingerXs.count
        if n >= 2 {
            out.append(Trigger(kind: .press, fingers: min(n, 4)))
        } else if n == 1 {
            let zone = Zone.classify(x: frontFingerXs[0], zoneWidth: zoneWidth)
            // Tek parmakla sol bölge normal sol tıklamadır; aday yok.
            if zone != .left {
                out.append(Trigger(kind: .press, fingers: 1, zone: zone))
            }
        }
        return out
    }
}
