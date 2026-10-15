import AppKit
import CMultitouch
import ApplicationServices
import Combine
import MerlinCore

struct Warning: Identifiable, Hashable {
    enum Source { case macOS, btt }
    var id: String { title }
    var source: Source
    var title: String
    var detail: String
}

/// Uygulamanın canlı durumu: izin, aygıt, son eylem, uyarılar.
final class AppModel: ObservableObject {
    static let shared = AppModel()
    let settings = Settings.shared

    @Published var trusted = false
    @Published var miceCount = 0
    @Published var deviceInfo = ""
    @Published var lastAction = "Henüz yok"
    @Published var liveTouches: [Touch] = []
    @Published var warnings: [Warning] = []
    /// İzin sıfırlama başarısız olursa kullanıcıya gösterilen yönerge.
    @Published var permissionHelp: String?
    /// Ana pencerenin açılması istenen sayfa (`MainWindow.Page.rawValue`); pencere görünce sıfırlar.
    @Published var requestedPage: String?
    @Published private(set) var mouseImage: NSImage?

    private var timer: Timer?
    private var ticks = 0
    private var cancellables = Set<AnyCancellable>()

    func start() {
        Log.write("Başladı · sürüm \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "?")")
        settings.applyAppearance()
        // Olay yakalayıcı başlamadan atamalar yüklensin.
        _ = BindingStore.shared
        TouchMonitor.shared.onFrame = { [weak self] touches in self?.liveTouches = touches }
        TouchMonitor.shared.onGesture = { GestureDispatcher.handle($0) }
        mouseImage = MouseArtwork.load()
        updateGestureConfig()
        FrontApp.shared.$bundleID
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateGestureConfig() }
            .store(in: &cancellables)
        InputTap.shared.onAction = { [weak self] text in
            self?.lastAction = text
            Log.write(text)
        }

        startTouches()
        checkTrust(prompt: true)
        refreshWarnings()

        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.tick() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.scheduleRestart(after: 1.5)
            // Bluetooth geç toparlanabilir: 5 sn sonra bir kez daha dene.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.startTouches() }
        }
        // Aygıt ekleme/çıkarma (Bluetooth bağlanma/kopma): C geri çağrısı yakalama yapamaz.
        OTMultitouchWatchDevices {
            DispatchQueue.main.async { AppModel.shared.deviceChanged() }
        }
        // Hareket ayarları değişince çakışma uyarılarını yenile.
        settings.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
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

    /// Tanıyıcıya güncel bölge düzenini ve (indeks kopyasıyla) çift dokunma sorgusunu verir.
    private func updateGestureConfig() {
        let index = BindingStore.shared.index
        let bundleID = FrontApp.shared.bundleID
        TouchMonitor.shared.configure(layout: settings.zoneLayout) { fingers, zone in
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
    }

    func startTouches() {
        changeLogged = false
        let found = TouchMonitor.shared.start()
        if found != miceCount { Log.write("Magic Mouse: \(found) · \(TouchMonitor.shared.deviceDescription)") }
        miceCount = found
        deviceInfo = TouchMonitor.shared.deviceDescription
    }

    func checkTrust(prompt: Bool) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        let nowTrusted = AXIsProcessTrustedWithOptions(options)
        if nowTrusted != trusted || prompt { Log.write("Erişilebilirlik izni: \(nowTrusted ? "var" : "yok")") }
        if nowTrusted != trusted { trusted = nowTrusted }
        if trusted && !InputTap.shared.isRunning {
            Log.write(InputTap.shared.start() ? "Olay yakalayıcı çalışıyor" : "Olay yakalayıcı başlatılamadı")
        }
    }

    /// Belirli bir sayfa isteğini bırakır ve uygulamayı öne alır; pencereyi açmak çağıranın işidir (`openWindow`).
    func openMainWindow(page: String?) {
        requestedPage = page
        NSApp.activate(ignoringOtherApps: true)
    }

    var isPaused: Bool { PauseState(pausedUntil: settings.pausedUntil).isPaused(now: Date()) }

    func pause(for interval: TimeInterval) {
        settings.pausedUntil = PauseState.pausing(for: interval, from: Date()).pausedUntil
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

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Eski (yeniden derleme yüzünden geçersiz kalan) Erişilebilirlik kaydını siler, izni yeniden ister.
    func resetAccessibilityPermission() {
        let bundleID = Bundle.main.bundleIdentifier ?? "dev.merlinmouse.MerlinMouse"
        permissionHelp = nil
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
                if !ok {
                    self.permissionHelp = "Sıfırlanamadı. Sistem Ayarları › Gizlilik ve Güvenlik › Erişilebilirlik'te Merlin Mouse'u – ile silip + ile /Applications/MerlinMouse.app'i yeniden ekle."
                }
                self.checkTrust(prompt: true)
                self.openAccessibilitySettings()
            }
        }
    }

    /// Çakışma denetiminin kullandığı ortam (Sistem hareketleri sayfası da bunu kullanır).
    func conflictEnvironment() -> ConflictEnvironment { SystemCheck.environment() }

    func refreshWarnings() {
        warnings = SystemCheck.warnings(for: BindingStore.shared.set.bindings)
    }
}

/// macOS fare hareketleri ve BetterTouchTool ile çakışmaları bulur (ConflictChecker ile).
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
        return result
    }
}
