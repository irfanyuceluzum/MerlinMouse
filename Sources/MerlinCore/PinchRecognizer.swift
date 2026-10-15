import Foundation

/// Çimdikleme tanıyıcısının ürettiği olaylar.
public enum PinchEvent: Equatable {
    case began
    /// +1 açma (yakınlaştır), −1 kapama (uzaklaştır); büyük sıçramada art arda birden çok adım gelir.
    case step(Int)
    /// Etkinken önceki kareye göre mesafe değişimi (yüzey birimi; + açma, − kapama). `.began`'den sonraki
    /// ilk kare başlangıç noktasına göre verir; toplamları oturumdaki toplam mesafe değişimidir.
    case moved(Float)
    case ended
}

/// İki ön parmağın arasındaki mesafe değişiminden çimdiklemeyi tanıyan saf durum makinesi.
public struct PinchRecognizer {
    /// Adım boyutunun izinli aralığı (yüzey birimi).
    public static let stepRange: ClosedRange<Double> = 0.012...0.05
    public static let defaultStep: Double = 0.025

    public var layout: ZoneLayout = .standard
    /// Başlamak için gereken mesafe değişimi.
    public var beginThreshold: Float = 0.05
    /// Etkinken bir adım için gereken mesafe değişimi.
    public var step: Float = Float(PinchRecognizer.defaultStep)

    public private(set) var isActive = false

    private var pair: (Int32, Int32)?
    private var startDistance: Float = 0
    private var startCentroid: (Float, Float) = (0, 0)
    private var anchor: Float = 0
    /// Etkinken son karenin mesafesi (`.moved` için).
    private var lastDistance: Float = 0
    /// Oturum iptal edildi: ön yüzeydeki tüm parmaklar kalkana kadar yeni çimdikleme yok.
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

    /// Fiziksel tıklama: oturum biter, parmaklar kalkana kadar yeni çimdikleme başlamaz.
    @discardableResult
    public mutating func noteClick() -> [PinchEvent] {
        cancel()
    }

    public mutating func process(_ frame: TouchFrame) -> [PinchEvent] {
        // Avuç (arka bölge) sayılmaz.
        let front = frame.touches.filter { Double($0.y) >= layout.frontLimit }
        if blocked {
            if front.isEmpty { blocked = false }
            return []
        }
        if front.count > 2 { return cancel() }
        guard front.count == 2 else { return reset() }

        let a = front[0], b = front[1]
        let d = hypot(a.x - b.x, a.y - b.y)
        let c = ((a.x + b.x) / 2, (a.y + b.y) / 2)
        let ids = (min(a.id, b.id), max(a.id, b.id))
        guard let p = pair, p == ids else {
            // Yeni parmak çifti: önceki etkin oturum biter, yeni başlangıç noktası alınır.
            let out = reset()
            pair = ids
            startDistance = d
            startCentroid = c
            return out
        }

        if !isActive {
            let change = abs(d - startDistance)
            let shift = hypot(c.0 - startCentroid.0, c.1 - startCentroid.1)
            // Paralel kaydırmada mesafe sabit kalır, merkez kayar; çimdiklemede tersi.
            guard change >= beginThreshold, change > shift else { return [] }
            isActive = true
            anchor = d
            lastDistance = d
            return [.began]
        }

        // Aynı karede önce sürekli değişim, sonra adımlar.
        var out: [PinchEvent] = []
        let delta = d - lastDistance
        lastDistance = d
        if delta != 0 { out.append(.moved(delta)) }

        let size = max(step, 0.001)
        let n = Int((d - anchor) / size)
        guard n != 0 else { return out }
        anchor += Float(n) * size
        return out + Array(repeating: .step(n > 0 ? 1 : -1), count: abs(n))
    }

    /// Oturumu kapatır; etkinse `.ended`.
    private mutating func reset() -> [PinchEvent] {
        let wasActive = isActive
        isActive = false
        pair = nil
        return wasActive ? [.ended] : []
    }

    private mutating func cancel() -> [PinchEvent] {
        let out = reset()
        blocked = true
        return out
    }
}
