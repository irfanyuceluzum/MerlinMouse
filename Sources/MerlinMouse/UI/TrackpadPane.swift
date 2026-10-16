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
    @State private var viewer = UUID()

    var body: some View {
        let height = (width / 1.6).rounded()
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        // Kareler en çok 20 Hz gelir; basılı düğme her çizimde okunur (ucuz).
        let clicking = NSEvent.pressedMouseButtons != 0
        return ZStack {
            shape.fill(MM.card2)
            shape.strokeBorder(MM.line, lineWidth: 1.5)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Canlı trackpad haritası"))
        .onAppear { TouchMonitor.shared.setTrackpadLiveView(viewer, visible: true) }
        .onDisappear { TouchMonitor.shared.setTrackpadLiveView(viewer, visible: false) }
    }
}

/// Hareketler sayfasının (trackpad seçiliyken) sol kartı.
struct TrackpadCard: View {
    let presence: DevicePresence

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
                TrackpadLiveMap(connected: on)
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

/// Bölgeler sayfasının (trackpad seçiliyken) sol kartı: canlı harita, parmak sayısı ve bölgesizlik notu.
struct TrackpadZonesCard: View {
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var live = TrackpadLiveTouches.shared

    var body: some View {
        let presence = model.devicePresence
        let on = presence.isPresent(.trackpad)
        MMCard(padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(presence.builtInTrackpad ? L("Dahili trackpad") : InputDeviceKind.trackpad.displayName)
                        .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(MM.text)
                    Text(on ? LF("Canlı · %lld parmak", live.touches.count) : L("Bağlı değil"))
                        .font(.system(size: 12, design: .monospaced)).foregroundStyle(MM.text2)
                }
                TrackpadLiveMap(connected: on, width: 220)
                VStack(alignment: .leading, spacing: 6) {
                    TrackpadLegendRow(ring: false, text: L("Parmaklar canlı gösterilir"))
                    TrackpadLegendRow(ring: true, text: L("Halka: fiziksel tıklama"))
                }
                Text(L("Trackpad'de bölge yok: hareketler tüm yüzeyde geçerli. Parmak sayısı ve dokunma ya da basma ayrımı yeterli."))
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
