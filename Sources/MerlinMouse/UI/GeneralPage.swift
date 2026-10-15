import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Genel ayarlar.
struct GeneralPage: View {
    @ObservedObject private var s = Settings.shared
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var battery = BatteryMonitor.shared
    @State private var imageError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MMPageHeader(title: "Genel", subtitle: "Etkinlik, görünüm, bölge ve aygıt ayarları.")
                if let imageError {
                    MMBanner(kind: .warning, title: "Görsel eklenemedi", message: imageError,
                             actionTitle: "Tamam") { self.imageError = nil }
                }
                card("Merlin Mouse") {
                    MMSwitchRow(title: "Etkin", subtitle: "Kapalıyken hiçbir hareket dönüştürülmez", isOn: $s.enabled)
                    MMDivider()
                    row("Görünüm", "Sistem, gündüz ya da gece") {
                        Picker("Görünüm", selection: $s.appearance) {
                            Text("Sistem").tag("system")
                            Text("Gündüz").tag("light")
                            Text("Gece").tag("dark")
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 220)
                    }
                    MMDivider()
                    MMSwitchRow(title: "Ön / arka yönünü ters çevir",
                                subtitle: "Haritada ön taraf yukarıda görünmüyorsa aç", isOn: $s.flipY)
                }
                card("Erişilebilirlik") {
                    row("İzin", "Tıklamaları dönüştürmek için gerekir. Listede açık görünüyorsa ama çalışmıyorsa: uygulama yeniden derlendiği için eski kayıt geçersizdir.") {
                        HStack(spacing: 10) {
                            statusChip(model.trusted ? "Verildi" : "Verilmedi", ok: model.trusted)
                            MMSecondaryButton("Ayarları aç") { model.openAccessibilitySettings() }
                            MMSecondaryButton("İzni sıfırla ve yeniden iste") { model.resetAccessibilityPermission() }
                        }
                    }
                    if let help = model.permissionHelp {
                        Text(help).font(.system(size: 12)).foregroundStyle(MM.warnText)
                            .padding(.horizontal, 20).padding(.bottom, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                card("Fare görseli") {
                    HStack(spacing: 16) {
                        MouseZoneMap(layout: .standard, image: model.mouseImage, width: 54, showLabels: false)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Görsel yoksa çizilmiş fare gösterilir. Görsel yalnız bu Mac'te saklanır.")
                                .font(.system(size: 12.5)).foregroundStyle(MM.text2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                        MMSecondaryButton("Görsel seç…", "photo") { pickImage() }
                        if model.mouseImage != nil {
                            MMSecondaryButton("Kaldır") { model.removeMouseImage() }
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 14)
                }
                card("Aygıt") {
                    row("Magic Mouse", model.deviceInfo.isEmpty ? "Magic Mouse bulunamadı" : model.deviceInfo) {
                        MMSecondaryButton("Fareyi yeniden tara", "arrow.clockwise") { model.startTouches() }
                    }
                    MMDivider()
                    row("Pil", battery.lastRead.map { "Son okuma \(Self.timeFormatter.string(from: $0))" }) {
                        HStack(spacing: 12) {
                            MMBatteryBadge(percent: battery.percent)
                            MMSecondaryButton("Pili şimdi oku") { battery.refresh() }
                        }
                    }
                    MMDivider()
                    MMSwitchRow(title: "Düşük pil bildirimleri",
                                subtitle: "Pil %20 ve %10'a düşünce bildirim gönderir.", isOn: $s.batteryAlertsEnabled)
                }
                card("Uygulama") {
                    row("Kayıt dosyası", "~/Library/Logs/MerlinMouse.log") {
                        MMSecondaryButton("Kayıt dosyasını Finder'da göster") {
                            let url = FileManager.default.homeDirectoryForCurrentUser
                                .appendingPathComponent("Library/Logs/MerlinMouse.log")
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                    MMDivider()
                    row("Sürüm", nil) {
                        Text(version).font(.system(size: 13, design: .monospaced)).foregroundStyle(MM.text2)
                    }
                }
            }
            .padding(.horizontal, 32).padding(.vertical, 28)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Magic Mouse görselini seç"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.importMouseImage(from: url)
            imageError = nil
        } catch {
            imageError = error.localizedDescription
        }
    }

    private func card<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        let body = content()
        return MMCard {
            VStack(spacing: 0) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(MM.text)
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MM.card2)
                    .overlay(alignment: .bottom) { Rectangle().fill(MM.line).frame(height: 1) }
                body
            }
        }
    }

    private func row<C: View>(_ title: String, _ subtitle: String?, @ViewBuilder _ control: () -> C) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13.5, weight: .medium)).foregroundStyle(MM.text)
                if let subtitle {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(MM.text2).lineLimit(2)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 12)
            control()
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    private func statusChip(_ text: String, ok: Bool) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ok ? MM.accentText : MM.warnText)
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(ok ? MM.accentSoft : MM.warnBg, in: Capsule())
    }
}
