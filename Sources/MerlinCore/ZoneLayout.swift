import Foundation

/// Fare yüzeyinin bölge düzeni: x 0 sol → 1 sağ; y bu sınırın altındaysa arka bölge.
public struct ZoneLayout: Codable, Equatable {
    /// Sol | orta sınırı.
    public var leftEdge: Double
    /// Orta | sağ sınırı.
    public var rightEdge: Double
    /// Ön | arka sınırı; y bu değerin altındaysa arka (logo) bölgesidir.
    public var frontLimit: Double

    public static let minZoneWidth = 0.10
    public static let frontLimitRange: ClosedRange<Double> = 0.2...0.6

    public init(leftEdge: Double, rightEdge: Double, frontLimit: Double) {
        self.leftEdge = leftEdge
        self.rightEdge = rightEdge
        self.frontLimit = frontLimit
    }

    /// Ortada `width` genişliğinde orta bölge, iki yanda eşit sol/sağ bölge.
    public static func symmetric(width: Double, frontLimit: Double = 0.4) -> ZoneLayout {
        ZoneLayout(leftEdge: 0.5 - width / 2, rightEdge: 0.5 + width / 2, frontLimit: frontLimit)
    }

    public static let standard = ZoneLayout.symmetric(width: 0.30)

    /// Eski tek "orta genişlik" ayarından düzen üretir.
    public static func fromLegacy(zoneWidth: Double) -> ZoneLayout {
        symmetric(width: zoneWidth).clamped()
    }

    /// Her bölge en az `minZoneWidth` genişliğinde; `frontLimit` 0.2…0.6.
    public func clamped() -> ZoneLayout {
        let m = ZoneLayout.minZoneWidth
        let left = min(max(leftEdge, m), 1 - 2 * m)
        let right = min(max(rightEdge, left + m), 1 - m)
        let front = min(max(frontLimit, ZoneLayout.frontLimitRange.lowerBound), ZoneLayout.frontLimitRange.upperBound)
        return ZoneLayout(leftEdge: left, rightEdge: right, frontLimit: front)
    }

    /// Sürüklenebilir sınırlar.
    public enum ZoneEdge: Equatable { case left, right, front }

    /// Verilen sınırı `value`'ya taşır; komşu bölgeyi en az `minZoneWidth` bırakır, sonucu `clamped()` döner.
    public func moving(_ edge: ZoneEdge, to value: Double) -> ZoneLayout {
        let m = ZoneLayout.minZoneWidth
        var l = self
        switch edge {
        case .left: l.leftEdge = min(max(value, m), rightEdge - m)
        case .right: l.rightEdge = min(max(value, leftEdge + m), 1 - m)
        case .front: l.frontLimit = value
        }
        return l.clamped()
    }

    public var leftWidth: Double { leftEdge }
    public var centerWidth: Double { rightEdge - leftEdge }
    public var rightWidth: Double { 1 - rightEdge }
}
