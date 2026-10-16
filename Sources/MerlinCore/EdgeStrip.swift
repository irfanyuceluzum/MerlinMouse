import Foundation

/// Bölgeler haritasının altındaki ölçüler (tam sayı yüzde).
public struct ZoneReadout: Equatable {
    public let left: Int, center: Int, right: Int
    /// Arka (logo) bölgesinin yüksekliği (= ön/arka sınırı) ve orta bölgenin yüksekliği.
    public let rear: Int, centerHeight: Int
    public let edgeWidth: Int, edgeBottom: Int, edgeTop: Int

    public init(layout: ZoneLayout, edgeWidth: Double, edgeBounds: EdgeStripBounds) {
        func pct(_ v: Double) -> Int { Int((v * 100).rounded()) }
        left = pct(layout.leftWidth)
        center = pct(layout.centerWidth)
        right = pct(layout.rightWidth)
        rear = pct(layout.frontLimit)
        centerHeight = pct(layout.centerHeight)
        self.edgeWidth = pct(edgeWidth)
        edgeBottom = pct(edgeBounds.bottom)
        edgeTop = pct(edgeBounds.top)
    }
}

/// Kenar şeridinin dikey aralığı (y: 0 arka → 1 ön). İki kenar aynı aralığı paylaşır.
public struct EdgeStripBounds: Codable, Equatable {
    public var bottom: Double
    public var top: Double

    public static let defaultBottom = 0.15
    public static let defaultTop = 0.60
    /// Üst ucun en fazla gidebileceği yer; ön uçtaki tıklama alanı şeritten uzak kalır.
    public static let maxTop = 0.85
    /// Şeridin en az yüksekliği.
    public static let minHeight = 0.15

    public static let standard = EdgeStripBounds(bottom: defaultBottom, top: defaultTop)

    public init(bottom: Double, top: Double) {
        self.bottom = bottom
        self.top = top
    }

    /// 0 ≤ bottom, top ≤ 0.85, top − bottom ≥ 0.15.
    public func clamped() -> EdgeStripBounds {
        let t = min(max(top, Self.minHeight), Self.maxTop)
        let b = min(max(bottom, 0), t - Self.minHeight)
        return EdgeStripBounds(bottom: b, top: t)
    }

    /// Sürüklenebilir uçlar.
    public enum End: Equatable { case bottom, top }

    /// Verilen ucu `value`'ya taşır; öbür uç yerinde kalır, en az yükseklik korunur.
    public func moving(_ end: End, to value: Double) -> EdgeStripBounds {
        let c = clamped()
        switch end {
        case .top:
            return EdgeStripBounds(bottom: c.bottom, top: min(max(value, c.bottom + Self.minHeight), Self.maxTop))
        case .bottom:
            return EdgeStripBounds(bottom: min(max(value, 0), c.top - Self.minHeight), top: c.top)
        }
    }

    public func contains(y: Float) -> Bool {
        let v = Double(y)
        return v >= bottom && v <= top
    }

    public var height: Double { top - bottom }
}

/// Kenar şeridi dikdörtgenleriyle ilgili saf yardımcılar.
public enum EdgeStrip {
    /// Şerit genişliğini izinli aralığa (`EdgeSlideRecognizer.edgeWidthRange`) sıkıştırır.
    public static func clampedWidth(_ width: Double) -> Double {
        let r = EdgeSlideRecognizer.edgeWidthRange
        return min(max(width, r.lowerBound), r.upperBound)
    }

    /// Genişlik tutamacı (şeridin iç kenarı) yüzeyin `x` konumuna (0 sol → 1 sağ) sürüklenince şerit genişliği;
    /// sol şeritte x, sağ şeritte 1 − x. İki kenar aynı genişliği paylaşır.
    public static func width(forHandleAt x: Double, side: EdgeSide) -> Double {
        clampedWidth(side == .left ? x : 1 - x)
    }

    /// x konumunun kenar sütunu (y'ye bakmadan); şeritte değilse nil.
    public static func side(forX x: Float, width: Double) -> EdgeSide? {
        let v = Double(x)
        if v <= width { return .left }
        if v >= 1 - width { return .right }
        return nil
    }

    /// Nokta bir şerit dikdörtgeninde mi (x sütunda ve y aralıkta); öyleyse kenarı.
    public static func side(of p: TouchPoint, width: Double, bounds: EdgeStripBounds) -> EdgeSide? {
        guard bounds.contains(y: p.y) else { return nil }
        return side(forX: p.x, width: width)
    }

    /// Basma çözümlemesi için: etkin kenarların şerit dikdörtgenindeki dokunuşları çıkarır.
    /// Etkin kenar yoksa liste olduğu gibi döner.
    public static func excluding(points: [TouchPoint], sides: Set<EdgeSide>, width: Double,
                                 bounds: EdgeStripBounds) -> [TouchPoint] {
        guard !sides.isEmpty else { return points }
        return points.filter { p in
            guard let s = side(of: p, width: width, bounds: bounds) else { return true }
            return !sides.contains(s)
        }
    }
}
