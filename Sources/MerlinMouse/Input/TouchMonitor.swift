import CMultitouch
import Foundation

struct Touch: Identifiable, Equatable {
    var id: Int32
    var x: Float
    var y: Float
    var size: Float

    /// Ön (uç) tarafa doğru 0…1 konum; kullanıcı yönü ters çevirdiyse düzeltilir.
    func front(flipped: Bool) -> Float { flipped ? 1 - y : y }
}

/// Magic Mouse yüzeyindeki parmakları okur, üç parmakla dokunmayı algılar.
/// C geri çağrısı kendi iş parçacığında gelir; paylaşılan durum kilitle korunur.
final class TouchMonitor {
    static let shared = TouchMonitor()

    /// Avuç içi dokunuşlarını ayırmak için: bu değerin önündekiler "parmak" sayılır.
    static let frontLimit: Float = 0.4

    var onFrame: (([Touch]) -> Void)?
    var onThreeFingerTap: (() -> Void)?

    private let lock = NSLock()
    private var current: [Touch] = []
    private var previousCount = 0
    private var lastUIUpdate: Double = 0

    // Üç parmakla dokunma algılama
    private var tapStart: Double?
    private var tapOrigins: [Int32: (Float, Float)] = [:]
    private var tapMaxMove: Float = 0
    private var clickedDuringTap = false

    var touches: [Touch] {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    var deviceDescription: String { String(cString: OTMultitouchDescribe()) }

    /// Bulunan fare sayısı (-1: framework yüklenemedi).
    @discardableResult
    func start() -> Int {
        Int(OTMultitouchStart { pointer, count, timestamp in
            guard let pointer else { return }
            TouchMonitor.shared.handle(UnsafeBufferPointer(start: pointer, count: Int(count)), timestamp)
        })
    }

    /// Fiziksel tıklama olduğunda olay yakalayıcı çağırır; dokunma "tap" sayılmaz.
    func noteClick() {
        lock.lock(); clickedDuringTap = true; lock.unlock()
    }

    private func handle(_ raw: UnsafeBufferPointer<OTTouch>, _ timestamp: Double) {
        // 3 = temas başladı, 4 = temas sürüyor
        let active = raw.filter { $0.state == 3 || $0.state == 4 }
            .map { Touch(id: Int32($0.identifier), x: $0.x, y: $0.y, size: $0.size) }

        var fireTap = false
        lock.lock()
        current = active
        let count = active.count
        if count >= 3 && previousCount < 3 && tapStart == nil {
            tapStart = timestamp
            tapOrigins = Dictionary(uniqueKeysWithValues: active.map { ($0.id, ($0.x, $0.y)) })
            tapMaxMove = 0
            clickedDuringTap = false
        }
        if let start = tapStart {
            for t in active {
                if let o = tapOrigins[t.id] { tapMaxMove = max(tapMaxMove, hypot(t.x - o.0, t.y - o.1)) }
            }
            if timestamp - start > 0.35 {
                tapStart = nil
            } else if count == 0 {
                fireTap = tapMaxMove < 0.04 && !clickedDuringTap
                tapStart = nil
            }
        }
        previousCount = count
        let sendUI = timestamp - lastUIUpdate > 0.05 || count == 0
        if sendUI { lastUIUpdate = timestamp }
        lock.unlock()

        if fireTap { DispatchQueue.main.async { self.onThreeFingerTap?() } }
        if sendUI { DispatchQueue.main.async { self.onFrame?(active) } }
    }
}
