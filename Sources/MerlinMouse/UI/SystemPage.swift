import SwiftUI
import AppKit
import MerlinCore

/// Sistem hareketleri durumu; kenar çubuğu rozeti ve sayfa aynı veriyi kullanır.
final class SystemGestureState: ObservableObject {
    static let shared = SystemGestureState()
    @Published private(set) var rows: [SystemGestureRow] = []
    @Published private(set) var trackpadSections: [TrackpadGestureSection] = []
    private var env = ConflictEnvironment()
    /// Rozet: açık macOS fare hareketleri; açık bir trackpad ataması varsa trackpad çakışmaları da.
    var onCount: Int {
        let mouse = SystemGestureCatalog.conflictCount(env: env)
        guard BindingStore.shared.index.hasAnyBinding(device: .trackpad) else { return mouse }
        return mouse + TrackpadGestureCatalog.conflictCount(env: env)
    }

    func refresh() {
        env = AppModel.shared.conflictEnvironment()
        rows = SystemGestureCatalog.rows(env: env)
        trackpadSections = TrackpadGestureCatalog.sections(env: env)
    }
}

/// macOS'un fare ve trackpad hareketleri ve Merlin Mouse ile ilişkileri.
struct SystemPage: View {
    @ObservedObject private var state = SystemGestureState.shared
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var settings = Settings.shared
    /// Düzenlenen aygıt üst çubuktaki seçiciden gelir.
    private var device: InputDeviceKind { settings.editingDevice }

    private func isKeyboard(_ r: SystemGestureRow) -> Bool {
        r.gesture.hasPrefix("⌃") || r.gesture.hasPrefix("⌘") || r.gesture == "BetterTouchTool"
    }

    private var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    var body: some View {
        let trackpad = device == .trackpad
        VStack(alignment: .leading, spacing: 16) {
            MMPageHeader(title: L("macOS sistem hareketleri"),
                         subtitle: trackpad
                            ? L("Apple'ın trackpad için ayırdığı hareketler. Açık olanlara atama yapılırsa Merlin Mouse uyarır.")
                            : L("Apple'ın Magic Mouse için ayırdığı hareketler. Açık olanlara atama yapılırsa Merlin Mouse uyarır.")) {
                HStack(spacing: 8) {
                    MMSecondaryButton(L("Yeniden tara"), "arrow.clockwise") { state.refresh() }
                    MMPrimaryButton(trackpad ? L("Sistem Ayarları › Trackpad") : L("Sistem Ayarları › Fare")) {
                        let pane = trackpad ? "com.apple.Trackpad-Settings.extension" : "com.apple.Mouse-Settings.extension"
                        if let url = URL(string: "x-apple.systempreferences:\(pane)") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            DevicePassiveBanner()
            statusStrip
            otherAppBanners
            if trackpad { trackpadTable } else { table }
        }
        .padding(.horizontal, 32).padding(.vertical, 28)
        .onAppear { state.refresh() }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in state.refresh() }
    }

    private var trackpadName: String {
        let p = model.devicePresence
        if !p.isPresent(.trackpad) { return L("Trackpad bağlı değil") }
        return p.builtInTrackpad ? L("Dahili trackpad") : InputDeviceKind.trackpad.displayName
    }

    private var statusStrip: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return HStack(spacing: 10) {
            Circle().fill(MM.okDot).frame(width: 8, height: 8)
            Group {
                if device == .trackpad {
                    Text(LF("Bu Mac'ten okundu · %@ · Ayarlar değişince liste kendiliğinden güncellenir", trackpadName))
                } else {
                    Text(LF("Bu Mac'ten okundu · macOS %@ · Magic Mouse %@ · Ayarlar değişince liste kendiliğinden güncellenir",
                            osVersion, model.miceCount > 0 ? L("bağlı") : L("bağlı değil")))
                }
            }
            .font(.system(size: 13)).foregroundStyle(MM.text2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(MM.card, in: shape)
        .overlay(shape.strokeBorder(MM.line, lineWidth: 1))
    }

    /// Çalışan diğer fare uygulamaları için birer turuncu şerit; yoksa hiçbir şey.
    @ViewBuilder private var otherAppBanners: some View {
        ForEach(model.warnings.filter { $0.source == .otherApp }) { w in
            MMBanner(kind: .warning, title: w.title, message: w.detail,
                     actionTitle: w.bundleID == nil ? nil : L("Uygulamayı göster")) {
                if let id = w.bundleID { SystemCheck.activateApp(bundleID: id) }
            }
        }
    }

    private var table: some View {
        MMCard {
            VStack(spacing: 0) {
                gridRow {
                    MMSectionLabel(L("Hareket")); MMSectionLabel(L("macOS görevi"))
                    MMSectionLabel(L("Bu Mac'te")); MMSectionLabel(L("Merlin Mouse için"))
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(MM.line).frame(height: 1) }
                ScrollView {
                    VStack(spacing: 0) {
                        group(L("Fare ayarları"), state.rows.filter { !isKeyboard($0) })
                        group(L("Klavye + fare"), state.rows.filter { isKeyboard($0) })
                    }
                }
                Spacer(minLength: 0)
                freeStrip(L("macOS'un Magic Mouse'ta kullanmadığı, serbest hareketler"), SystemGestureCatalog.freeGestures)
            }
        }
    }

    /// Trackpad sekmesi: `TrackpadGestureCatalog` bölümleri, aynı dört sütun.
    private var trackpadTable: some View {
        MMCard {
            VStack(spacing: 0) {
                gridRow {
                    MMSectionLabel(L("Hareket")); MMSectionLabel(L("macOS görevi"))
                    MMSectionLabel(L("Bu Mac'te")); MMSectionLabel(L("Merlin Mouse için"))
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(MM.line).frame(height: 1) }
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(state.trackpadSections, id: \.title) { s in
                            group(s.title, s.rows, trackpad: true)
                        }
                    }
                }
                Spacer(minLength: 0)
                freeStrip(L("macOS'un trackpad'de kullanmadığı, serbest hareketler"), TrackpadGestureCatalog.freeGestures)
            }
        }
    }

    /// 1.6 / 1.6 / 1 / 1.7 oranlı dört sütunlu satır.
    private func gridRow<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        FourColumnLayout { content() }
            .padding(.horizontal, 20)
    }

    private func group(_ title: String, _ rows: [SystemGestureRow], trackpad: Bool = false) -> some View {
        VStack(spacing: 0) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(MM.text)
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MM.card2)
            ForEach(rows) { r in
                gridRow {
                    Text(r.gesture)
                        .font(isKeyboard(r) && r.gesture != "BetterTouchTool"
                              ? .system(size: 13, weight: .medium, design: .monospaced)
                              : .system(size: 13.5, weight: .medium))
                        .foregroundStyle(MM.text)
                    Text(r.task).font(.system(size: 13.5)).foregroundStyle(MM.text)
                    chip(r.status)
                    Text(r.note).font(.system(size: 13)).foregroundStyle(trackpad ? trackpadNoteColor(r) : noteColor(r))
                }
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) { Rectangle().fill(MM.line2).frame(height: 1) }
            }
        }
    }

    private func noteColor(_ r: SystemGestureRow) -> Color {
        switch r.status {
        case .on, .always:
            // Çevrilmiş metinde arama yapmak yerine kataloğun "engellenir" notuyla karşılaştırılır.
            return r.note == L("Orta tuşla sürüklerken engellenir") ? MM.accentText : MM.warnText
        case .appLevel: return MM.bttText
        case .off: return MM.text2
        }
    }

    /// Trackpad: yalnız açık ve çakışabilen satırlar uyarı rengiyle; bilgi satırları soluk.
    private func trackpadNoteColor(_ r: SystemGestureRow) -> Color {
        r.isConfigurable && r.status == .on ? MM.warnText : MM.text2
    }

    private func chip(_ status: SystemGestureStatus) -> some View {
        let spec: (String, Color, Color)
        switch status {
        case .on: spec = (L("Açık"), MM.warnBg, MM.warnText)
        case .off: spec = (L("Kapalı"), MM.neuBg, MM.neuText)
        case .always: spec = (L("Her zaman"), MM.warnBg, MM.warnText)
        case .appLevel: spec = (L("Uygulama içi"), MM.bttBg, MM.bttText)
        }
        return Text(spec.0).font(.system(size: 12, weight: .semibold)).foregroundStyle(spec.2)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(spec.1, in: Capsule())
    }

    private func freeStrip(_ title: String, _ gestures: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(MM.accentText)
            FlowLayout(spacing: 8) {
                ForEach(gestures, id: \.self) { g in
                    Text(g).font(.system(size: 13)).foregroundStyle(MM.text)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(MM.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(MM.accentLine, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MM.accentSoft)
        .overlay(alignment: .top) { Rectangle().fill(MM.line).frame(height: 1) }
    }
}

extension SystemGestureRow: Identifiable {
    public var id: String { gesture }
}

/// 1.6 / 1.6 / 1 / 1.7 oranlı dört sütun, 12 pt boşluk, dikeyde ortalı.
struct FourColumnLayout: Layout {
    private let weights: [CGFloat] = [1.6, 1.6, 1, 1.7]

    private func widths(_ total: CGFloat) -> [CGFloat] {
        let avail = max(0, total - 12 * 3)
        let sum = weights.reduce(0, +)
        return weights.map { avail * $0 / sum }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let total = proposal.width ?? 600
        let w = widths(total)
        var h: CGFloat = 0
        for (i, v) in subviews.enumerated() where i < 4 {
            h = max(h, v.sizeThatFits(ProposedViewSize(width: w[i], height: nil)).height)
        }
        return CGSize(width: total, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let w = widths(bounds.width)
        var x = bounds.minX
        for (i, v) in subviews.enumerated() where i < 4 {
            let size = v.sizeThatFits(ProposedViewSize(width: w[i], height: nil))
            v.place(at: CGPoint(x: x, y: bounds.midY - size.height / 2), anchor: .topLeading,
                    proposal: ProposedViewSize(width: w[i], height: nil))
            x += w[i] + 12
        }
    }
}

/// Satırlara sarılan basit akış düzeni.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 600, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = arrange(width: bounds.width, subviews: subviews)
        for (i, f) in r.frames.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY),
                              anchor: .topLeading, proposal: ProposedViewSize(f.size))
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxW: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0, x + s.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
            maxW = max(maxW, x - spacing)
        }
        return (frames, CGSize(width: maxW, height: y + rowH))
    }
}
