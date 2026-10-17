import AppKit
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

    /// macOS Trackpad ayarı (dahili ve Bluetooth trackpad alanları); yoksa 0.
    private static func trackpadValue(_ key: String) -> Int {
        for domain in ["com.apple.AppleMultitouchTrackpad", "com.apple.driver.AppleBluetoothMultitouch.trackpad"] {
            if let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? NSNumber {
                return value.intValue
            }
        }
        return 0
    }

    /// Güncel macOS fare ve trackpad ayarları ve BetterTouchTool durumu.
    static func environment() -> ConflictEnvironment {
        ConflictEnvironment(
            mouseButtonMode: mouseString("MouseButtonMode"),
            oneFingerDoubleTap: mouseValue("MouseOneFingerDoubleTapGesture") ?? 0,
            twoFingerDoubleTap: mouseValue("MouseTwoFingerDoubleTapGesture") ?? 0,
            twoFingerHorizSwipe: mouseValue("MouseTwoFingerHorizSwipeGesture") ?? 0,
            bttRunning: NSWorkspace.shared.runningApplications
                .contains { $0.bundleIdentifier == "com.hegenberg.BetterTouchTool" },
            oneFingerHorizSwipePages: globalInt("AppleEnableMouseSwipeNavigateWithScrolls"),
            controlScrollZoom: universalAccessBool("closeViewScrollWheelToggle"),
            trackpadTapToClick: trackpadValue("Clicking") != 0,
            threeFingerTapLookup: trackpadValue("TrackpadThreeFingerTapGesture") == 2,
            trackpadPinch: trackpadValue("TrackpadPinch") != 0,
            trackpadSmartZoom: trackpadValue("TrackpadTwoFingerDoubleTapGesture") != 0,
            trackpadRotate: trackpadValue("TrackpadRotate") != 0,
            threeFingerHorizSwipe: trackpadValue("TrackpadThreeFingerHorizSwipeGesture"),
            threeFingerVertSwipe: trackpadValue("TrackpadThreeFingerVertSwipeGesture"),
            notificationCenterSwipe: trackpadValue("TrackpadTwoFingerFromRightEdgeSwipeGesture") != 0,
            fiveFingerPinch: trackpadValue("TrackpadFiveFingerPinchGesture") != 0,
            threeFingerDrag: trackpadValue("TrackpadThreeFingerDrag") != 0,
            // 0 kapalı, 1 sol alt, 2 sağ alt köşe.
            trackpadCornerSecondaryClick: trackpadValue("TrackpadCornerSecondaryClick"))
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
