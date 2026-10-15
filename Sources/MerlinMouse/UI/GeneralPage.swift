import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Genel ayarlar.
struct GeneralPage: View {
    @ObservedObject private var s = Settings.shared
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var battery = BatteryMonitor.shared
    @ObservedObject private var login = LoginItem.shared
    @State private var imageError: String?
    @State private var backupResult: (ok: Bool, text: String)?
    @State private var cloudBackups: [BackupManager.ICloudBackup] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MMPageHeader(title: L("Genel"), subtitle: L("Etkinlik, görünüm, bölge ve aygıt ayarları."))
                if let imageError {
                    MMBanner(kind: .warning, title: L("Görsel eklenemedi"), message: imageError,
                             actionTitle: L("Tamam")) { self.imageError = nil }
                }
                card(verbatim: "Merlin Mouse") {
                    MMSwitchRow(title: L("Etkin"), subtitle: L("Kapalıyken hiçbir hareket dönüştürülmez"), isOn: $s.enabled)
                    MMDivider()
                    MMSwitchRow(title: L("Girişte başlat"),
                                subtitle: L("Mac açıldığında Merlin Mouse kendiliğinden çalışır."),
                                isOn: Binding(get: { login.isEnabled }, set: { login.set($0) }))
                    if login.needsApproval {
                        HStack(spacing: 10) {
                            Text(L("Sistem Ayarları › Genel › Giriş Öğeleri'nde Merlin Mouse'a izin ver."))
                                .font(.system(size: 12)).foregroundStyle(MM.warnText)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            MMSecondaryButton(L("Ayarları aç")) { login.openSystemSettings() }
                        }
                        .padding(.horizontal, 20).padding(.bottom, 12)
                    }
                    if let err = login.errorText {
                        Text(err).font(.system(size: 12)).foregroundStyle(MM.warnText)
                            .padding(.horizontal, 20).padding(.bottom, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    MMDivider()
                    row(L("Karşılama rehberi"), L("İzin, fare tanıma ve ilk hareket için 3 adımlı rehber.")) {
                        MMSecondaryButton(L("Karşılama rehberini göster")) { model.showOnboarding = true }
                    }
                    MMDivider()
                    row(L("Görünüm"), L("Sistem, gündüz ya da gece")) {
                        Picker(L("Görünüm"), selection: $s.appearance) {
                            Text(L("Sistem")).tag("system")
                            Text(L("Gündüz")).tag("light")
                            Text(L("Gece")).tag("dark")
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 220)
                    }
                    MMDivider()
                    row(L("Dil"), L("Varsayılan olarak Mac'in dili kullanılır")) {
                        Picker(L("Dil"), selection: $s.language) {
                            Text(Localization.systemChoiceTitle).tag("system")
                            Text(Localization.nativeName(of: "tr")).tag("tr")
                            Text(Localization.nativeName(of: "en")).tag("en")
                        }
                        .pickerStyle(.menu).labelsHidden().frame(width: 220)
                    }
                    MMDivider()
                    MMSwitchRow(title: L("Ön / arka yönünü ters çevir"),
                                subtitle: L("Haritada ön taraf yukarıda görünmüyorsa aç"), isOn: $s.flipY)
                }
                card(L("Erişilebilirlik")) {
                    row(L("İzin"), L("Tıklamaları dönüştürmek için gerekir. Listede açık görünüyorsa ama çalışmıyorsa: uygulama yeniden derlendiği için eski kayıt geçersizdir.")) {
                        HStack(spacing: 10) {
                            statusChip(model.trusted ? L("Verildi") : L("Verilmedi"), ok: model.trusted)
                            MMSecondaryButton(L("Ayarları aç")) { model.openAccessibilitySettings() }
                            MMSecondaryButton(L("İzni sıfırla ve yeniden iste")) { model.resetAccessibilityPermission() }
                        }
                    }
                    if let help = model.permissionHelp {
                        Text(help).font(.system(size: 12)).foregroundStyle(MM.warnText)
                            .padding(.horizontal, 20).padding(.bottom, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                card(L("Fare görseli")) {
                    HStack(spacing: 16) {
                        MouseZoneMap(layout: .standard, image: model.mouseImage, width: 54, showLabels: false)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("Görsel yoksa çizilmiş fare gösterilir. Görsel yalnız bu Mac'te saklanır."))
                                .font(.system(size: 12.5)).foregroundStyle(MM.text2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                        MMSecondaryButton(L("Görsel seç…"), "photo") { pickImage() }
                        if model.mouseImage != nil {
                            MMSecondaryButton(L("Kaldır")) { model.removeMouseImage() }
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 14)
                }
                card(L("Aygıt")) {
                    row("Magic Mouse", model.deviceInfo.isEmpty ? L("Magic Mouse bulunamadı") : model.deviceInfo) {
                        MMSecondaryButton(L("Fareyi yeniden tara"), "arrow.clockwise") { model.startTouches() }
                    }
                    MMDivider()
                    row(L("Pil"), battery.lastRead.map { LF("Son okuma %@", Self.timeFormatter.string(from: $0)) }) {
                        HStack(spacing: 12) {
                            MMBatteryBadge(percent: battery.percent)
                            MMSecondaryButton(L("Pili şimdi oku")) { battery.refresh() }
                        }
                    }
                    MMDivider()
                    MMSwitchRow(title: L("Düşük pil bildirimleri"),
                                subtitle: L("Pil %20 ve %10'a düşünce bildirim gönderir."), isOn: $s.batteryAlertsEnabled)
                }
                card(L("Yedek")) {
                    if let r = backupResult {
                        MMBanner(kind: r.ok ? .info : .warning, title: r.text, actionTitle: L("Tamam")) {
                            backupResult = nil
                        }
                        .padding(.horizontal, 14).padding(.top, 12)
                    }
                    row(L("Dosya"), L("Atamalar ve ayarlar bir dosyaya yazılır. Fare görseli yedeğe girmez.")) {
                        HStack(spacing: 10) {
                            MMSecondaryButton(L("Dosyaya yedekle…")) { exportToFile() }
                            MMSecondaryButton(L("Dosyadan geri yükle…")) { importFromFile() }
                        }
                    }
                    MMDivider()
                    row("iCloud Drive", BackupManager.iCloudAvailable
                        ? L("Yedekler iCloud Drive'daki 'Merlin Mouse' klasörüne yazılır ve diğer Mac'lerine eşitlenir.")
                        : L("iCloud Drive kapalı")) {
                        HStack(spacing: 10) {
                            MMSecondaryButton(L("iCloud Drive'a yedekle")) { exportToICloud() }
                                .disabled(!BackupManager.iCloudAvailable)
                            Menu(L("iCloud Drive'dan geri yükle")) {
                                if cloudBackups.isEmpty {
                                    Text(L("Yedek bulunamadı"))
                                } else {
                                    ForEach(cloudBackups) { b in
                                        Button("\(b.name) · \(Self.dateFormatter.string(from: b.date))") {
                                            restore(from: b.url)
                                        }
                                    }
                                }
                            }
                            .menuStyle(.button).fixedSize()
                            .disabled(!BackupManager.iCloudAvailable)
                            .onAppear { cloudBackups = BackupManager.latestICloudBackups() }
                        }
                    }
                }
                card(L("Uygulama")) {
                    row(L("Kayıt dosyası"), "~/Library/Logs/MerlinMouse.log") {
                        MMSecondaryButton(L("Kayıt dosyasını Finder'da göster")) {
                            let url = FileManager.default.homeDirectoryForCurrentUser
                                .appendingPathComponent("Library/Logs/MerlinMouse.log")
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                    MMDivider()
                    row(L("Sürüm"), nil) {
                        Text(version).font(.system(size: 13, design: .monospaced)).foregroundStyle(MM.text2)
                    }
                }
            }
            .padding(.horizontal, 32).padding(.vertical, 28)
        }
        .onAppear { login.refresh() }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private func exportToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: BackupManager.fileExtension) ?? .json]
        panel.nameFieldStringValue = BackupManager.defaultFileName()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try BackupManager.exportTo(url: url)
            backupResult = (true, LF("Yedek yazıldı: %@", url.lastPathComponent))
        } catch {
            backupResult = (false, error.localizedDescription)
        }
    }

    private func importFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: BackupManager.fileExtension) ?? .json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        restore(from: url)
    }

    private func exportToICloud() {
        do {
            let url = try BackupManager.exportToICloud()
            cloudBackups = BackupManager.latestICloudBackups()
            backupResult = (true, LF("iCloud Drive'a yazıldı: %@", url.lastPathComponent))
        } catch {
            backupResult = (false, error.localizedDescription)
        }
    }

    /// Onay alır, sonra geri yükler; önceki hâl BackupManager tarafından otomatik yedeklenir.
    private func restore(from url: URL) {
        let alert = NSAlert()
        alert.messageText = L("Geri yüklensin mi?")
        alert.informativeText = L("Geçerli atamalar ve ayarlar değiştirilecek. Önceki hâl otomatik yedeklenir.")
        alert.addButton(withTitle: L("Geri yükle"))
        alert.addButton(withTitle: L("Vazgeç"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try BackupManager.importFrom(url: url)
            backupResult = (true, L("Yedek geri yüklendi."))
        } catch {
            backupResult = (false, error.localizedDescription)
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = L("Magic Mouse görselini seç")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.importMouseImage(from: url)
            imageError = nil
        } catch {
            imageError = error.localizedDescription
        }
    }

    private func card<C: View>(verbatim title: String, @ViewBuilder _ content: () -> C) -> some View {
        card(title, content)
    }

    private func card<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        let body = content()
        return MMCard {
            VStack(spacing: 0) {
                Text(verbatim: title).font(.system(size: 12, weight: .semibold)).foregroundStyle(MM.text)
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
