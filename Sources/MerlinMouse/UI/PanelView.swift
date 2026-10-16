import SwiftUI
import MerlinCore

/// Menü çubuğundan açılan panel: durum, hızlı anahtarlar, görünüm ve kısayollar.
/// Harita, tüm atamalar ve gelişmiş ayarlar ana pencerededir.
struct PanelView: View {
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var s = Settings.shared
    @ObservedObject private var front = FrontApp.shared
    @ObservedObject private var battery = BatteryMonitor.shared
    @ObservedObject private var bindingStore = BindingStore.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 10) {
                if !model.trusted {
                    MMBanner(kind: .warning, title: L("Erişilebilirlik izni gerekli"),
                             actionTitle: L("Ayarları aç")) {
                        // Panel, açılan Sistem Ayarları'nın önünde kalmasın.
                        NSApp.keyWindow?.close()
                        model.requestPermission()
                    }
                }
                if model.isPaused, let until = s.pausedUntil {
                    MMBanner(kind: .info, title: LF("%@'e kadar duraklatıldı", Self.timeText(until)),
                             actionTitle: L("Devam et")) { model.resume() }
                }
            }
            .padding(.horizontal, 16).padding(.top, model.trusted && !model.isPaused ? 0 : 12)
            profileSection
            quickToggles
            appearanceSection
            warningLinks
            footer
        }
        .frame(width: 380)
        .background(MM.win)
        .tint(MM.accent)
        // Dil değişince panel yeniden kurulur.
        .id(s.language)
    }

    // MARK: Başlık

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MM.accent)
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "magicmouse").font(.system(size: 20, weight: .medium)).foregroundStyle(MM.accentInk))
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "Merlin Mouse").font(.system(size: 14, weight: .semibold)).foregroundStyle(MM.text)
                HStack(spacing: 8) {
                    Text(model.miceCount > 0 ? L("Magic Mouse bağlı") : L("Magic Mouse bulunamadı"))
                        .font(.system(size: 12)).foregroundStyle(MM.text2)
                    if model.miceCount > 0 { MMBatteryBadge(percent: battery.percent) }
                }
            }
            Spacer()
            MMSwitch(isOn: $s.enabled, label: "Merlin Mouse")
        }
        .padding(16)
        .overlay(alignment: .bottom) { MMDivider() }
    }

    // MARK: Etkin profil

    private var hasScopedSetup: Bool {
        guard let id = front.bundleID else { return false }
        return bindingStore.profiles.contains { $0.bundleID == id }
            || bindingStore.bindings.contains { $0.appBundleID == id }
    }

    private var profileSection: some View {
        let appName = front.name.isEmpty ? "—" : front.name
        return VStack(alignment: .leading, spacing: 10) {
            MMSectionLabel(L("Etkin profil"))
            MMCard {
                HStack(spacing: 10) {
                    AppIconView(bundleID: front.bundleID, name: appName, size: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(appName).font(.system(size: 14, weight: .medium)).foregroundStyle(MM.text).lineLimit(1)
                        Text(hasScopedSetup ? L("Bu uygulamanın profili etkin") : L("Genel atamalar · öndeki uygulamadan algılandı"))
                            .font(.system(size: 12)).foregroundStyle(MM.text2).lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    if front.is3D {
                        Text("3D").font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(MM.accentSoft, in: Capsule())
                            .foregroundStyle(MM.accentText)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
            }
            HStack(spacing: 8) {
                Circle().fill(MM.accent).frame(width: 8, height: 8)
                Text(L("Son eylem: ")).font(.system(size: 13)).foregroundStyle(MM.text)
                    + Text(model.lastAction ?? L("Henüz yok")).font(.system(size: 13, weight: .medium)).foregroundStyle(MM.text)
            }
            .lineLimit(1)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .overlay(alignment: .bottom) { MMDivider() }
    }

    // MARK: Hızlı anahtarlar

    private var globalCenterPress: GestureBinding? {
        bindingStore.bindings.first {
            $0.appBundleID == nil && $0.trigger.normalized == Trigger(kind: .press, fingers: 1, zone: .center)
        }
    }

    private var globalThreeFingerPress: GestureBinding? {
        bindingStore.bindings.first {
            $0.appBundleID == nil && $0.trigger.kind == .press && $0.trigger.fingers == 3 && $0.trigger.modifier == .none
        }
    }

    private var quickToggles: some View {
        VStack(spacing: 0) {
            if let b = globalCenterPress { bindingRow(L("Orta bölge sürükleme"), b) }
            if let b = globalThreeFingerPress { bindingRow(L("Üç parmakla orta tıklama"), b) }
            toggleRow(L("3D yakınlaştırma düzeltmesi"), $s.calm3DScroll)
        }
        .padding(.horizontal, 8).padding(.vertical, 10)
        .overlay(alignment: .bottom) { MMDivider() }
    }

    private func bindingRow(_ title: String, _ b: GestureBinding) -> some View {
        toggleRow(title, Binding(get: { b.enabled }, set: { bindingStore.setEnabled(id: b.id, $0) }))
    }

    private func toggleRow(_ title: String, _ value: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Text(title).font(.system(size: 14)).foregroundStyle(MM.text)
            Spacer(minLength: 8)
            MMSwitch(isOn: value, label: title)
        }
        .padding(8)
        .frame(minHeight: 44)
    }

    // MARK: Görünüm

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MMSectionLabel(L("Görünüm"))
            HStack(spacing: 2) {
                ForEach([("system", L("Sistem")), ("light", L("Gündüz")), ("dark", L("Gece"))], id: \.0) { id, label in
                    let on = s.appearance == id
                    Button { s.appearance = id } label: {
                        Text(label)
                            .font(.system(size: 12.5, weight: on ? .semibold : .regular))
                            .foregroundStyle(on ? MM.text : MM.text2)
                            .frame(maxWidth: .infinity).frame(height: 28)
                            .background(on ? MM.card : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .shadow(color: on ? .black.opacity(0.18) : .clear, radius: 1, y: 1)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(3)
            .background(MM.neuBg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .padding(.horizontal, 16).padding(.top, 12)
    }

    // MARK: Uyarı bağlantıları

    @ViewBuilder private var warningLinks: some View {
        if let btt = model.warnings.first(where: { $0.source == .btt }) {
            linkRow(btt.title, icon: "arrow.left.arrow.right", bg: MM.bttBg, fg: MM.bttText) { openPage(.gestures) }
        }
    }

    private func linkRow(_ text: String, icon: String, bg: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                Text(text).font(.system(size: 13)).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16).padding(.top, 12)
    }

    // MARK: Alt menü

    private var footer: some View {
        VStack(spacing: 0) {
            menuRow(L("Ayarlar…"), shortcut: "⌘ ,") { openPage(nil) }
                .keyboardShortcut(",", modifiers: .command)
            if model.isPaused {
                menuRow(L("Devam et"), shortcut: nil) { model.resume() }
            } else {
                menuRow(L("1 saat duraklat"), shortcut: nil) { model.pause(for: 3600) }
            }
            menuRow(L("Merlin Mouse'tan çık"), shortcut: "⌘ Q") { NSApp.terminate(nil) }
        }
        .padding(8)
        .overlay(alignment: .top) { MMDivider() }
        .padding(.top, 12)
    }

    private func menuRow(_ title: String, shortcut: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 14)).foregroundStyle(MM.text)
                Spacer()
                if let shortcut {
                    Text(shortcut).font(.system(size: 13, design: .monospaced)).foregroundStyle(MM.text2)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Yardımcılar

    private func openPage(_ page: MainWindow.Page?) {
        model.openMainWindow(page: page?.rawValue)
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
