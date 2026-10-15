import SwiftUI
import MerlinCore

/// Ayarların düzenlendiği ana pencere.
struct MainWindow: View {
    enum Page: String, CaseIterable, Identifiable {
        case gestures, profiles, scroll, system, general
        var id: String { rawValue }
        var title: String {
            switch self {
            case .gestures: return "Hareketler"
            case .profiles: return "Uygulama profilleri"
            case .scroll: return "Kaydırma"
            case .system: return "Sistem hareketleri"
            case .general: return "Genel"
            }
        }
        var icon: String {
            switch self {
            case .gestures: return "hand.tap"
            case .profiles: return "square.stack"
            case .scroll: return "scroll"
            case .system: return "gearshape.2"
            case .general: return "gearshape"
            }
        }
    }

    @State private var page: Page? = .gestures
    @ObservedObject private var system = SystemGestureState.shared

    var body: some View {
        NavigationSplitView {
            List(Page.allCases, selection: $page) { p in
                HStack {
                    Label(p.title, systemImage: p.icon)
                    if p == .system {
                        Spacer()
                        Text("\(system.onCount)")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("\(system.onCount) açık")
                    }
                }
                .tag(p)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            detail
                .navigationTitle((page ?? .gestures).title)
        }
        .frame(minWidth: 900, minHeight: 600)
        .tint(.merlinAccent)
        .onAppear {
            system.refresh()
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @ViewBuilder private var detail: some View {
        switch page ?? .gestures {
        case .gestures: GesturesPage()
        case .profiles: ProfilesPage()
        case .scroll: ScrollPage()
        case .system: SystemPage()
        case .general: GeneralPage()
        }
    }
}
