import SwiftUI
import MerlinCore

/// Bölgeler: bölge sınırlarının ve kenar şeritlerinin TEK düzenleme yeri; parmakların bölgelerde nasıl
/// algılandığını ve hangi hareketin tetiklendiğini de canlı gösterir (kuru deneme dahil).
/// Trackpad seçiliyken solda canlı trackpad haritası (bölge yok), sağda aynı kuru deneme ve günlük; parmak satırları
/// trackpad parmaklarını gösterir.
struct TestModePage: View {
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var s = Settings.shared
    /// Trackpad parmakları (yalnız canlı harita görünürken yayınlanır).
    @ObservedObject private var live = TrackpadLiveTouches.shared
    @State private var dryRun = false

    private var trackpad: Bool { s.editingDevice == .trackpad }
    @State private var twoButton = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .medium
        f.dateStyle = .none
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MMPageHeader(title: L("Bölgeler"),
                             subtitle: trackpad
                                ? L("Trackpad'deki parmakları canlı izle ve hangi hareketin tetiklendiğini dene.")
                                : L("Tüm bölgeleri tek haritada ayarla: sınırları ve kenar şeritlerini sürükle, parmaklarınla hemen dene."))
                DevicePassiveBanner()
                if !model.trusted {
                    MMBanner(kind: .warning, title: L("Erişilebilirlik izni gerekli"),
                             actionTitle: L("Ayarları aç")) { model.requestPermission() }
                }
                HStack(alignment: .top, spacing: 20) {
                    if trackpad { TrackpadZonesCard() } else { mapCard }
                    VStack(spacing: 16) {
                        MMCard {
                            MMSwitchRow(title: L("Kuru deneme"),
                                        subtitle: L("Eylemleri çalıştırmadan yalnız neyin tetikleneceğini gösterir."),
                                        isOn: $dryRun)
                        }
                        fingersCard
                        logCard
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 32).padding(.vertical, 28)
        }
        .onAppear {
            dryRun = false
            InputState.shared.dryRun = false
            twoButton = AppModel.shared.conflictEnvironment().mouseButtonMode == "TwoButton"
        }
        .onChange(of: dryRun) { _, on in InputState.shared.dryRun = on }
        .onDisappear { InputState.shared.dryRun = false }
    }

    /// Tek düzenleme haritası: bölge sınırları, orta yükseklik, arka sınırı ve kenar şeritlerinin uçları ve
    /// genişliği sürüklenir; altında yüzde ölçüler ve "Varsayılana dön".
    private var mapCard: some View {
        let r = ZoneReadout(layout: s.zoneLayout, edgeWidth: s.edgeWidth, edgeBounds: s.edgeBounds)
        return MMCard(padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                MouseZoneMap(touches: model.liveTouches, layout: s.zoneLayout, editable: true, flipped: s.flipY,
                             image: model.mouseImage, secondaryRightZone: twoButton, width: 220,
                             showEdges: true, edgeEditable: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LF("Sol %lld · Orta %lld · Sağ %lld", r.left, r.center, r.right))
                    Text(LF("Arka %lld · Orta yükseklik %lld (yüzde)", r.rear, r.centerHeight))
                        .foregroundStyle(MM.text2)
                    Text(LF("Kenar genişliği %lld · Kenar aralığı %lld–%lld (yüzde)", r.edgeWidth, r.edgeBottom, r.edgeTop))
                        .foregroundStyle(MM.text2)
                }
                .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(MM.text)
                .lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 10) {
                    Button { s.resetZoneLayout() } label: {
                        Text(L("Varsayılana dön")).font(.system(size: 12))
                            .foregroundStyle(MM.text)
                            .padding(.horizontal, 10).frame(height: 26)
                            .background(MM.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(MM.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help(L("Bölgeleri ve kenar şeritlerini varsayılan boyutlarına döndürür"))
                    Text(L("Kapalı kenarlar soluk çizilir.")).font(.system(size: 12)).foregroundStyle(MM.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 220)
        }
    }

    /// Kartta her zaman gösterilen parmak satırı sayısı (Magic Mouse en fazla 5 parmak).
    private static let fingerSlots = 5
    private static let fingerRowHeight: CGFloat = 30

    private var fingersCard: some View {
        // Kimliğe göre kararlı sıra: aynı parmak satır değiştirmez; fazlası gösterilmez.
        let source = trackpad ? live.touches : model.liveTouches
        let touches = Array(source.sorted { $0.id < $1.id }.prefix(Self.fingerSlots))
        return MMCard {
            VStack(spacing: 0) {
                HStack {
                    Text(L("Parmaklar")).font(.system(size: 12, weight: .semibold)).foregroundStyle(MM.text)
                    Spacer(minLength: 8)
                    Text(verbatim: "\(touches.count) / \(Self.fingerSlots)")
                        .font(.system(size: 12, design: .monospaced)).foregroundStyle(MM.text2)
                }
                .padding(.horizontal, 20).padding(.vertical, 8)
                .background(MM.card2)
                .overlay(alignment: .bottom) { Rectangle().fill(MM.line).frame(height: 1) }
                ForEach(0..<Self.fingerSlots, id: \.self) { i in
                    fingerRow(index: i, touch: i < touches.count ? touches[i] : nil)
                    if i < Self.fingerSlots - 1 { MMDivider() }
                }
            }
        }
    }

    private func fingerRow(index i: Int, touch: Touch?) -> some View {
        HStack(spacing: 10) {
            Text(verbatim: "\(i + 1)").font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(touch != nil ? MM.accentInk : MM.text2)
                .frame(width: 20, height: 20)
                .background { if touch != nil { Circle().fill(MM.accent) } }
                .overlay {
                    if touch == nil { Circle().strokeBorder(MM.line, style: StrokeStyle(lineWidth: 1, dash: [2, 2])) }
                }
                .opacity(touch != nil ? 1 : 0.7)
            Text(LF("Parmak %lld", i + 1)).font(.system(size: 13, weight: .medium))
                .foregroundStyle(touch != nil ? MM.text : MM.text2)
            Spacer(minLength: 8)
            if let t = touch, trackpad {
                // Trackpad'de bölge yok: yön çevirme uygulanmaz, bölge sütununda "yüzeyde" yazar.
                Text(verbatim: "x \(pct(t.x))% · y \(pct(t.y))%")
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(MM.text2)
                Text(L("yüzeyde")).font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(MM.accentText)
                    .frame(minWidth: 80, alignment: .trailing)
            } else if let t = touch {
                let front = t.front(flipped: s.flipY)
                let zone = Zone.classify(x: t.x, y: front, layout: s.zoneLayout)
                Text(verbatim: "x \(pct(t.x))% · y \(pct(front))%")
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(MM.text2)
                Text(zone.displayName).font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(MM.accentText)
                    .frame(minWidth: 80, alignment: .trailing)
            } else {
                Text(verbatim: "—").font(.system(size: 12, design: .monospaced)).foregroundStyle(MM.text2)
                Text(verbatim: "—").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(MM.text2)
                    .frame(minWidth: 80, alignment: .trailing)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, 20)
        .frame(height: Self.fingerRowHeight)
        .accessibilityElement(children: .combine)
    }

    private var logCard: some View {
        MMCard {
            VStack(spacing: 0) {
                HStack {
                    Text(L("Algılanan hareketler")).font(.system(size: 12, weight: .semibold)).foregroundStyle(MM.text)
                    Spacer(minLength: 8)
                    Button { model.eventLog.clear() } label: {
                        Text(L("Temizle")).font(.system(size: 12)).foregroundStyle(MM.accentText)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.eventLog.entries.isEmpty)
                }
                .padding(.horizontal, 20).padding(.vertical, 8)
                .background(MM.card2)
                .overlay(alignment: .bottom) { Rectangle().fill(MM.line).frame(height: 1) }
                let entries = model.eventLog.entries
                if entries.isEmpty {
                    Text(L("Henüz hareket algılanmadı")).font(.system(size: 13)).foregroundStyle(MM.text2)
                        .padding(.horizontal, 20).padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(entries) { e in
                        HStack(spacing: 10) {
                            Text(Self.timeFormatter.string(from: e.date))
                                .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(MM.text2)
                            Text(e.text).font(.system(size: 12.5)).foregroundStyle(MM.text)
                                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            if e.dryRun {
                                Text(L("deneme")).font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                    .background(MM.bttBg, in: Capsule()).foregroundStyle(MM.bttText)
                            }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 7)
                        if e.id != entries.last?.id { MMDivider() }
                    }
                }
            }
        }
    }

    private func pct(_ v: Float) -> Int { Int((Double(v) * 100).rounded()) }
}
