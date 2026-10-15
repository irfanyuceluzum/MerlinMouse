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
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)

        // Açılışta kendiliğinden belirmez; panelden, Finder'dan ya da Spotlight'tan açılır.
        Window("Merlin Mouse", id: "main") {
            MainWindow()
        }
        .defaultSize(width: 980, height: 660)
        .defaultLaunchBehavior(.suppressed)
    }
}

extension Notification.Name {
    /// Ana pencereyi açma isteği (uygulama yeniden açıldığında gönderilir).
    static let merlinOpenMain = Notification.Name("dev.merlinmouse.openMain")
}

/// Menü çubuğu simgesi; ana pencereyi açma bildirimini dinler.
struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "magicmouse")
            .onReceive(NotificationCenter.default.publisher(for: .merlinOpenMain)) { _ in
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppModel.shared.start()
    }

    /// Finder / Spotlight'tan yeniden açılınca ana pencereyi göster.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .merlinOpenMain, object: nil)
        return true
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
