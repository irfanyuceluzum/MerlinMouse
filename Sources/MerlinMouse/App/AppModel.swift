import AppKit
import CMultitouch
import Combine
import MerlinCore

/// Uygulamanın canlı durumu: izin, aygıt, son eylem, uyarılar.
final class AppModel: ObservableObject {
    static let shared = AppModel()
    let settings = Settings.shared
    /// Erişilebilirlik izni; değişiklikleri bu modelin `objectWillChange`'ine iletilir (arayüz `model` üzerinden izler).
    let accessibility = AccessibilityManager()

    /// İzin durumu (`accessibility` üzerinden; arayüz için ince iletici).
    var trusted: Bool { accessibility.trusted }
    @Published var miceCount = 0
    @Published var deviceInfo = ""
    /// Bağlı dokunma aygıtları; aygıtı olmayan türün ayarları pasiftir.
    @Published var devicePresence = DevicePresence.none
    /// Son eylemin metni; nil iken arayüz "Henüz yok" gösterir.
    @Published var lastAction: String?
    @Published var liveTouches: [Touch] = []
    /// Deneme modundaki son olaylar (en yeni önce).
    @Published var eventLog = EventLog()
    /// Karşılama rehberi gösteriliyor (ilk açılışta, ya da Genel sayfasından istenince).
    @Published var showOnboarding = !Settings.shared.onboardingCompleted
    @Published var warnings: [Warning] = []
    /// İzin sıfırlama başarısız olursa kullanıcıya gösterilen yönerge.
    var permissionHelp: String? { accessibility.permissionHelp }
    /// Ana pencerenin açılması istenen sayfa (`MainWindow.Page.rawValue`); pencere görünce sıfırlar.
    @Published var requestedPage: String?
    @Published private(set) var mouseImage: NSImage?

    private var timer: Timer?
    private var ticks = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        // İzin durumu değişince modeli izleyen görünümler de yeniden çizilsin.
        accessibility.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func start() {
        Log.write("Başladı · sürüm \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "?")")
        settings.applyAppearance()
        Localization.apply()
        // Olay yakalayıcı başlamadan atamalar yüklensin.
        _ = BindingStore.shared
        TouchMonitor.shared.onFrame = { [weak self] touches in self?.liveTouches = touches }
        TouchMonitor.shared.onTrackpadFrame = { TrackpadLiveTouches.shared.update($0) }
        TouchMonitor.shared.onGesture = { GestureDispatcher.handle($0, device: $1) }
        TouchMonitor.shared.onPinch = { GestureDispatcher.handlePinch($0) }
        TouchMonitor.shared.onEdge = { GestureDispatcher.handleEdge($0) }
        mouseImage = MouseArtwork.load()
        updateGestureConfig()
        FrontApp.shared.$bundleID
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateGestureConfig() }
            .store(in: &cancellables)
        InputState.shared.dryRun = false
        InputTap.shared.onAction = { [weak self] text in
            self?.lastAction = text
            self?.recordEvent(text, dryRun: false)
            Log.write(text)
        }

        startTouches()
        BatteryMonitor.shared.start()
        // Karşılama rehberi açılacaksa izni rehberin ilk adımı ister; iki ekran üst üste binmesin.
        checkTrust(prompt: !showOnboarding)
        refreshWarnings()

        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.tick() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.scheduleRestart(after: 1.5)
            BatteryMonitor.shared.refresh()
            // Bluetooth geç toparlanabilir: 5 sn sonra bir kez daha dene.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.startTouches() }
        }
        // Başka bir fare uygulaması açılınca/kapanınca çakışma uyarıları 10 sn'lik turu beklemeden yenilenir.
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refreshWarnings()
            }
        }
        // Erişilebilirlik izinleri değişince yakalayıcı 2 sn'lik turu beklemeden kalksın.
        accessibility.observeSystemChanges()
        // Aygıt ekleme/çıkarma (Bluetooth bağlanma/kopma): C geri çağrısı yakalama yapamaz.
        OTMultitouchWatchDevices {
            DispatchQueue.main.async { AppModel.shared.deviceChanged() }
        }
        // Hareket ayarları değişince çakışma uyarılarını yenile.
        settings.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                // Kapatılınca süren yakınlaştırma ve kenar kaydırma da biter.
                if !Settings.shared.enabled {
                    GestureDispatcher.endPinchSession()
                    GestureDispatcher.endEdgeSession()
                }
                self?.refreshWarnings()
                self?.updateGestureConfig()
            }
            .store(in: &cancellables)
        BindingStore.shared.$set
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshWarnings()
                self?.updateGestureConfig()
            }
            .store(in: &cancellables)
    }

    /// Tanıyıcıya güncel bölge düzenini, çimdikleme ve kenar kaydırma ayarlarını ve (indeks kopyasıyla)
    /// çift dokunma sorgusunu verir. Kenar yalnız öndeki uygulama için açık ve geçerli bir ataması varsa etkindir.
    private func updateGestureConfig() {
        let index = BindingStore.shared.index
        let bundleID = FrontApp.shared.bundleID
        let wantsPinch = index.match(Trigger(kind: .pinch, fingers: 2), bundleID: bundleID) != nil
        let edgeSides = Set(EdgeSide.allCases.filter {
            index.match(Trigger(kind: .edgeSlide, zone: $0.zone), bundleID: bundleID)?.action.isStepAction == true
        })
        TouchMonitor.shared.configure(layout: settings.zoneLayout, pinchStep: settings.pinchStep,
                                      wantsPinch: wantsPinch, edgeWidth: settings.edgeWidth,
                                      edgeStep: settings.edgeStep, edgeBounds: settings.edgeBounds,
                                      edgeSides: edgeSides) { fingers, zone in
            index.hasDoubleTap(fingers: fingers, zone: zone, bundleID: bundleID)
                || (fingers == 4 && index.hasDoubleTap(fingers: 3, zone: zone, bundleID: bundleID))
        }
        // Trackpad akışı yalnız açık bir trackpad ataması (herhangi bir kapsamda) ya da canlı görünüm varken açıktır.
        TouchMonitor.shared.setTrackpadBindingsActive(index.hasAnyBinding(device: .trackpad))
        // Trackpad tanıyıcısı: bölgesiz, yalnız trackpad atamaları.
        TouchMonitor.shared.configureTrackpad { fingers, _ in
            index.hasDoubleTap(fingers: fingers, bundleID: bundleID, device: .trackpad)
                || (fingers == 4 && index.hasDoubleTap(fingers: 3, bundleID: bundleID, device: .trackpad))
        }
    }

    private func tick() {
        ticks += 1
        // İzin, yakalayıcı çalışsa da her turda okunur (geri alınmayı da yakalar).
        checkTrust(prompt: false)
        if let until = settings.pausedUntil, Date() >= until {
            resume()
            Log.write("Duraklatma bitti")
        }
        // Fare bulunamadıysa (Bluetooth yeni bağlandıysa) 10 sn'de bir yeniden tara.
        // Trackpad akışı bu periyodik taramada yeniden başlatılmaz (süren trackpad dokunuşu bölünmesin).
        if miceCount <= 0 && ticks % 5 == 0 { startTouches(rescanTrackpads: false) }
        if ticks % 5 == 0 { refreshWarnings() }
    }

    private var restartWork: DispatchWorkItem?

    /// Art arda gelen bildirimleri tek yeniden başlatmaya indirir.
    private func scheduleRestart(after delay: TimeInterval) {
        restartWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.startTouches() }
        restartWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private var changeLogged = false

    fileprivate func deviceChanged() {
        if !changeLogged {
            changeLogged = true
            Log.write("Aygıt değişikliği algılandı")
        }
        scheduleRestart(after: 1.5)
        BatteryMonitor.shared.refresh()
    }

    /// `rescanTrackpads`: trackpad akışı isteniyorsa trackpad'leri de yeniden tara (hot-plug, uyanma, elle tarama).
    func startTouches(rescanTrackpads: Bool = true) {
        changeLogged = false
        // Aygıt yeniden başlarken kalkış karesi gelmeyebilir; yakınlaştırma ve kenar kaydırma takılı kalmasın.
        GestureDispatcher.endPinchSession()
        GestureDispatcher.endEdgeSession()
        let found = TouchMonitor.shared.start(rescanTrackpads: rescanTrackpads)
        if found != miceCount { Log.write("Magic Mouse: \(found) · \(TouchMonitor.shared.deviceDescription)") }
        miceCount = found
        deviceInfo = TouchMonitor.shared.deviceDescription
        // Aygıt varlığı (fare + trackpad); trackpad akışı yalnız gerektiğinde açıktır (aygıt sayısı ayrıca yazılır).
        let presence = TouchMonitor.shared.devicePresence(startedMice: found)
        if presence.trackpads != devicePresence.trackpads {
            Log.write("Trackpad: \(presence.trackpads)\(presence.builtInTrackpad ? " (dahili)" : "")"
                      + " · akış \(TouchMonitor.shared.trackpadStreams)")
        }
        devicePresence = presence
    }

    /// İzni (canlı yoklamayla) okur; yakalayıcıyı kaldırır ya da başlatır (`accessibility`'ye iletir).
    func checkTrust(prompt: Bool) {
        accessibility.checkTrust(prompt: prompt)
    }

    /// Olay günlüğüne ekler (yalnız bellek işlemi; ana iş parçacığında çağrılır).
    func recordEvent(_ text: String, dryRun: Bool) {
        eventLog.append(EventLogEntry(text: text, dryRun: dryRun))
    }

    /// Belirli bir sayfa isteğini bırakır ve uygulamayı öne alır; pencereyi açmak çağıranın işidir (`openWindow`).
    func openMainWindow(page: String?) {
        requestedPage = page
        NSApp.activate(ignoringOtherApps: true)
    }

    var isPaused: Bool { PauseState(pausedUntil: settings.pausedUntil).isPaused(now: Date()) }

    func pause(for interval: TimeInterval) {
        settings.pausedUntil = PauseState.pausing(for: interval, from: Date()).pausedUntil
        GestureDispatcher.endPinchSession()
        GestureDispatcher.endEdgeSession()
        Log.write("Duraklatıldı · \(Int(interval / 60)) dk")
        objectWillChange.send()
    }

    func resume() {
        guard settings.pausedUntil != nil else { return }
        settings.pausedUntil = nil
        Log.write("Duraklatma kaldırıldı")
        objectWillChange.send()
    }

    /// Verilen görseli uygulamanın fare görseli olarak kopyalar (varsa üzerine yazar) ve yükler.
    func importMouseImage(from url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: MouseArtwork.directory, withIntermediateDirectories: true)
        if fm.fileExists(atPath: MouseArtwork.fileURL.path) { try fm.removeItem(at: MouseArtwork.fileURL) }
        try fm.copyItem(at: url, to: MouseArtwork.fileURL)
        mouseImage = MouseArtwork.load()
    }

    func removeMouseImage() {
        try? FileManager.default.removeItem(at: MouseArtwork.fileURL)
        mouseImage = nil
    }

    /// İzin ister (`accessibility`'ye iletir).
    func requestPermission() {
        accessibility.requestPermission()
    }

    /// Eski Erişilebilirlik kaydını siler, izni yeniden ister (`accessibility`'ye iletir).
    func resetAccessibilityPermission() {
        accessibility.resetAccessibilityPermission()
    }

    /// Çakışma denetiminin kullandığı ortam (Sistem hareketleri sayfası da bunu kullanır).
    func conflictEnvironment() -> ConflictEnvironment { SystemCheck.environment() }

    func refreshWarnings() {
        warnings = SystemCheck.warnings(for: BindingStore.shared.set.bindings)
    }
}
