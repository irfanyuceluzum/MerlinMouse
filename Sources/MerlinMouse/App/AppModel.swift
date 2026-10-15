import AppKit
import ApplicationServices
import Combine

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
        TouchMonitor.shared.onFrame = { [weak self] touches in self?.liveTouches = touches }
        TouchMonitor.shared.onThreeFingerTap = { [weak self] in
            guard let self, self.settings.enabled, self.settings.threeFingerTap, EventTapper.shared.isRunning else { return }
            EventTapper.shared.postMiddleClick()
            self.lastAction = "Orta tıklama · üç parmakla dokunma"
            Log.write(self.lastAction)
        }
        EventTapper.shared.onAction = { [weak self] text in
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
            .sink { [weak self] _ in self?.refreshWarnings() }
            .store(in: &cancellables)
    }

    private func tick() {
        ticks += 1
        if !EventTapper.shared.isRunning { checkTrust(prompt: false) }
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
        if trusted && !EventTapper.shared.isRunning {
            Log.write(EventTapper.shared.start() ? "Olay yakalayıcı çalışıyor" : "Olay yakalayıcı başlatılamadı")
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func refreshWarnings() {
        warnings = SystemCheck.warnings(for: settings)
    }
}

/// macOS fare hareketleri ve BetterTouchTool ile çakışmaları bulur.
enum SystemCheck {
    private static func mouseValue(_ key: String) -> Int? {
        for domain in ["com.apple.AppleMultitouchMouse", "com.apple.driver.AppleBluetoothMultitouch.mouse"] {
            if let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? Int { return value }
        }
        return nil
    }

    static func warnings(for s: Settings) -> [Warning] {
        var result: [Warning] = []
        let bttRunning = NSWorkspace.shared.runningApplications
            .contains { $0.bundleIdentifier == "com.hegenberg.BetterTouchTool" }
        if bttRunning && (s.twoFingerClick || s.threeFingerClick) {
            result.append(Warning(
                source: .btt,
                title: "BetterTouchTool çalışıyor",
                detail: "BTT'de 2 ve 3 parmak tıklaması da orta tıklamaya atanmış; orta tıklama iki kez gidebilir. BTT › Magic Mouse'ta bu ikisini kapat."
            ))
        }
        if s.zoneClick, (mouseValue("MouseOneFingerDoubleTapGesture") ?? 0) != 0 {
            result.append(Warning(
                source: .macOS,
                title: "Akıllı büyütme açık",
                detail: "macOS tek parmakla çift dokunmayı akıllı büyütmeye ayırmış. Orta bölgeye hızlı iki tıklama yakınlaştırma da yapabilir."
            ))
        }
        return result
    }
}
