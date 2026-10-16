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

/// Fiziksel tıklamada kaynak aygıtı seçmek için anlık kopya (`ClickSource.resolve`).
struct ClickSnapshot {
    var mouse: (touches: Int, lastFrame: Double)
    var trackpad: (touches: Int, lastFrame: Double)
    /// Kare zamanlarıyla aynı saat (`systemUptime`).
    var now: Double
}

/// Magic Mouse (ve bağlıysa trackpad) yüzeyindeki parmakları okur ve hareket tanıyıcıları besleyen ince adaptördür.
/// C geri çağrısı kendi iş parçacığında gelir; paylaşılan durum kilitle korunur.
final class TouchMonitor {
    static let shared = TouchMonitor()

    var onFrame: (([Touch]) -> Void)?
    /// Trackpad parmakları ana kuyrukta gelir (canlı harita için).
    var onTrackpadFrame: (([Touch]) -> Void)?
    /// Tanınan hareketler ana kuyrukta, geldikleri aygıtla gelir.
    var onGesture: (([RecognizedGesture], InputDeviceKind) -> Void)?
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
    /// Farenin son karesi: parmak sayısı ve alındığı an (`systemUptime`; aygıt zaman damgasından bağımsız).
    private var mouseLast: (touches: Int, lastFrame: Double) = (0, 0)

    // Trackpad: ayrı tanıyıcı; bölge, ön/arka, çimdikleme ve kenar yok.
    /// Ön/arka sınırı negatif: arka bölge yok, tüm dokunuşlar sayılır.
    private static let trackpadLayout = ZoneLayout(leftEdge: 0.35, rightEdge: 0.65, frontLimit: -1, centerTop: 1)
    private var padRecognizer: GestureRecognizer = {
        var r = GestureRecognizer()
        r.layout = TouchMonitor.trackpadLayout
        return r
    }()
    /// Aynı trackpad'in birden çok aygıtından yalnız birinin karesini seçer (çift sayım olmasın).
    private var padSelector = TrackpadStreamSelector()
    private var padCurrent: [Touch] = []
    private var lastPadUIUpdate: Double = 0
    /// Akışı açık trackpad aygıtı sayısı (akış kapalıyken 0).
    private(set) var trackpadStreams = 0

    var touches: [Touch] {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    /// Trackpad'deki etkin parmaklar (seçilen aygıttan).
    var trackpadTouches: [Touch] {
        lock.lock(); defer { lock.unlock() }
        return padCurrent
    }

    /// Basma anında kaynak aygıt için hafif kopya (yalnız sayı ve zaman).
    func clickSnapshot() -> ClickSnapshot {
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock(); defer { lock.unlock() }
        return ClickSnapshot(mouse: mouseLast, trackpad: padSelector.lastFrame, now: now)
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
    /// (`MultitouchFamily.kind` ile, dahili bilgisine göre).
    func devicePresence(startedMice: Int) -> DevicePresence {
        var buffer = [OTDeviceInfo](repeating: OTDeviceInfo(), count: 16)
        let n = Int(OTMultitouchDevices(&buffer, Int32(buffer.count)))
        let devices = buffer.prefix(n).map { (familyID: Int($0.family), isBuiltIn: $0.builtIn != 0) }
        return DevicePresence(startedMice: startedMice, devices: devices)
    }

    /// Fare akışını (yeniden) başlatır; bulunan fare sayısı (-1: framework yüklenemedi). Trackpad akışı ayrı
    /// yönetilir (`updateTrackpadStream`): `rescanTrackpads` doğruysa ve akış isteniyorsa trackpad'ler de yeniden
    /// taranır (hot-plug, uyanma, elle tarama); fare bulunamadığı için yapılan periyodik taramada trackpad'e dokunulmaz.
    @discardableResult
    func start(rescanTrackpads: Bool = true) -> Int {
        let mice = Int(OTMultitouchStart { pointer, count, timestamp in
            guard let pointer else { return }
            TouchMonitor.shared.handle(UnsafeBufferPointer(start: pointer, count: Int(count)), timestamp)
        })
        updateTrackpadStream(rescan: rescanTrackpads)
        return mice
    }

    // MARK: Trackpad akışı (yalnız gerektiğinde; ana iş parçacığında yönetilir)

    /// Herhangi bir kapsamda açık trackpad ataması var mı (AppModel atamalar değişince yazar).
    private var trackpadBindingsActive = false
    /// Görünür canlı trackpad haritaları (her harita kendi kimliğiyle girer / çıkar; biri kapanırken
    /// diğeri açıksa akış kapanmaz, yinelenen çağrı sayımı bozmaz).
    private var trackpadLiveViewers: Set<UUID> = []
    private var trackpadLiveVisible: Bool { !trackpadLiveViewers.isEmpty }
    /// Akış istenip başlatıldı mı (aygıt bulunmasa da; her çağrıda yeniden taranmasın).
    private var trackpadRunning = false
    /// Canlı görünüm açıkken arayüze trackpad karesi gönderilir (geri çağrı iş parçacığı okur; kilitli).
    private var publishTrackpadUI = false

    /// En az bir trackpad ataması açık mı; değişince akış başlatılır ya da durdurulur (ana iş parçacığı).
    func setTrackpadBindingsActive(_ active: Bool) {
        guard active != trackpadBindingsActive else { return }
        trackpadBindingsActive = active
        updateTrackpadStream(rescan: false)
    }

    /// Bir canlı trackpad haritası göründü / kayboldu (`viewer`: haritanın kimliği; ana iş parçacığı). En az bir
    /// harita görünürken akış açılır ve kareler en çok 20 Hz yayınlanır.
    func setTrackpadLiveView(_ viewer: UUID, visible: Bool) {
        let was = trackpadLiveVisible
        if visible { trackpadLiveViewers.insert(viewer) } else { trackpadLiveViewers.remove(viewer) }
        let now = trackpadLiveVisible
        guard now != was else { return }
        lock.lock()
        publishTrackpadUI = now
        lock.unlock()
        if !now { onTrackpadFrame?([]) }
        updateTrackpadStream(rescan: false)
    }

    /// İstenen duruma geçer: atama ya da canlı görünüm varsa akış açık, yoksa kapalı. Fare akışı etkilenmez.
    private func updateTrackpadStream(rescan: Bool) {
        let wanted = trackpadBindingsActive || trackpadLiveVisible
        if wanted {
            guard rescan || !trackpadRunning else { return }
            resetTrackpadState()
            let n = OTMultitouchStartTrackpads { slot, pointer, count, timestamp in
                guard let pointer else { return }
                TouchMonitor.shared.handleTrackpad(Int(slot), UnsafeBufferPointer(start: pointer, count: Int(count)), timestamp)
            }
            trackpadRunning = true
            let count = max(Int(n), 0)
            if count != trackpadStreams || !rescan { Log.write("Trackpad akışı açık · aygıt \(count)") }
            trackpadStreams = count
        } else if trackpadRunning {
            OTMultitouchStopTrackpads()
            trackpadRunning = false
            trackpadStreams = 0
            resetTrackpadState()
            onTrackpadFrame?([])
            Log.write("Trackpad akışı kapalı")
        }
    }

    /// Yuvalar yeniden dağıtılır ya da akış kapanır: eski aygıtın son karesi ve yarım oturum taşınmasın.
    private func resetTrackpadState() {
        lock.lock()
        padSelector.reset()
        padCurrent = []
        var r = GestureRecognizer()
        r.layout = Self.trackpadLayout
        r.wantsDoubleTap = padRecognizer.wantsDoubleTap
        padRecognizer = r
        lock.unlock()
    }

    /// Fiziksel tıklama olduğunda olay yakalayıcı çağırır; açık oturumlar hareket üretmez. Tıklama hangi aygıttan
    /// gelirse gelsin her iki tanıyıcıya gider: fare yolu bugünküyle aynı kalır, trackpad'de de tıklamayla biten
    /// bir oturum dokunma sayılmaz.
    func noteClick() {
        lock.lock()
        recognizer.noteClick()
        padRecognizer.noteClick()
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

    /// Trackpad tanıyıcısının çift dokunma sorgusu (`device: .trackpad`).
    func configureTrackpad(wantsDoubleTap: @escaping (Int, Zone) -> Bool) {
        lock.lock()
        padRecognizer.wantsDoubleTap = wantsDoubleTap
        lock.unlock()
    }

    /// 3 = temas başladı, 4 = temas sürüyor.
    private static func activeTouches(_ raw: UnsafeBufferPointer<OTTouch>) -> [Touch] {
        raw.filter { $0.state == 3 || $0.state == 4 }
            .map { Touch(id: Int32($0.identifier), x: $0.x, y: $0.y, size: $0.size) }
    }

    private func handle(_ raw: UnsafeBufferPointer<OTTouch>, _ timestamp: Double) {
        let active = Self.activeTouches(raw)
        let flipped = Settings.shared.flipY
        let points = active.map { TouchPoint(id: $0.id, x: $0.x, y: $0.front(flipped: flipped)) }
        let now = ProcessInfo.processInfo.systemUptime

        lock.lock()
        current = active
        mouseLast = (active.count, now)
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
        if !gestures.isEmpty { DispatchQueue.main.async { self.onGesture?(gestures, .magicMouse) } }
        if !pinchEvents.isEmpty { DispatchQueue.main.async { self.onPinch?(pinchEvents) } }
        deliverEdge(edgeEvents, stateChanged: edgeChanged)
        if sendUI { DispatchQueue.main.async { self.onFrame?(active) } }
    }

    private func flush(at deadline: Double) {
        lock.lock()
        let gestures = recognizer.flush(now: deadline)
        lock.unlock()
        if !gestures.isEmpty { DispatchQueue.main.async { self.onGesture?(gestures, .magicMouse) } }
    }

    /// Trackpad karesi (köprünün iş parçacığında). Yalnız seçilen aygıtın kareleri işlenir; yön çevirme ve
    /// kenar şeridi yok. Çimdikleme ve kenar tanıyıcıları yalnız fare içindir.
    private func handleTrackpad(_ slot: Int, _ raw: UnsafeBufferPointer<OTTouch>, _ timestamp: Double) {
        let active = Self.activeTouches(raw)
        let now = ProcessInfo.processInfo.systemUptime

        lock.lock()
        guard padSelector.accept(slot: slot, touches: active.count, at: now) else {
            lock.unlock()
            return
        }
        padCurrent = active
        let points = active.map { TouchPoint(id: $0.id, x: $0.x, y: $0.y) }
        let gestures = padRecognizer.process(TouchFrame(touches: points, timestamp: timestamp))
        let deadline = padRecognizer.pendingDeadline
        // Yalnız canlı görünüm açıkken ve fare arayüzü gibi en çok 20 Hz (kalkış karesi her zaman).
        let sendUI = publishTrackpadUI && (timestamp - lastPadUIUpdate > 0.05 || active.isEmpty)
        if sendUI { lastPadUIUpdate = timestamp }
        lock.unlock()

        if let deadline {
            flushQueue.asyncAfter(deadline: .now() + max(0, deadline - timestamp)) { [weak self] in
                self?.flushTrackpad(at: deadline)
            }
        }
        if !gestures.isEmpty { DispatchQueue.main.async { self.onGesture?(gestures, .trackpad) } }
        if sendUI { DispatchQueue.main.async { self.onTrackpadFrame?(active) } }
    }

    private func flushTrackpad(at deadline: Double) {
        lock.lock()
        let gestures = padRecognizer.flush(now: deadline)
        lock.unlock()
        if !gestures.isEmpty { DispatchQueue.main.async { self.onGesture?(gestures, .trackpad) } }
    }
}
