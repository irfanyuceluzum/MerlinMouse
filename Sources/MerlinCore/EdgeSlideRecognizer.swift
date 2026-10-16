import Foundation

/// Kenar kaydırmanın şeridi.
public enum EdgeSide: String, Hashable, CaseIterable {
    case left, right

    /// Tetikteki bölge karşılığı.
    public var zone: Zone { self == .left ? .leftEdge : .rightEdge }

    public init?(zone: Zone) {
        switch zone {
        case .leftEdge: self = .left
        case .rightEdge: self = .right
        default: return nil
        }
    }
}

/// Kenar kaydırma tanıyıcısının ürettiği olaylar.
public enum EdgeSlideEvent: Equatable {
    case began(EdgeSide)
    /// +1 yukarı (öne doğru, artır), −1 aşağı (azalt); büyük sıçramada art arda birden çok adım gelir.
    case step(Int)
    case ended
}

/// Farenin sol / sağ kenar şeridinde tek parmakla dikey kaydırmayı tanıyan saf durum makinesi.
/// Şerit, kenar sütununun `bounds` dikey aralığındaki dikdörtgendir; x: 0 sol → 1 sağ, y: 0 arka → 1 ön.
/// Arka bölgede şerit dikdörtgenleri dışında kalan avuç dokunuşları hiçbir kurala katılmaz.
public struct EdgeSlideRecognizer {
    /// Şerit genişliğinin izinli aralığı (yüzey genişliğine oranla).
    public static let edgeWidthRange: ClosedRange<Double> = 0.06...0.20
    public static let defaultEdgeWidth: Double = 0.12
    /// Adım boyutunun izinli aralığı (yüzey birimi).
    public static let stepRange: ClosedRange<Double> = 0.025...0.10
    public static let defaultStep: Double = 0.05

    /// Avuç dokunuşlarını ayırmak için ön/arka sınırı (`frontLimit`).
    public var layout: ZoneLayout = .standard
    public var edgeWidth: Double = EdgeSlideRecognizer.defaultEdgeWidth
    /// Şeridin dikey aralığı (iki kenar ortak).
    public var bounds: EdgeStripBounds = .standard
    /// Ataması açık kenarlar; boşsa hiçbir dokunuş aday olmaz.
    public var enabledSides: Set<EdgeSide> = []
    /// Başlamak için gereken dikey değişim; ayrıca |dy| > 3|dx| olmalı.
    public var beginThreshold: Float = 0.04
    /// Etkinken bir adım için gereken dikey değişim.
    public var step: Float = Float(EdgeSlideRecognizer.defaultStep)

    /// Kenar hareketi başladı; yalnız bu sürede gerçek kaydırma düşürülür.
    public private(set) var isActive = false
    /// Şeritte inen tek parmak izleniyor (etkin olsun olmasın); adaylıkta kaydırma geçer.
    public var isCandidate: Bool { candidate != nil }

    private struct Candidate {
        var id: Int32
        var side: EdgeSide
        var origin: (Float, Float)
        var anchor: Float
    }

    private var candidate: Candidate?
    private var surfaceWasEmpty = true
    /// Oturum iptal edildi: tüm parmaklar kalkana kadar yeni aday yok.
    private var blocked = false

    public init() {}

    /// Hassasiyet 0 (az) … 1 (çok) → adım boyutu; hassasiyet arttıkça adım küçülür.
    public static func step(forSensitivity s: Double) -> Double {
        let c = min(max(s, 0), 1)
        return stepRange.upperBound - c * (stepRange.upperBound - stepRange.lowerBound)
    }

    /// Adım boyutu → hassasiyet 0…1.
    public static func sensitivity(forStep step: Double) -> Double {
        let s = min(max(step, stepRange.lowerBound), stepRange.upperBound)
        return (stepRange.upperBound - s) / (stepRange.upperBound - stepRange.lowerBound)
    }

    /// x konumunun kenar sütunu (y'ye bakmadan); sütunda değilse nil.
    public func side(forX x: Float) -> EdgeSide? {
        EdgeStrip.side(forX: x, width: edgeWidth)
    }

    /// Noktanın şerit dikdörtgeni (x sütunda ve y aralıkta); dışındaysa nil.
    public func side(of p: TouchPoint) -> EdgeSide? {
        EdgeStrip.side(of: p, width: edgeWidth, bounds: bounds)
    }

    /// Avuç dokunuşu: arka bölgede ve hiçbir şerit dikdörtgeninde olmayan dokunuş. Parmak sayımında, iptalde
    /// ve "yüzey boş" koşulunda sayılmaz (fare tutulurken avuç çoğu zaman arkaya değer).
    public func isPalm(_ p: TouchPoint) -> Bool {
        Double(p.y) < layout.frontLimit && side(of: p) == nil
    }

    /// Fiziksel tıklama: oturum biter, parmaklar kalkana kadar yeni aday olmaz.
    @discardableResult
    public mutating func noteClick() -> [EdgeSlideEvent] {
        cancel()
    }

    public mutating func process(_ frame: TouchFrame) -> [EdgeSlideEvent] {
        // Avuç dokunuşları yok sayılır; aşağıdaki "tek parmak", "boş yüzey" ve iptal kuralları kalanlara uygulanır.
        // Adayın kendi parmağı şeridin dışına (örn. alt ucun altına) kaysa da avuç sayılmaz.
        let ownID = candidate?.id
        let all = frame.touches.filter { $0.id == ownID || !isPalm($0) }
        let wasEmpty = surfaceWasEmpty
        surfaceWasEmpty = all.isEmpty

        if blocked {
            if all.isEmpty { blocked = false }
            return []
        }

        guard var c = candidate else {
            // Yalnız boş yüzeye tek parmak, etkin bir kenarın şerit dikdörtgenine inerse aday olur.
            if wasEmpty, all.count == 1, let side = side(of: all[0]), enabledSides.contains(side) {
                let p = all[0]
                candidate = Candidate(id: p.id, side: side, origin: (p.x, p.y), anchor: p.y)
            }
            return []
        }

        if all.isEmpty { return finish() }
        // İkinci parmak (ya da parmak değişimi) oturumu iptal eder.
        if all.count != 1 || all[0].id != c.id { return cancel() }

        let p = all[0]
        if !isActive {
            let dx = p.x - c.origin.0
            let dy = p.y - c.origin.1
            guard abs(dy) >= beginThreshold, abs(dy) > 3 * abs(dx) else { return [] }
            isActive = true
            c.anchor = p.y
            candidate = c
            return [.began(c.side)]
        }

        let size = max(step, 0.001)
        let n = Int((p.y - c.anchor) / size)
        guard n != 0 else { return [] }
        c.anchor += Float(n) * size
        candidate = c
        return Array(repeating: .step(n > 0 ? 1 : -1), count: abs(n))
    }

    /// Adayı bırakır; etkinse `.ended`.
    private mutating func finish() -> [EdgeSlideEvent] {
        let wasActive = isActive
        isActive = false
        candidate = nil
        return wasActive ? [.ended] : []
    }

    /// Oturumu bitirir; yüzeyde parmak varsa hepsi kalkana kadar yeni aday yok.
    private mutating func cancel() -> [EdgeSlideEvent] {
        let out = finish()
        if !surfaceWasEmpty { blocked = true }
        return out
    }
}
