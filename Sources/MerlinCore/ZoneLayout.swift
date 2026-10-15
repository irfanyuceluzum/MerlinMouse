import Foundation

/// Fare yüzeyinin bölge düzeni: x 0 sol → 1 sağ; y bu sınırın altındaysa arka bölge.
public struct ZoneLayout: Codable, Equatable {
    /// Sol | orta sınırı.
    public var leftEdge: Double
    /// Orta | sağ sınırı.
    public var rightEdge: Double
    /// Ön | arka sınırı; y bu değerin altındaysa arka (logo) bölgesidir.
    public var frontLimit: Double
    /// Orta bölgenin üst kenarı (y: 0 arka → 1 ön uç). Orta bölge `frontLimit ≤ y ≤ centerTop` aralığındadır;
    /// üstünde kalan ön uç, orta sütunun ortasından ikiye bölünüp sol ve sağ bölgeye katılır.
    public var centerTop: Double

    public static let minZoneWidth = 0.10
    /// Orta bölgenin en az yüksekliği.
    public static let minCenterHeight = 0.15
    public static let frontLimitRange: ClosedRange<Double> = 0.2...0.6

    public init(leftEdge: Double, rightEdge: Double, frontLimit: Double, centerTop: Double = 1.0) {
        self.leftEdge = leftEdge
        self.rightEdge = rightEdge
        self.frontLimit = frontLimit
        self.centerTop = centerTop
    }

    private enum CodingKeys: String, CodingKey { case leftEdge, rightEdge, frontLimit, centerTop }

    /// Eski kayıtlarda `centerTop` yoktur; 1.0 (bugünkü davranış) varsayılır.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        leftEdge = try c.decode(Double.self, forKey: .leftEdge)
        rightEdge = try c.decode(Double.self, forKey: .rightEdge)
        frontLimit = try c.decode(Double.self, forKey: .frontLimit)
        centerTop = try c.decodeIfPresent(Double.self, forKey: .centerTop) ?? 1.0
    }

    /// Ortada `width` genişliğinde orta bölge, iki yanda eşit sol/sağ bölge.
    public static func symmetric(width: Double, frontLimit: Double = 0.4) -> ZoneLayout {
        ZoneLayout(leftEdge: 0.5 - width / 2, rightEdge: 0.5 + width / 2, frontLimit: frontLimit, centerTop: 1.0)
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
        let top = min(max(centerTop, front + ZoneLayout.minCenterHeight), 1.0)
        return ZoneLayout(leftEdge: left, rightEdge: right, frontLimit: front, centerTop: top)
    }

    /// Sürüklenebilir sınırlar.
    public enum ZoneEdge: Equatable { case left, right, front, centerTop }

    /// Verilen sınırı `value`'ya taşır; komşu bölgeyi en az `minZoneWidth` bırakır, sonucu `clamped()` döner.
    public func moving(_ edge: ZoneEdge, to value: Double) -> ZoneLayout {
        let m = ZoneLayout.minZoneWidth
        var l = self
        switch edge {
        case .left: l.leftEdge = min(max(value, m), rightEdge - m)
        case .right: l.rightEdge = min(max(value, leftEdge + m), 1 - m)
        case .front: l.frontLimit = value
        case .centerTop: l.centerTop = value
        }
        return l.clamped()
    }

    public var leftWidth: Double { leftEdge }
    public var centerWidth: Double { rightEdge - leftEdge }
    public var rightWidth: Double { 1 - rightEdge }
    public var centerHeight: Double { centerTop - frontLimit }
}
