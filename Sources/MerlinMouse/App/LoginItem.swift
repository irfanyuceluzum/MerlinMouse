import Foundation
import Combine
import ServiceManagement

/// "Girişte başlat": SMAppService.mainApp ile kayıt; durum her zaman sistemden okunur.
final class LoginItem: ObservableObject {
    static let shared = LoginItem()

    @Published private(set) var isEnabled = false
    @Published private(set) var needsApproval = false
    @Published private(set) var errorText: String?

    private init() { refresh() }

    /// Durumu `SMAppService.mainApp.status`'tan okur.
    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = (status == .enabled)
        needsApproval = (status == .requiresApproval)
    }

    func set(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorText = nil
            Log.write("Girişte başlat: \(on ? "açıldı" : "kapatıldı")")
        } catch {
            errorText = error.localizedDescription
            Log.write("Girişte başlat değiştirilemedi: \(error.localizedDescription)")
        }
        refresh()
    }

    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
