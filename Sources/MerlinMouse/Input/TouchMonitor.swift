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
    /// Trackpad parmaklarının konumu (köşeye basma için; y 0 alt → 1 üst).
    var trackpadPoints: [TouchPoint]
    /// Kare zamanlarıyla aynı saat (`systemUptime`).
    var now: Double
}

/// Kaydırma düşürme için canlı bayraklar: geri çağrı iş parçacığı çimdikleme / kenar oturumu başladığı ya da
/// bittiği anda yazar, olay yakalayıcı okur (`InputState` bayrakları ana kuyruğa geç ulaşır; aradaki kaydırma
/// sızmasın). `TouchMonitor`'ın kilitlerinden ayrı, yalnız iki Bool'u koruyan kısa bir `os_unfair_lock` kullanır;
/// yaprak kilittir (altında başka kilit alınmaz).
final class LiveScrollBlock {
    private let mutex: UnsafeMutablePointer<os_unfair_lock>
    private var pinch = false
    private var edge = false

    init() {
        mutex = .allocate(capacity: 1)
        mutex.initialize(to: os_unfair_lock())
    }

    deinit {
        mutex.deinitialize(count: 1)
        mutex.deallocate()
    }

    /// Olay yakalayıcıda: yalnız kısa kilitli okuma.
    func read() -> (pinch: Bool, edge: Bool) {
        os_unfair_lock_lock(mutex); defer { os_unfair_lock_unlock(mutex) }
        return (pinch, edge)
    }

    func setPinch(_ value: Bool) {
        os_unfair_lock_lock(mutex); pinch = value; os_unfair_lock_unlock(mutex)
    }

    func setEdge(_ value: Bool) {
        os_unfair_lock_lock(mutex); edge = value; os_unfair_lock_unlock(mutex)
    }
}

/// Magic Mouse (ve bağlıysa trackpad) yüzeyindeki parmakları okur ve hareket tanıyıcıları besleyen ince adaptördür.
/// C geri çağrısı kendi iş parçacığında gelir; paylaşılan durum kilitle korunur.
///
/// Kilitler (olay yakalayıcı tanıma hesabını beklemesin diye anlık durum ile tanıyıcı durumu ayrıdır):
/// - `stateMutex` (kısa `os_unfair_lock`): ana iş parçacığının okuduğu anlık değerler — `current`, `mouseLast`,
///   `padCurrent`, `padSelector` (`clickSnapshot`'ın trackpad alanları), `clickSeq` (bekleyen tıklama sayacı) ve
///   kenar şeridi ayarlarının kopyası (`strip`). Altında yalnız kopyalama / sayaç artırma yapılır.
/// - `mouseLock`: fare tanıyıcıları (`recognizer`, `pinch`, `edge`), `wantsPinch`, `edgeEngaged`,
///   `mouseClicksApplied`, `lastUIUpdate`. Fare karesi, fare flush'ı ve bekleyen tıklamanın uygulanması.
/// - `padLock`: `padRecognizer`, `padClicksApplied`, `publishTrackpadUI`, `lastPadUIUpdate`. Fare ve trackpad
///   kareleri ayrı aygıtların geri çağrılarından gelir ve aynı iş parçacığında geleceği garanti değildir; ayrı
///   kilit biri diğerinin tanımasını beklemesin diye.
/// Sıra: bu üç kilit hiçbir yerde iç içe alınmaz (biri bırakılmadan diğeri alınmaz). Tek iç içe geçiş
/// `liveScroll`'un yaprak kilididir: `mouseLock` → `liveScroll` (altında hiçbir kilit alınmaz). Olay yakalayıcı
/// yolu (`noteClick`, `clickSnapshot`, `touches`, `excludingEdgeStrips`) yalnız `stateMutex`'i alır.
/// `DispatchQueue.main.async` her zaman kilitler bırakıldıktan sonra çağrılır.
final class TouchMonitor {
    static let shared = TouchMonitor()

    private let stateMutex: UnsafeMutablePointer<os_unfair_lock> = {
        let m = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        m.initialize(to: os_unfair_lock())
        return m
    }()

    deinit {
        stateMutex.deinitialize(count: 1)
        stateMutex.deallocate()
    }

    /// Anlık durum kilidi altında kısa bölüm (yalnız kopyalama / sayaç).
    private func withState<T>(_ body: () -> T) -> T {
        os_unfair_lock_lock(stateMutex); defer { os_unfair_lock_unlock(stateMutex) }
        return body()
    }

    var onFrame: (([Touch]) -> Void)?
    /// Trackpad parmakları ana kuyrukta gelir (canlı harita için).
    var onTrackpadFrame: (([Touch]) -> Void)?
    /// Tanınan hareketler ana kuyrukta, geldikleri aygıtla gelir.
    var onGesture: (([RecognizedGesture], InputDeviceKind) -> Void)?
    /// Çimdikleme olayları ana kuyrukta gelir.
    var onPinch: (([PinchEvent]) -> Void)?
    /// Kenar kaydırma olayları ana kuyrukta gelir.
    var onEdge: (([EdgeSlideEvent]) -> Void)?

    /// Fare tanıyıcı kilidi (yukarıdaki kilit notuna bakın).
    private let mouseLock = NSLock()
    /// Trackpad tanıyıcı kilidi.
    private let padLock = NSLock()
    /// Olay yakalayıcının bildirdiği fiziksel tıklama sayısı (`stateMutex`). Tanıyıcılar bir sonraki karede
    /// (ya da hemen ardından `flushQueue`'da) tanımadan önce uygular; uygulanan son değer her aygıtta ayrı tutulur.
    private var clickSeq: UInt64 = 0
    /// Fare tanıyıcılarına uygulanan son `clickSeq` (`mouseLock`).
    private var mouseClicksApplied: UInt64 = 0
    /// Trackpad tanıyıcısına uygulanan son `clickSeq` (`padLock`).
    private var padClicksApplied: UInt64 = 0
    /// Kenar şeridi ayarlarının kopyası (`stateMutex`; `excludingEdgeStrips` tanıyıcı kilidini almasın).
    private var strip: (sides: Set<EdgeSide>, width: Double, bounds: EdgeStripBounds) = {
        let e = EdgeSlideRecognizer()
        return (e.enabledSides, e.edgeWidth, e.bounds)
    }()
    /// Çimdikleme / kenar oturumunun canlı durumu (`ScrollModule` okur). Yalnız geçişlerde yazılır: çimdiklemede
    /// `.began` (ataması varken) açar, `.ended` kapatır; kenarda etkinlik değişimi. Kapanış yolları sıfırlar.
    let liveScroll = LiveScrollBlock()
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

    /// Olay yakalayıcı yolu: yalnız `stateMutex`.
    var touches: [Touch] {
        withState { current }
    }

    /// Trackpad'deki etkin parmaklar (seçilen aygıttan).
    var trackpadTouches: [Touch] {
        withState { padCurrent }
    }

    /// Basma anında kaynak aygıt için hafif kopya (sayı, zaman ve en çok 16 trackpad noktası). Olay yakalayıcı
    /// yolu: kilit altında yalnız kopyalanır, noktalara çevirme kilit dışında yapılır.
    func clickSnapshot() -> ClickSnapshot {
        let now = ProcessInfo.processInfo.systemUptime
        let (mouse, trackpad, pad) = withState { (mouseLast, padSelector.lastFrame, padCurrent) }
        return ClickSnapshot(mouse: mouse, trackpad: trackpad,
                             trackpadPoints: pad.map { TouchPoint(id: $0.id, x: $0.x, y: $0.y) }, now: now)
    }

    /// Kenar tanıyıcısının canlı durumu: kenar hareketi başladı mı. Yalnız `deliverEdge`'in ana kuyruk
    /// bloğunda (olay yakalayıcı dışında, kenar durumu değiştiğinde) okunur; `mouseLock` alır.
    var isEdgeEngaged: Bool {
        mouseLock.lock(); defer { mouseLock.unlock() }
        return edge.isActive
    }

    /// Basma çözümlemesi için: etkin kenarların şerit dikdörtgenindeki dokunuşları çıkarır (önbellekteki
    /// ayarlarla, yalnız dizi süzme). Kenar kapalıysa liste olduğu gibi döner. Olay yakalayıcı yolu: ayarlar
    /// `stateMutex` altındaki kopyadan okunur.
    func excludingEdgeStrips(_ points: [TouchPoint]) -> [TouchPoint] {
        let s = withState { strip }
        return EdgeStrip.excluding(points: points, sides: s.sides, width: s.width, bounds: s.bounds)
    }

    /// Kenar oturumunu iptal eder (duraklatma, kapatma, kuru deneme, aygıt yeniden başlama, yakalayıcı durması).
    /// Parmaklar kalkana kadar yeni aday olmaz; üretilen `.ended` iletilmez (kapanışı çağıran yapar).
    /// Ana kuyrukta, olay yakalayıcı dışında ve seyrek çağrılır; `mouseLock` alır.
    func cancelEdge() {
        mouseLock.lock()
        edge.noteClick()
        edgeEngaged = false
        liveScroll.setEdge(false)
        mouseLock.unlock()
    }

    /// Canlı çimdikleme bayrağını kapatır (`GestureDispatcher.endPinchSession`: bitiş, iptal, duraklatma,
    /// kapatma, kuru deneme, izin kaybı, akışın yeniden başlaması). Oturum kabul edildiyse ana kuyrukta
    /// `InputState.pinchActive` devralır; bayrak ancak yeni bir `.began` ile yeniden açılır.
    func cancelLivePinch() {
        liveScroll.setPinch(false)
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
        // Akış yeniden başlıyor: kalkış karesi gelmeyebilir, canlı bayraklar takılı kalmasın.
        liveScroll.setPinch(false)
        liveScroll.setEdge(false)
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
    /// Canlı görünüm açıkken arayüze trackpad karesi gönderilir (geri çağrı iş parçacığı okur; `padLock`).
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
        padLock.lock()
        publishTrackpadUI = now
        padLock.unlock()
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
    /// Ana iş parçacığında; iki kilit sırayla (iç içe değil) alınır.
    private func resetTrackpadState() {
        withState {
            padSelector.reset()
            padCurrent = []
        }
        padLock.lock()
        var r = GestureRecognizer()
        r.layout = Self.trackpadLayout
        r.wantsDoubleTap = padRecognizer.wantsDoubleTap
        padRecognizer = r
        padLock.unlock()
    }

    /// Fiziksel tıklama olduğunda olay yakalayıcı çağırır; açık oturumlar hareket üretmez. Tıklama hangi aygıttan
    /// gelirse gelsin her iki tanıyıcıya gider: fare yolu bugünküyle aynı kalır, trackpad'de de tıklamayla biten
    /// bir oturum dokunma sayılmaz.
    ///
    /// Olay yakalayıcı yolu: tanıyıcı kilidini beklemez. Yalnız `stateMutex` altında bekleyen tıklama sayacı
    /// artar; tanıyıcılara uygulama geri çağrı iş parçacığında bir sonraki karede tanımadan önce ya da hemen
    /// `flushQueue`'da (hangisi önce gelirse; ikisi aynı tıklamayı iki kez uygulamaz) yapılır. Tıklama parmak
    /// kalkışından önce ana iş parçacığında işlendiği için kalkış karesi sayacı görür. Canlı kaydırma bayrakları
    /// bugünkü gibi hemen kapanır (tıklama iki oturumu da iptal eder; iptal sonrası kenar etkin değildir).
    func noteClick() {
        withState { clickSeq += 1 }
        liveScroll.setPinch(false)
        liveScroll.setEdge(false)
        flushQueue.async { [weak self] in self?.applyPendingClicks() }
    }

    /// `flushQueue`'da: bekleyen tıklamayı karenin gelmesini beklemeden uygular (çimdikleme / kenar bitişi ve
    /// `edgeActive` bugünkü gibi hemen iletilsin). Kilitler sırayla alınır, iç içe değil.
    private func applyPendingClicks() {
        let seq = withState { clickSeq }
        mouseLock.lock()
        let click = applyMouseClicks(upTo: seq)
        mouseLock.unlock()
        padLock.lock()
        applyPadClicks(upTo: seq)
        padLock.unlock()
        deliverClick(click)
    }

    /// `mouseLock` altında: `seq`'e kadarki tıklamalar uygulanmadıysa eski `noteClick` gövdesini bir kez uygular
    /// (art arda tıklamalar arada kare yokken aynı sonucu verir; `noteClick` tekrarında etkisizdir). Sayaç yalnız
    /// artar: geç kalan bir uygulayıcının eski değeri (`<=`) yok sayılır, aynı tıklama iki kez uygulanmaz.
    private func applyMouseClicks(upTo seq: UInt64) -> (pinch: [PinchEvent], edge: [EdgeSlideEvent], edgeChanged: Bool) {
        guard seq > mouseClicksApplied else { return ([], [], false) }
        mouseClicksApplied = seq
        recognizer.noteClick()
        let pinchEvents = pinch.noteClick()
        let edgeEvents = edge.noteClick()
        let engaged = edge.isActive
        let edgeChanged = engaged != edgeEngaged
        edgeEngaged = engaged
        // Tıklama iki oturumu da iptal eder: canlı bayraklar kapanır (arada bir kare açtıysa da).
        liveScroll.setPinch(false)
        liveScroll.setEdge(engaged && !edge.enabledSides.isEmpty)
        return (pinchEvents, edgeEvents, edgeChanged)
    }

    /// `padLock` altında: trackpad tanıyıcısına bekleyen tıklama.
    private func applyPadClicks(upTo seq: UInt64) {
        guard seq > padClicksApplied else { return }
        padClicksApplied = seq
        padRecognizer.noteClick()
    }

    /// Kilit dışında: tıklamanın ürettiği çimdikleme / kenar olaylarını ana kuyruğa iletir.
    private func deliverClick(_ click: (pinch: [PinchEvent], edge: [EdgeSlideEvent], edgeChanged: Bool)) {
        let pinchEvents = click.pinch
        if !pinchEvents.isEmpty { DispatchQueue.main.async { self.onPinch?(pinchEvents) } }
        deliverEdge(click.edge, stateChanged: click.edgeChanged)
    }

    /// Bölge düzeni (ön/arka sınırı dahil), çimdikleme adımı, kenar şeridi / adımı / etkin kenarlar ve
    /// çift dokunma sorgusu tanıyıcılara verilir.
    func configure(layout: ZoneLayout, pinchStep: Double, wantsPinch: Bool,
                   edgeWidth: Double, edgeStep: Double, edgeBounds: EdgeStripBounds, edgeSides: Set<EdgeSide>,
                   wantsDoubleTap: @escaping (Int, Zone) -> Bool) {
        mouseLock.lock()
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
        mouseLock.unlock()
        // Olay yakalayıcının okuduğu kopya (kilitler iç içe değil; ikisi de yalnız ana iş parçacığında yazılır).
        withState { strip = (edgeSides, edgeWidth, edgeBounds) }
    }

    /// Trackpad tanıyıcısının çift dokunma sorgusu (`device: .trackpad`).
    func configureTrackpad(wantsDoubleTap: @escaping (Int, Zone) -> Bool) {
        padLock.lock()
        padRecognizer.wantsDoubleTap = wantsDoubleTap
        padLock.unlock()
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

        // 1) Anlık durum (kısa): ana iş parçacığının kopyaladığı değerler ve bekleyen tıklama sayacı.
        let clicks: UInt64 = withState {
            current = active
            mouseLast = (active.count, now)
            return clickSeq
        }

        // 2) Tanıma (`mouseLock`): bekleyen tıklama tanımadan önce uygulanır; kalkış karesi de onu görür.
        mouseLock.lock()
        let click = applyMouseClicks(upTo: clicks)
        let frame = TouchFrame(touches: points, timestamp: timestamp)
        let gestures = recognizer.process(frame)
        var pinchEvents = pinch.process(frame)
        // Ataması yoksa yalnız bitiş iletilir (yakınlaştırma durumu takılı kalmasın).
        if !wantsPinch { pinchEvents = pinchEvents.filter { $0 == .ended } }
        // Canlı bayrak geçiş anında yazılır (ataması yoksa `.began` süzüldüğü için açılmaz).
        if pinchEvents.contains(.ended) {
            liveScroll.setPinch(false)
        } else if pinchEvents.contains(.began) {
            liveScroll.setPinch(true)
        }
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
        // Yalnız etkin kenar varken anlamlı; değişim anında yazılır.
        if edgeChanged { liveScroll.setEdge(engaged && !edge.enabledSides.isEmpty) }
        let deadline = recognizer.pendingDeadline
        let sendUI = timestamp - lastUIUpdate > 0.05 || active.isEmpty
        if sendUI { lastUIUpdate = timestamp }
        mouseLock.unlock()

        // Tıklamanın sonuçları, bugünkü gibi bu karenin sonuçlarından önce iletilir.
        deliverClick(click)
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
        // Önce sayaç okunur ve bırakılır (iç içe değil); bekleyen tıklama flush'la aynı bölümde uygulanır.
        let clicks = withState { clickSeq }
        mouseLock.lock()
        let click = applyMouseClicks(upTo: clicks)
        let gestures = recognizer.flush(now: deadline)
        mouseLock.unlock()
        deliverClick(click)
        if !gestures.isEmpty { DispatchQueue.main.async { self.onGesture?(gestures, .magicMouse) } }
    }

    /// Trackpad karesi (köprünün iş parçacığında). Yalnız seçilen aygıtın kareleri işlenir; yön çevirme ve
    /// kenar şeridi yok. Çimdikleme ve kenar tanıyıcıları yalnız fare içindir.
    private func handleTrackpad(_ slot: Int, _ raw: UnsafeBufferPointer<OTTouch>, _ timestamp: Double) {
        let active = Self.activeTouches(raw)
        let now = ProcessInfo.processInfo.systemUptime

        // 1) Anlık durum (kısa): aygıt seçimi, `clickSnapshot`'ın okuduğu değerler ve bekleyen tıklama sayacı.
        let accepted: UInt64? = withState {
            guard padSelector.accept(slot: slot, touches: active.count, at: now) else { return nil }
            padCurrent = active
            return clickSeq
        }
        guard let clicks = accepted else { return }
        let points = active.map { TouchPoint(id: $0.id, x: $0.x, y: $0.y) }

        // 2) Tanıma (`padLock`): bekleyen tıklama tanımadan önce uygulanır.
        padLock.lock()
        applyPadClicks(upTo: clicks)
        let gestures = padRecognizer.process(TouchFrame(touches: points, timestamp: timestamp))
        let deadline = padRecognizer.pendingDeadline
        // Yalnız canlı görünüm açıkken ve fare arayüzü gibi en çok 20 Hz (kalkış karesi her zaman).
        let sendUI = publishTrackpadUI && (timestamp - lastPadUIUpdate > 0.05 || active.isEmpty)
        if sendUI { lastPadUIUpdate = timestamp }
        padLock.unlock()

        if let deadline {
            flushQueue.asyncAfter(deadline: .now() + max(0, deadline - timestamp)) { [weak self] in
                self?.flushTrackpad(at: deadline)
            }
        }
        if !gestures.isEmpty { DispatchQueue.main.async { self.onGesture?(gestures, .trackpad) } }
        if sendUI { DispatchQueue.main.async { self.onTrackpadFrame?(active) } }
    }

    private func flushTrackpad(at deadline: Double) {
        let clicks = withState { clickSeq }
        padLock.lock()
        applyPadClicks(upTo: clicks)
        let gestures = padRecognizer.flush(now: deadline)
        padLock.unlock()
        if !gestures.isEmpty { DispatchQueue.main.async { self.onGesture?(gestures, .trackpad) } }
    }
}
