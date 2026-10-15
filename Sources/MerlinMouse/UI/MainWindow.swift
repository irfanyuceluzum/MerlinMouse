import SwiftUI
import MerlinCore

/// Ayarların düzenlendiği ana pencere.
struct MainWindow: View {
    enum Page: String, CaseIterable, Identifiable {
        case gestures, profiles, scroll, system, migration, general
        var id: String { rawValue }
        var title: String {
            switch self {
            case .gestures: return L("Hareketler")
            case .profiles: return L("Uygulama profilleri")
            case .scroll: return L("Kaydırma")
            case .system: return L("Sistem hareketleri")
            case .migration: return L("BTT'den geçiş")
            case .general: return L("Genel")
            }
        }
        var icon: String {
            switch self {
            case .gestures: return "computermouse"
            case .profiles: return "square.grid.2x2"
            case .scroll: return "arrow.up.and.down"
            case .system: return "shield"
            case .migration: return "arrow.left.arrow.right"
            case .general: return "gearshape"
            }
        }
    }

    @State private var page: Page = .gestures
    @ObservedObject private var system = SystemGestureState.shared
    @ObservedObject private var battery = BatteryMonitor.shared
    @ObservedObject private var front = FrontApp.shared
    @ObservedObject private var store = BindingStore.shared
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        // Dil değişince kenar çubuğu ve sayfa yeniden kurulur; seçili sayfa (`page`) korunur,
        // yaşam döngüsü işleyicileri kapsayıcıya bağlı olduğundan yeniden tetiklenmez.
        ZStack {
            HStack(spacing: 0) {
                sidebar
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(MM.win)
            }
            .id(settings.language)
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(MM.win)
        .tint(MM.accent)
        .onAppear {
            system.refresh()
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
        // Panelden gelen sayfa isteği (pencere açıkken de, yeni açılırken de çalışır).
        .onReceive(model.$requestedPage) { raw in
            guard let raw, let p = Page(rawValue: raw) else { return }
            page = p
            model.requestedPage = nil
        }
    }

    // MARK: Kenar çubuğu

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Page.allCases) { p in row(p) }
            Spacer(minLength: 12)
            statusCard
        }
        .padding(.horizontal, 12).padding(.vertical, 18)
        .frame(width: 224)
        .frame(maxHeight: .infinity)
        .background(MM.side)
        .overlay(alignment: .trailing) { Rectangle().fill(MM.line).frame(width: 1) }
    }

    private func row(_ p: Page) -> some View {
        let selected = p == page
        return Button { page = p } label: {
            HStack(spacing: 10) {
                Image(systemName: p.icon).font(.system(size: 14, weight: .regular)).frame(width: 18)
                Text(p.title).font(.system(size: 13, weight: selected ? .medium : .regular))
                    .lineLimit(1).minimumScaleFactor(0.85)
                Spacer(minLength: 4)
                if p == .system, system.onCount > 0 {
                    Text("\(system.onCount)")
                        .font(.system(size: 11.5, weight: .semibold))
                        .padding(.horizontal, 7).padding(.vertical, 1)
                        .fixedSize()
                        .background(MM.warnBg, in: Capsule())
                        .foregroundStyle(MM.warnText)
                        .accessibilityLabel(LF("%lld açık", system.onCount))
                }
            }
            .foregroundStyle(selected ? MM.accentInk : MM.text)
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(selected ? MM.accent : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var statusCard: some View {
        let profile = store.profiles.first { front.bundleID != nil && $0.bundleID == front.bundleID }
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(MM.okDot).frame(width: 7, height: 7)
                Text(profile.map { LF("%@ profili etkin", $0.name) } ?? L("Genel atamalar etkin"))
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(MM.text)
            }
            if profile != nil {
                Text(L("Öndeki uygulamadan algılandı")).font(.system(size: 12)).foregroundStyle(MM.text2)
            }
            HStack(spacing: 6) {
                Text(verbatim: "Magic Mouse").font(.system(size: 12)).foregroundStyle(MM.text2)
                MMBatteryBadge(percent: battery.percent)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MM.card, in: shape)
        .overlay(shape.strokeBorder(MM.line, lineWidth: 1))
    }

    @ViewBuilder private var detail: some View {
        switch page {
        case .gestures: GesturesPage()
        case .profiles: ProfilesPage()
        case .scroll: ScrollPage()
        case .system: SystemPage()
        case .migration: MigrationPage()
        case .general: GeneralPage()
        }
    }
}
