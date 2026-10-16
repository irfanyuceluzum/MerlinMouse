import Foundation

/// Birden çok trackpad aygıtından gelen karelerden yalnız bir aygıtınkini seçer. MacBook'ta dahili trackpad iki
/// çoklu dokunma aygıtı olarak görünebilir (ör. aile 176 ve 113); kareleri tek akışa karışırsa parmaklar çift sayılır
/// ve boş kareler açık dokunma oturumunu böler. Kural: en son parmak karesi veren aygıt etkindir; etkin aygıtın
/// tüm kareleri (boş olanlar dahil, parmak kalkışı için) işlenir. Diğer aygıtın karesi yalnız parmak taşıyorsa ve
/// etkin aygıt boştaysa (son karesi boş ya da `ClickSource.staleAfter`'dan eski) aygıtı devralır; aksi hâlde yok sayılır.
public struct TrackpadStreamSelector {
    public private(set) var active: Int?
    private var last: [Int: (touches: Int, time: Double)] = [:]

    public init() {}

    /// `slot` aygıtının karesi işlenecek mi (`time` saniye; aygıtlar arasında aynı saat).
    public mutating func accept(slot: Int, touches: Int, at time: Double) -> Bool {
        last[slot] = (touches, time)
        if active == slot { return true }
        guard touches > 0 else { return false }
        if let a = active, let la = last[a], la.touches > 0, time - la.time <= ClickSource.staleAfter {
            return false
        }
        active = slot
        return true
    }

    /// Etkin aygıtın son karesi (`ClickSource.resolve` için); etkin aygıt yoksa parmak yok.
    public var lastFrame: (touches: Int, lastFrame: Double) {
        guard let a = active, let l = last[a] else { return (0, 0) }
        return (l.touches, l.time)
    }

    /// Aygıtlar yeniden başlatılınca (yuvalar değişebilir) sıfırlanır.
    public mutating func reset() {
        active = nil
        last = [:]
    }
}
