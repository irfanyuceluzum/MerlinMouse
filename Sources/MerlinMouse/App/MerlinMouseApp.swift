import AppKit
import SwiftUI
import MerlinCore

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
        // İlk görünüm çizilmeden önce seçili dil bağlanır.
        Localization.apply()
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
        .defaultSize(width: 1120, height: 740)
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
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var battery = BatteryMonitor.shared

    var body: some View {
        let state = MenuBarIconState.resolve(enabled: settings.enabled, paused: model.isPaused,
                                             trusted: model.trusted, batteryPercent: battery.percent)
        Image(systemName: state.symbolName)
            .opacity(state == .disabled ? 0.4 : 1)
            .help(state.help)
            .onAppear {
                // İlk açılışta ana pencere (rehberle birlikte) kendiliğinden açılır.
                if !Settings.shared.onboardingCompleted {
                    DispatchQueue.main.async {
                        openWindow(id: "main")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            }
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

    /// Çimdikleme sürerken çıkılırsa açık büyütme hareketi "bitti" ile kapanır; kenar oturumu da kapanır.
    func applicationWillTerminate(_ notification: Notification) {
        GestureDispatcher.endPinchSession()
        GestureDispatcher.endEdgeSession()
    }

    /// Finder / Spotlight'tan yeniden açılınca ana pencereyi göster.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .merlinOpenMain, object: nil)
        return true
    }
}
