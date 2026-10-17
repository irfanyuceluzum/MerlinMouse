import SwiftUI
import AppKit
import MerlinCore

/// Canlı trackpad haritası: yatay yuvarlatılmış yüzey, parmaklar mavi noktalar; fiziksel tıklama sürerken
/// noktaların çevresinde halka. Trackpad bağlı değilse "Bağlı değil" örtüsü. Harita görünürken trackpad akışı
/// açılır (kendi kimliğiyle; aynı anda birden çok harita olabilir).
struct TrackpadLiveMap: View {
    @ObservedObject private var live = TrackpadLiveTouches.shared
    let connected: Bool
    var width: CGFloat = 240
    /// Gösterilecek köşeler (nil = köşe çizilmez); atanmış olanlar dolu turuncu, diğerleri kesikli.
    var corners: TrackpadCornerLayout?
    var assigned: Set<Zone> = []
    /// Verilirse köşe ölçüsü sol alt köşedeki iki tutamaçla sürüklenir (dört köşe aynı ölçüyü paylaşır).
    var onCornersChange: ((TrackpadCornerLayout) -> Void)?
    @State private var viewer = UUID()

    private static let space = "trackpadMap"

    /// Atanmış köşeler: açık trackpad atamalarından tek parmakla köşeye basanlar (her kapsam).
    static func assignedCorners(_ bindings: [GestureBinding]) -> Set<Zone> {
        Set(bindings.compactMap { b -> Zone? in
            let t = b.trigger.normalized
            guard b.enabled, b.device == .trackpad, t.kind == .press, t.fingers == 1, t.zone.isCorner else { return nil }
            return t.zone
        })
    }

    var body: some View {
        let height = (width / 1.6).rounded()
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        // Kareler en çok 20 Hz gelir; basılı düğme her çizimde okunur (ucuz).
        let clicking = NSEvent.pressedMouseButtons != 0
        return ZStack {
            shape.fill(MM.card2)
            if let corners {
                cornerAreas(corners, height: height).clipShape(shape)
            }
            shape.strokeBorder(MM.line, lineWidth: 1.5)
            if let corners, let onCornersChange, connected {
                handles(corners, height: height, onChange: onCornersChange)
            }
            if connected {
                ForEach(live.touches) { t in
                    // Trackpad'de y: 0 alt (kullanıcıya yakın) → 1 üst; ekranda yukarısı üst.
                    let x = min(max(CGFloat(t.x), 0), 1) * width
                    let y = (1 - min(max(CGFloat(t.y), 0), 1)) * height
                    ZStack {
                        if clicking {
                            Circle().stroke(MM.accent.opacity(0.55), lineWidth: 1.5).frame(width: 28, height: 28)
                        }
                        Circle().fill(MM.accent).frame(width: 14, height: 14)
                    }
                    .position(x: x, y: y)
                }
            } else {
                shape.fill(MM.card.opacity(0.7))
                Text(L("Bağlı değil")).font(.system(size: 13, weight: .medium)).foregroundStyle(MM.text2)
            }
        }
        .frame(width: width, height: height)
        .coordinateSpace(name: Self.space)
        .accessibilityElement(children: onCornersChange == nil ? .ignore : .contain)
        .accessibilityLabel(L("Canlı trackpad haritası"))
        .onAppear { TouchMonitor.shared.setTrackpadLiveView(viewer, visible: true) }
        .onDisappear { TouchMonitor.shared.setTrackpadLiveView(viewer, visible: false) }
    }

    /// Dört köşe dikdörtgeni (ekranda üst = trackpad'in üstü).
    private func cornerAreas(_ c: TrackpadCornerLayout, height: CGFloat) -> some View {
        let w = CGFloat(c.width) * width, h = CGFloat(c.height) * height
        return ZStack {
            ForEach(Zone.corners, id: \.self) { z in
                let left = z == .cornerTopLeft || z == .cornerBottomLeft
                let top = z == .cornerTopLeft || z == .cornerTopRight
                let on = assigned.contains(z)
                Group {
                    if on {
                        Rectangle().fill(MM.warnDot.opacity(0.22))
                            .overlay(Rectangle().strokeBorder(MM.warnDot, lineWidth: 1.5))
                    } else {
                        Rectangle().strokeBorder(MM.text2.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .frame(width: w, height: h)
                .position(x: left ? w / 2 : width - w / 2, y: top ? h / 2 : height - h / 2)
            }
        }
        .frame(width: width, height: height)
    }

    /// Sol alt köşenin iç kenarlarındaki iki tutamaç: dikey kenar genişliği, yatay kenar yüksekliği değiştirir.
    private func handles(_ c: TrackpadCornerLayout, height: CGFloat,
                         onChange: @escaping (TrackpadCornerLayout) -> Void) -> some View {
        let w = CGFloat(c.width) * width, h = CGFloat(c.height) * height
        return ZStack {
            handle(horizontal: false)
                .position(x: w, y: height - h / 2)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space)).onChanged { v in
                    var n = c
                    n.width = Double(v.location.x / width)
                    onChange(n.clamped())
                })
                .accessibilityElement()
                .accessibilityLabel(L("Köşe genişliği"))
                .accessibilityValue(Text(verbatim: "\(Int((c.width * 100).rounded()))%"))
                .accessibilityAdjustableAction { dir in
                    var n = c
                    n.width += dir == .increment ? 0.01 : -0.01
                    onChange(n.clamped())
                }
            handle(horizontal: true)
                .position(x: w / 2, y: height - h)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space)).onChanged { v in
                    var n = c
                    n.height = Double((height - v.location.y) / height)
                    onChange(n.clamped())
                })
                .accessibilityElement()
                .accessibilityLabel(L("Köşe yüksekliği"))
                .accessibilityValue(Text(verbatim: "\(Int((c.height * 100).rounded()))%"))
                .accessibilityAdjustableAction { dir in
                    var n = c
                    n.height += dir == .increment ? 0.01 : -0.01
                    onChange(n.clamped())
                }
        }
        .frame(width: width, height: height)
    }

    private func handle(horizontal: Bool) -> some View {
        Capsule().fill(MM.card)
            .overlay(Capsule().strokeBorder(MM.warnDot, lineWidth: 1.5))
            .frame(width: horizontal ? 18 : 8, height: horizontal ? 8 : 18)
            // Tutması kolay olsun: dokunma alanı her yönde 6 pt geniş.
            .padding(6)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { (horizontal ? NSCursor.resizeUpDown : NSCursor.resizeLeftRight).push() } else { NSCursor.pop() }
            }
    }
}

/// Hareketler sayfasının (trackpad seçiliyken) sol kartı.
struct TrackpadCard: View {
    let presence: DevicePresence
    @ObservedObject private var s = Settings.shared
    @ObservedObject private var store = BindingStore.shared

    var body: some View {
        let on = presence.isPresent(.trackpad)
        MMCard(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(presence.builtInTrackpad ? L("Dahili trackpad") : InputDeviceKind.trackpad.displayName)
                        .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(MM.text)
                    Text(!on ? L("Bağlı değil")
                         : presence.builtInTrackpad ? L("MacBook trackpad · bağlı") : L("Magic Trackpad · bağlı"))
                        .font(.system(size: 12)).foregroundStyle(MM.text2)
                }
                // Köşeler yalnız gösterilir; ölçü Bölgeler sayfasında ayarlanır.
                TrackpadLiveMap(connected: on, corners: s.trackpadCorners,
                                assigned: TrackpadLiveMap.assignedCorners(store.bindings))
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    legend(ring: false, L("Parmaklar canlı gösterilir"))
                    legend(ring: true, L("Halka: fiziksel tıklama"))
                }
                Text(L("macOS'un trackpad hareketleri (kaydırma, çimdikleme, Mission Control) her zamanki gibi çalışır. Yalnız boş hareketler atanabilir."))
                    .font(.system(size: 12)).foregroundStyle(MM.text2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 280)
    }

    fileprivate func legend(ring: Bool, _ text: String) -> some View {
        TrackpadLegendRow(ring: ring, text: text)
    }
}

/// Harita lejantı: dolu nokta (parmak) ya da halkalı nokta (fiziksel tıklama).
struct TrackpadLegendRow: View {
    let ring: Bool
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if ring {
                    Circle().stroke(MM.accent.opacity(0.55), lineWidth: 1.5).frame(width: 12, height: 12)
                    Circle().fill(MM.accent).frame(width: 6, height: 6)
                } else {
                    Circle().fill(MM.accent).frame(width: 9, height: 9)
                }
            }
            .frame(width: 12, height: 12)
            Text(text).font(.system(size: 12)).foregroundStyle(MM.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Bölgeler sayfasının (trackpad seçiliyken) sol kartı: canlı harita, köşe ölçüsünün tek düzenleme yeri
/// (tutamaçlar, ölçü satırı, "Varsayılana dön") ve notlar.
struct TrackpadZonesCard: View {
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var live = TrackpadLiveTouches.shared
    @ObservedObject private var s = Settings.shared
    @ObservedObject private var store = BindingStore.shared

    var body: some View {
        let presence = model.devicePresence
        let on = presence.isPresent(.trackpad)
        let c = s.trackpadCorners
        MMCard(padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(presence.builtInTrackpad ? L("Dahili trackpad") : InputDeviceKind.trackpad.displayName)
                        .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(MM.text)
                    Text(on ? LF("Canlı · %lld parmak", live.touches.count) : L("Bağlı değil"))
                        .font(.system(size: 12, design: .monospaced)).foregroundStyle(MM.text2)
                }
                TrackpadLiveMap(connected: on, width: 220, corners: c,
                                assigned: TrackpadLiveMap.assignedCorners(store.bindings)) { s.trackpadCorners = $0 }
                Text(LF("Köşe genişliği %lld · yüksekliği %lld", Int((c.width * 100).rounded()), Int((c.height * 100).rounded())))
                    .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(MM.text)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Button { s.trackpadCorners = .standard } label: {
                    Text(L("Varsayılana dön")).font(.system(size: 12))
                        .foregroundStyle(MM.text)
                        .padding(.horizontal, 10).frame(height: 26)
                        .background(MM.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(MM.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help(L("Köşeleri varsayılan boyutlarına döndürür"))
                VStack(alignment: .leading, spacing: 6) {
                    TrackpadLegendRow(ring: false, text: L("Parmaklar canlı gösterilir"))
                    TrackpadLegendRow(ring: true, text: L("Halka: fiziksel tıklama"))
                }
                Text(L("Köşelere basınca atanan eylem çalışır; köşe dışındaki tek parmak tıklaması hiç değişmez. Köşe boyutunu tutamaçlarla ayarla. Çok parmaklı hareketler tüm yüzeyde geçerlidir."))
                    .font(.system(size: 12)).foregroundStyle(MM.text2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L("Harita yalnız bu sayfa açıkken canlıdır."))
                    .font(.system(size: 12)).foregroundStyle(MM.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 220)
        }
    }
}

/// Hareketler sayfasının trackpad içeriği: kart + liste, alt şerit (pasif şeridi sayfa üstünde ortaktır).
struct TrackpadGesturesContent: View {
    @ObservedObject private var model = AppModel.shared

    var body: some View {
        let presence = model.devicePresence
        let on = presence.isPresent(.trackpad)
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 20) {
                TrackpadCard(presence: presence)
                BindingListView(scope: nil, device: .trackpad, passive: !on)
            }
            .frame(maxHeight: .infinity)
            bottomStrip
        }
    }

    private var bottomStrip: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return HStack(spacing: 10) {
            Image(systemName: "info.circle").font(.system(size: 13, weight: .medium)).foregroundStyle(MM.text2)
            Text(L("macOS trackpad ayarları okunur; çakışan bir ayar açılırsa uyarı verilir."))
                .font(.system(size: 12.5)).foregroundStyle(MM.text2)
            Spacer(minLength: 8)
            // Aygıt zaten genel seçimdir; bağlantı yalnız sayfayı açar.
            Button { MainWindow.Page.system.open() } label: {
                Text(L("Sistem hareketleri ›")).font(.system(size: 12.5, weight: .medium)).foregroundStyle(MM.accentText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(MM.card, in: shape)
        .overlay(shape.strokeBorder(MM.line, lineWidth: 1))
    }
}
