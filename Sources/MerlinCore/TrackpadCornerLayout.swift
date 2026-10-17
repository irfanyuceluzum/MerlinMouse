import Foundation

/// Trackpad'in dört köşesinin ortak boyutu (yüzeyin oranı olarak). Yalnız tek parmakla fiziksel basmada kullanılır.
///
/// Koordinatlar MultitouchSupport'un normalleştirilmiş konumudur: x 0 sol → 1 sağ, y 0 → 1. y'nin 0 ucu
/// kullanıcıya yakın kenardır (trackpad'de "alt"): aynı veri Magic Mouse'ta y 0 = avuç / arka (kullanıcıya yakın),
/// 1 = uç verir ve bu projede bölge haritası (`flipY` varsayılanı kapalı) gerçek fareyle buna göre doğrulanmıştır.
public struct TrackpadCornerLayout: Codable, Equatable {
    public var width: Double
    public var height: Double

    public static let defaultWidth = 0.18
    public static let defaultHeight = 0.22
    public static let range: ClosedRange<Double> = 0.08...0.35
    public static let standard = TrackpadCornerLayout(width: defaultWidth, height: defaultHeight)

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    /// Her iki ölçü `range` içine çekilir (sayı değilse varsayılan).
    public func clamped() -> TrackpadCornerLayout {
        func clamp(_ v: Double, _ fallback: Double) -> Double {
            guard v.isFinite else { return fallback }
            return min(max(v, Self.range.lowerBound), Self.range.upperBound)
        }
        return TrackpadCornerLayout(width: clamp(width, Self.defaultWidth), height: clamp(height, Self.defaultHeight))
    }

    /// Noktanın köşesi; köşe dışındaysa nil. x: 0 sol → 1 sağ; y: 0 alt (kullanıcıya yakın) → 1 üst.
    public func classify(x: Float, y: Float) -> Zone? {
        let c = clamped()
        let dx = Double(x), dy = Double(y)
        let left = dx < c.width, right = dx > 1 - c.width
        let bottom = dy < c.height, top = dy > 1 - c.height
        switch (left, right, bottom, top) {
        case (true, _, true, _): return .cornerBottomLeft
        case (_, true, true, _): return .cornerBottomRight
        case (true, _, _, true): return .cornerTopLeft
        case (_, true, _, true): return .cornerTopRight
        default: return nil
        }
    }
}
