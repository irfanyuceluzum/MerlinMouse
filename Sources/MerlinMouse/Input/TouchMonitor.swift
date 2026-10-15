import CMultitouch
import Foundation
import MerlinCore

struct Touch: Identifiable, Equatable {
    var id: Int32
    var x: Float
    var y: Float
    var size: Float

    /// Ön (uç) tarafa doğru 0…1 konum; kullanıcı yönü ters çevirdiyse düzeltilir.
    func front(flipped: Bool) -> Float { flipped ? 1 - y : y }
}

/// Magic Mouse yüzeyindeki parmakları okur ve hareket tanıyıcıyı besleyen ince adaptördür.
/// C geri çağrısı kendi iş parçacığında gelir; paylaşılan durum kilitle korunur.
final class TouchMonitor {
    static let shared = TouchMonitor()

    var onFrame: (([Touch]) -> Void)?
    /// Tanınan hareketler ana kuyrukta gelir.
    var onGesture: (([RecognizedGesture]) -> Void)?

    private let lock = NSLock()
    private let flushQueue = DispatchQueue(label: "dev.merlinmouse.gesture-flush")
    private var current: [Touch] = []
    private var lastUIUpdate: Double = 0
    private var recognizer = GestureRecognizer()

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

    /// Fiziksel tıklama olduğunda olay yakalayıcı çağırır; açık oturum hareket üretmez.
    func noteClick() {
        lock.lock(); recognizer.noteClick(); lock.unlock()
    }

    /// Bölge düzeni (ön/arka sınırı dahil) ve çift dokunma sorgusu tanıyıcıya verilir.
    func configure(layout: ZoneLayout, wantsDoubleTap: @escaping (Int, Zone) -> Bool) {
        lock.lock()
        recognizer.layout = layout
        recognizer.wantsDoubleTap = wantsDoubleTap
        lock.unlock()
    }

    private func handle(_ raw: UnsafeBufferPointer<OTTouch>, _ timestamp: Double) {
        // 3 = temas başladı, 4 = temas sürüyor
        let active = raw.filter { $0.state == 3 || $0.state == 4 }
            .map { Touch(id: Int32($0.identifier), x: $0.x, y: $0.y, size: $0.size) }
        let flipped = Settings.shared.flipY
        let points = active.map { TouchPoint(id: $0.id, x: $0.x, y: $0.front(flipped: flipped)) }

        lock.lock()
        current = active
        let gestures = recognizer.process(TouchFrame(touches: points, timestamp: timestamp))
        let deadline = recognizer.pendingDeadline
        let sendUI = timestamp - lastUIUpdate > 0.05 || active.isEmpty
        if sendUI { lastUIUpdate = timestamp }
        lock.unlock()

        if let deadline {
            flushQueue.asyncAfter(deadline: .now() + max(0, deadline - timestamp)) { [weak self] in
                self?.flush(at: deadline)
            }
        }
        if !gestures.isEmpty { DispatchQueue.main.async { self.onGesture?(gestures) } }
        if sendUI { DispatchQueue.main.async { self.onFrame?(active) } }
    }

    private func flush(at deadline: Double) {
        lock.lock()
        let gestures = recognizer.flush(now: deadline)
        lock.unlock()
        if !gestures.isEmpty { DispatchQueue.main.async { self.onGesture?(gestures) } }
    }
}
