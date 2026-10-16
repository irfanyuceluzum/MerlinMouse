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
    /// Çimdikleme olayları ana kuyrukta gelir.
    var onPinch: (([PinchEvent]) -> Void)?
    /// Kenar kaydırma olayları ana kuyrukta gelir.
    var onEdge: (([EdgeSlideEvent]) -> Void)?

    private let lock = NSLock()
    private let flushQueue = DispatchQueue(label: "dev.merlinmouse.gesture-flush")
    private var current: [Touch] = []
    private var lastUIUpdate: Double = 0
    private var recognizer = GestureRecognizer()
    private var pinch = PinchRecognizer()
    /// Öndeki uygulama için açık bir çimdikleme ataması var mı; yoksa yalnız `.ended` iletilir.
    private var wantsPinch = false
    /// Kenar kaydırma; etkin kenarlar boşsa hiçbir dokunuş aday olmaz.
    private var edge = EdgeSlideRecognizer()
    /// Son karede kenar hareketi etkin miydi (değişince `InputState.edgeActive` güncellenir).
    /// Adaylık sayılmaz: başlamadan önce gerçek kaydırma geçer.
    private var edgeEngaged = false

    var touches: [Touch] {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    /// Kenar tanıyıcısının canlı durumu: kenar hareketi başladı mı.
    var isEdgeEngaged: Bool {
        lock.lock(); defer { lock.unlock() }
        return edge.isActive
    }

    /// Basma çözümlemesi için: etkin kenarların şerit dikdörtgenindeki dokunuşları çıkarır (önbellekteki
    /// ayarlarla, yalnız dizi süzme). Kenar kapalıysa liste olduğu gibi döner.
    func excludingEdgeStrips(_ points: [TouchPoint]) -> [TouchPoint] {
        lock.lock()
        let sides = edge.enabledSides, width = edge.edgeWidth, bounds = edge.bounds
        lock.unlock()
        return EdgeStrip.excluding(points: points, sides: sides, width: width, bounds: bounds)
    }

    /// Kenar oturumunu iptal eder (duraklatma, kapatma, kuru deneme, aygıt yeniden başlama, yakalayıcı durması).
    /// Parmaklar kalkana kadar yeni aday olmaz; üretilen `.ended` iletilmez (kapanışı çağıran yapar).
    func cancelEdge() {
        lock.lock()
        edge.noteClick()
        edgeEngaged = false
        lock.unlock()
    }

    /// Ana kuyrukta: `edgeActive`'i tanıyıcının o anki durumundan yazar (sıra dışı eski değer takılı kalmaz),
    /// sonra olayları iletir.
    private func deliverEdge(_ events: [EdgeSlideEvent], stateChanged: Bool) {
        guard stateChanged || !events.isEmpty else { return }
        DispatchQueue.main.async {
            if stateChanged { InputState.shared.edgeActive = self.isEdgeEngaged }
            if !events.isEmpty { self.onEdge?(events) }
        }
    }

    var deviceDescription: String { String(cString: OTMultitouchDescribe()) }

    /// Son taramadaki aygıt varlığı: fare sayısı `start` sonucundan, trackpad'ler köprünün tanım listesinden
    /// (`MultitouchFamily.kind` ile, dahili bilgisine göre). Trackpad'lerin akışı başlatılmaz; yalnız sayılır.
    func devicePresence(startedMice: Int) -> DevicePresence {
        var buffer = [OTDeviceInfo](repeating: OTDeviceInfo(), count: 16)
        let n = Int(OTMultitouchDevices(&buffer, Int32(buffer.count)))
        let devices = buffer.prefix(n).map { (familyID: Int($0.family), isBuiltIn: $0.builtIn != 0) }
        return DevicePresence(startedMice: startedMice, devices: devices)
    }

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
        lock.lock()
        recognizer.noteClick()
        let pinchEvents = pinch.noteClick()
        let edgeEvents = edge.noteClick()
        let engaged = edge.isActive
        let edgeChanged = engaged != edgeEngaged
        edgeEngaged = engaged
        lock.unlock()
        if !pinchEvents.isEmpty { DispatchQueue.main.async { self.onPinch?(pinchEvents) } }
        deliverEdge(edgeEvents, stateChanged: edgeChanged)
    }

    /// Bölge düzeni (ön/arka sınırı dahil), çimdikleme adımı, kenar şeridi / adımı / etkin kenarlar ve
    /// çift dokunma sorgusu tanıyıcılara verilir.
    func configure(layout: ZoneLayout, pinchStep: Double, wantsPinch: Bool,
                   edgeWidth: Double, edgeStep: Double, edgeBounds: EdgeStripBounds, edgeSides: Set<EdgeSide>,
                   wantsDoubleTap: @escaping (Int, Zone) -> Bool) {
        lock.lock()
        recognizer.layout = layout
        recognizer.wantsDoubleTap = wantsDoubleTap
        pinch.layout = layout
        pinch.step = Float(pinchStep)
        self.wantsPinch = wantsPinch
        edge.layout = layout
        edge.edgeWidth = edgeWidth
        edge.bounds = edgeBounds
        edge.step = Float(edgeStep)
        edge.enabledSides = edgeSides
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
        let frame = TouchFrame(touches: points, timestamp: timestamp)
        let gestures = recognizer.process(frame)
        var pinchEvents = pinch.process(frame)
        // Ataması yoksa yalnız bitiş iletilir (yakınlaştırma durumu takılı kalmasın).
        if !wantsPinch { pinchEvents = pinchEvents.filter { $0 == .ended } }
        // Çimdikleme başladıysa açık dokunma / kaydırma oturumu hareket üretmez.
        if pinchEvents.contains(.began) { recognizer.noteClick() }
        let edgeEvents = edge.process(frame)
        // Kenar kaydırma başladıysa da açık dokunma oturumu hareket üretmez.
        if edgeEvents.contains(where: { if case .began = $0 { return true } else { return false } }) {
            recognizer.noteClick()
        }
        // Yalnız etkin oturum kaydırmayı durdurur; adaylıkta şeritte başlayan normal kaydırma geçer.
        let engaged = edge.isActive
        let edgeChanged = engaged != edgeEngaged
        edgeEngaged = engaged
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
        if !pinchEvents.isEmpty { DispatchQueue.main.async { self.onPinch?(pinchEvents) } }
        deliverEdge(edgeEvents, stateChanged: edgeChanged)
        if sendUI { DispatchQueue.main.async { self.onFrame?(active) } }
    }

    private func flush(at deadline: Double) {
        lock.lock()
        let gestures = recognizer.flush(now: deadline)
        lock.unlock()
        if !gestures.isEmpty { DispatchQueue.main.async { self.onGesture?(gestures) } }
    }
}
