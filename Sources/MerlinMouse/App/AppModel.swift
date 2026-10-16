import AppKit
import CMultitouch
import ApplicationServices
import Combine
import UserNotifications
import MerlinCore

struct Warning: Identifiable, Hashable {
    enum Source { case macOS, btt, otherApp }
    var id: String { title }
    var source: Source
    var title: String
    var detail: String
    /// `.otherApp` için çalışan uygulamanın paket kimliği ("Uygulamayı göster").
    var bundleID: String? = nil
}

/// Uygulamanın canlı durumu: izin, aygıt, son eylem, uyarılar.
final class AppModel: ObservableObject {
    static let shared = AppModel()
    let settings = Settings.shared

    @Published var trusted = false
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
    /// İzin sıfırlama başarısız olduysa doğru; yönerge dil değişince de güncel kalsın diye metin hesaplanır.
    @Published var permissionResetFailed = false
    /// İzin sıfırlama başarısız olursa kullanıcıya gösterilen yönerge.
    var permissionHelp: String? {
        permissionResetFailed
            ? L("Sıfırlanamadı. Sistem Ayarları › Gizlilik ve Güvenlik › Erişilebilirlik'te Merlin Mouse'u – ile silip + ile /Applications/MerlinMouse.app'i yeniden ekle.")
            : nil
    }
    /// Ana pencerenin açılması istenen sayfa (`MainWindow.Page.rawValue`); pencere görünce sıfırlar.
    @Published var requestedPage: String?
    @Published private(set) var mouseImage: NSImage?

    private var timer: Timer?
    private var ticks = 0
    private var cancellables = Set<AnyCancellable>()

    func start() {
        Log.write("Başladı · sürüm \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "?")")
        settings.applyAppearance()
        Localization.apply()
        // Olay yakalayıcı başlamadan atamalar yüklensin.
        _ = BindingStore.shared
        TouchMonitor.shared.onFrame = { [weak self] touches in self?.liveTouches = touches }
        TouchMonitor.shared.onGesture = { GestureDispatcher.handle($0) }
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
        // Erişilebilirlik izinleri değişince macOS bu bildirimi yollar; izin geri alındıysa yakalayıcı
        // 2 sn'lik turu beklemeden kalksın. TCC kaydı gecikebildiği için kısa aralıklarla birkaç kez bakılır.
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [weak self] _ in
            self?.checkTrust(prompt: false)
            for delay in [0.25, 0.75, 1.5] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self?.checkTrust(prompt: false) }
            }
        }
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
        if miceCount <= 0 && ticks % 5 == 0 { startTouches() }
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

    func startTouches() {
        changeLogged = false
        // Aygıt yeniden başlarken kalkış karesi gelmeyebilir; yakınlaştırma ve kenar kaydırma takılı kalmasın.
        GestureDispatcher.endPinchSession()
        GestureDispatcher.endEdgeSession()
        let found = TouchMonitor.shared.start()
        if found != miceCount { Log.write("Magic Mouse: \(found) · \(TouchMonitor.shared.deviceDescription)") }
        miceCount = found
        deviceInfo = TouchMonitor.shared.deviceDescription
        // Aygıt varlığı (fare + trackpad); trackpad yalnız sayılır, akışı başlatılmaz.
        let presence = TouchMonitor.shared.devicePresence(startedMice: found)
        if presence.trackpads != devicePresence.trackpads {
            Log.write("Trackpad: \(presence.trackpads)\(presence.builtInTrackpad ? " (dahili)" : "")")
        }
        devicePresence = presence
    }

    func checkTrust(prompt: Bool) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        let axTrusted = AXIsProcessTrustedWithOptions(options)
        // AXIsProcessTrusted önbellekli: izin geri alınsa da "var" der. Gerçek durum canlı yoklamayla doğrulanır.
        let nowTrusted = axTrusted && InputTap.canCreateActiveTap()
        if prompt && !axTrusted { promptedThisLaunch = true }
        if nowTrusted != trusted || prompt { Log.write("Erişilebilirlik izni: \(nowTrusted ? "var" : "yok")") }
        if nowTrusted != trusted {
            let lost = trusted && !nowTrusted
            trusted = nowTrusted
            // Kullanıcının kendi başlattığı sıfırlamada bildirim gönderilmez.
            if lost && !resetInProgress { notifyPermissionLost() }
        }
        // İzin gitti: yakalayıcı hemen kalkar, yoksa sistemin fare olayları donar.
        if !nowTrusted && InputTap.shared.isRunning {
            InputTap.shared.stop()
            GestureDispatcher.endPinchSession()
            GestureDispatcher.endEdgeSession()
            Log.write("İzin yok: olay yakalayıcı durduruldu")
        }
        if trusted && !resetInProgress && !InputTap.shared.isRunning {
            Log.write(InputTap.shared.start() ? "Olay yakalayıcı çalışıyor" : "Olay yakalayıcı başlatılamadı")
        }
    }

    /// İzin çalışırken geri alındı: menü çubuğu uygulaması olduğu için ayrıca sistem bildirimi gönderilir.
    private func notifyPermissionLost() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else {
                Log.write("İzin bildirimi gönderilemedi: bildirim izni yok")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = L("Erişilebilirlik izni kaldırıldı")
            content.body = L("Merlin Mouse hareketleri şu an dönüştüremiyor. İzni yeniden vermek için menü çubuğundaki Merlin Mouse simgesine tıkla.")
            content.sound = .default
            let request = UNNotificationRequest(identifier: "permission-lost", content: content, trigger: nil)
            center.add(request) { error in
                if let error { Log.write("İzin bildirimi eklenemedi: \(error.localizedDescription)") }
            }
        }
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

    /// Bu açılışta macOS izin penceresi gösterildi mi (tek ekran kuralı).
    private var promptedThisLaunch = false
    /// İzin sıfırlanıyor (tccutil sürüyor): yakalayıcı bu arada yeniden kurulmaz.
    private var resetInProgress = false

    /// İzin ister: bu açılışta ilk kez macOS'un izin penceresini (uygulamayı listeye de ekler),
    /// sonrasında (ya da izin zaten varsa) yalnız Sistem Ayarları'nı açar.
    func requestPermission() {
        // Önbellekteki AX "var" diyorsa macOS izin penceresini göstermez; o durumda da Ayarlar açılır.
        if trusted || promptedThisLaunch || AXIsProcessTrusted() {
            openAccessibilitySettings()
        } else {
            checkTrust(prompt: true)
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Eski (yeniden derleme yüzünden geçersiz kalan) Erişilebilirlik kaydını siler, izni yeniden ister.
    func resetAccessibilityPermission() {
        let bundleID = Bundle.main.bundleIdentifier ?? "dev.merlinmouse.MerlinMouse"
        permissionResetFailed = false
        // İzin silinmeden ÖNCE yakalayıcı kalkar; çalışırken silinirse fare ve ekran donar.
        // Sıfırlama bitene kadar yakalayıcı yeniden kurulmaz.
        resetInProgress = true
        InputTap.shared.stop()
        GestureDispatcher.endPinchSession()
        GestureDispatcher.endEdgeSession()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", "Accessibility", bundleID]
            var ok = false
            do {
                try process.run()
                process.waitUntilExit()
                ok = process.terminationStatus == 0
                Log.write("İzin sıfırlama (tccutil) · çıkış \(process.terminationStatus)")
            } catch {
                Log.write("İzin sıfırlama başarısız: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.resetInProgress = false
                // Sıfırlama başarılıysa uygulama yeniden başlar: AX önbelleği bu süreçte "var" demeye devam
                // ettiği için izin penceresi ancak yeni süreçte çıkar (açılışta tek ekran olarak).
                // Başarısızsa yalnız Sistem Ayarları açılır.
                if ok {
                    self.relaunch()
                } else {
                    self.permissionResetFailed = true
                    self.checkTrust(prompt: false)
                    self.openAccessibilitySettings()
                }
            }
        }
    }

    /// Uygulamayı kapatıp 1 sn sonra yeniden açar (yeni süreç izni baştan okur).
    private func relaunch() {
        Log.write("İzin sıfırlandı: uygulama yeniden başlatılıyor")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        do {
            try process.run()
            NSApp.terminate(nil)
        } catch {
            Log.write("Yeniden başlatılamadı: \(error.localizedDescription)")
            openAccessibilitySettings()
        }
    }

    /// Çakışma denetiminin kullandığı ortam (Sistem hareketleri sayfası da bunu kullanır).
    func conflictEnvironment() -> ConflictEnvironment { SystemCheck.environment() }

    func refreshWarnings() {
        warnings = SystemCheck.warnings(for: BindingStore.shared.set.bindings)
    }
}

/// macOS fare hareketleri ve BetterTouchTool ile çakışmaları (ConflictChecker ile) ve çalışan diğer fare uygulamalarını bulur.
enum SystemCheck {
    private static func mouseValue(_ key: String) -> Int? {
        for domain in ["com.apple.AppleMultitouchMouse", "com.apple.driver.AppleBluetoothMultitouch.mouse"] {
            if let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? Int { return value }
        }
        return nil
    }

    private static func mouseString(_ key: String) -> String? {
        for domain in ["com.apple.AppleMultitouchMouse", "com.apple.driver.AppleBluetoothMultitouch.mouse"] {
            if let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? String { return value }
        }
        return nil
    }

    private static func globalInt(_ key: String) -> Int {
        let v = CFPreferencesCopyAppValue(key as CFString, kCFPreferencesAnyApplication)
        if let n = v as? NSNumber { return n.intValue != 0 ? 1 : 0 }
        return 0
    }

    private static func universalAccessBool(_ key: String) -> Bool {
        (CFPreferencesCopyAppValue(key as CFString, "com.apple.universalaccess" as CFString) as? NSNumber)?.boolValue ?? false
    }

    /// Güncel macOS fare ayarları ve BetterTouchTool durumu.
    static func environment() -> ConflictEnvironment {
        ConflictEnvironment(
            mouseButtonMode: mouseString("MouseButtonMode"),
            oneFingerDoubleTap: mouseValue("MouseOneFingerDoubleTapGesture") ?? 0,
            twoFingerDoubleTap: mouseValue("MouseTwoFingerDoubleTapGesture") ?? 0,
            twoFingerHorizSwipe: mouseValue("MouseTwoFingerHorizSwipeGesture") ?? 0,
            bttRunning: NSWorkspace.shared.runningApplications
                .contains { $0.bundleIdentifier == "com.hegenberg.BetterTouchTool" },
            oneFingerHorizSwipePages: globalInt("AppleEnableMouseSwipeNavigateWithScrolls"),
            controlScrollZoom: universalAccessBool("closeViewScrollWheelToggle"))
    }

    static func warnings(for bindings: [GestureBinding]) -> [Warning] {
        let env = environment()
        var result: [Warning] = []
        var seen = Set<String>()
        for b in bindings where b.enabled {
            for c in ConflictChecker.check(b, among: bindings, env: env) {
                let source: Warning.Source
                switch c.level {
                case .macOS: source = .macOS
                case .btt: source = .btt
                default: continue
                }
                if seen.insert(c.title).inserted {
                    result.append(Warning(source: source, title: c.title, detail: c.detail))
                }
            }
        }
        // Çalışan diğer fare uygulamaları (atama olmasa da gösterilir).
        let running = NSWorkspace.shared.runningApplications
        let utilities = MouseUtilityCatalog.detect(running: running.map { (bundleID: $0.bundleIdentifier, name: $0.localizedName) })
        for u in utilities where seen.insert(u.warningTitle).inserted {
            let matching = running.filter { u.matches(bundleID: $0.bundleIdentifier, name: $0.localizedName) }
            // Öne getirilecek uygulama: varsa normal (Dock'ta görünen) olanı, yoksa ilk eşleşen.
            let app = matching.first { $0.activationPolicy == .regular } ?? matching.first
            result.append(Warning(source: .otherApp, title: u.warningTitle, detail: u.warningDetail,
                                  bundleID: app?.bundleIdentifier))
        }
        return result
    }

    /// `.otherApp` uyarısındaki uygulamayı öne getirir.
    static func activateApp(bundleID: String) {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        (apps.first { $0.activationPolicy == .regular } ?? apps.first)?.activate()
    }
}
