import AppKit
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
        updateGestureConfig()
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
        ) { [weak self] _ in self?.startTouches() }
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

    /// Tanıyıcıya güncel bölge genişliğini ve (indeks kopyasıyla) çift dokunma sorgusunu verir.
    private func updateGestureConfig() {
        let index = BindingStore.shared.index
        TouchMonitor.shared.configure(zoneWidth: settings.zoneWidth) { fingers, zone in
            index.hasDoubleTap(fingers: fingers, zone: zone)
        }
    }

    private func tick() {
        ticks += 1
        if !InputTap.shared.isRunning { checkTrust(prompt: false) }
        // Fare bulunamadıysa (Bluetooth yeni bağlandıysa) 10 sn'de bir yeniden tara.
        if miceCount <= 0 && ticks % 5 == 0 { startTouches() }
        if ticks % 5 == 0 { refreshWarnings() }
    }

    func startTouches() {
        let found = TouchMonitor.shared.start()
        if found != miceCount { Log.write("Magic Mouse: \(found) · \(TouchMonitor.shared.deviceDescription)") }
        miceCount = found
        deviceInfo = TouchMonitor.shared.deviceDescription
    }

    func checkTrust(prompt: Bool) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        let nowTrusted = AXIsProcessTrustedWithOptions(options)
        if nowTrusted != trusted || prompt { Log.write("Erişilebilirlik izni: \(nowTrusted ? "var" : "yok")") }
        trusted = nowTrusted
        if trusted && !InputTap.shared.isRunning {
            Log.write(InputTap.shared.start() ? "Olay yakalayıcı çalışıyor" : "Olay yakalayıcı başlatılamadı")
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
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

    /// Güncel macOS fare ayarları ve BetterTouchTool durumu.
    static func environment() -> ConflictEnvironment {
        ConflictEnvironment(
            mouseButtonMode: mouseString("MouseButtonMode"),
            oneFingerDoubleTap: mouseValue("MouseOneFingerDoubleTapGesture") ?? 0,
            twoFingerDoubleTap: mouseValue("MouseTwoFingerDoubleTapGesture") ?? 0,
            twoFingerHorizSwipe: mouseValue("MouseTwoFingerHorizSwipeGesture") ?? 0,
            bttRunning: NSWorkspace.shared.runningApplications
                .contains { $0.bundleIdentifier == "com.hegenberg.BetterTouchTool" })
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
