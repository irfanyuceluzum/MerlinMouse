import SwiftUI
import AppKit

/// Genel ayarlar.
struct GeneralPage: View {
    @ObservedObject private var s = Settings.shared
    @ObservedObject private var model = AppModel.shared

    var body: some View {
        Form {
            Section {
                Toggle("Etkin", isOn: $s.enabled)
                Picker("Görünüm", selection: $s.appearance) {
                    Text("Sistem").tag("system")
                    Text("Gündüz").tag("light")
                    Text("Gece").tag("dark")
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("Orta bölge genişliği")
                    Slider(value: $s.zoneWidth, in: 0.15...0.45)
                    Text("%\(Int(s.zoneWidth * 100))").monospacedDigit().foregroundStyle(.secondary)
                }
                Toggle("Ön / arka yönünü ters çevir", isOn: $s.flipY)
            }
            Section("Erişilebilirlik") {
                LabeledContent("İzin", value: model.trusted ? "Verildi" : "Verilmedi")
                if !model.trusted {
                    Button("Ayarları aç") { model.openAccessibilitySettings() }
                }
            }
            Section("Aygıt") {
                Text(model.deviceInfo.isEmpty ? "Magic Mouse bulunamadı" : model.deviceInfo)
                    .font(.callout.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                Button("Fareyi yeniden tara") { model.startTouches() }
            }
            Section("Uygulama") {
                Button("Kayıt dosyasını Finder'da göster") {
                    let url = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent("Library/Logs/MerlinMouse.log")
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                LabeledContent("Sürüm", value: version)
            }
        }
        .formStyle(.grouped)
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}
