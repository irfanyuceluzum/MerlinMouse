import AppKit
import SwiftUI

@main
struct MerlinMouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        // Tanılama: `MerlinMouse --probe` dokunma aygıtlarını listeler ve çıkar.
        if CommandLine.arguments.contains("--probe") {
            let found = TouchMonitor.shared.start()
            print("Bulunan Magic Mouse: \(found) · \(TouchMonitor.shared.deviceDescription)")
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView()
        } label: {
            Image(systemName: "magicmouse")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppModel.shared.start()
    }
}

/// Tasarımdaki derin mavi vurgu rengi (gündüz / gece).
extension Color {
    static let merlinAccent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.278, green: 0.404, blue: 0.933, alpha: 1)
            : NSColor(srgbRed: 0.184, green: 0.357, blue: 0.827, alpha: 1)
    })
    static let merlinWarn = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 1.0, green: 0.76, blue: 0.48, alpha: 1)
            : NSColor(srgbRed: 0.56, green: 0.29, blue: 0.0, alpha: 1)
    })
    static let merlinBTT = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.85, green: 0.74, blue: 1.0, alpha: 1)
            : NSColor(srgbRed: 0.40, green: 0.20, blue: 0.66, alpha: 1)
    })
}
