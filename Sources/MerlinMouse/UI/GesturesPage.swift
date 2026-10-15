import SwiftUI
import MerlinCore

/// Genel (tüm uygulamalar) hareket atamaları.
struct GesturesPage: View {
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var store = BindingStore.shared
    @ObservedObject private var s = Settings.shared
    @State private var adding = false
    @State private var twoButton = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MMPageHeader(title: "Hareketler",
                         subtitle: "Magic Mouse yüzeyindeki hareketleri orta tuş eylemlerine bağla.") {
                MMPrimaryButton("Hareket ekle", "plus") { adding = true }
            }
            banners
            HStack(alignment: .top, spacing: 20) {
                zoneCard
                BindingListView(scope: nil)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 32).padding(.vertical, 28)
        .onAppear { twoButton = AppModel.shared.conflictEnvironment().mouseButtonMode == "TwoButton" }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            twoButton = AppModel.shared.conflictEnvironment().mouseButtonMode == "TwoButton"
        }
        .sheet(isPresented: $adding) { BindingEditorView(existing: nil) }
    }

    @ViewBuilder private var banners: some View {
        if !model.trusted {
            MMBanner(kind: .warning, title: "Erişilebilirlik izni gerekli",
                     message: "Tıklamaları orta tuşa çevirebilmek için Merlin Mouse'a izin ver.",
                     actionTitle: "Ayarları aç") { model.openAccessibilitySettings() }
        }
        if let notice = store.recoveryNotice {
            MMBanner(kind: .info, title: notice, actionTitle: "Tamam") { store.dismissRecoveryNotice() }
        }
        if model.isPaused {
            MMBanner(kind: .info, title: "Merlin Mouse duraklatıldı",
                     actionTitle: "Devam et") { model.resume() }
        }
    }

    private var zoneCard: some View {
        MMCard(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Dokunma bölgeleri").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(MM.text)
                MouseZoneMap(touches: model.liveTouches, zoneWidth: s.zoneWidth, flipped: s.flipY,
                             image: model.mouseImage, secondaryRightZone: twoButton, width: 162)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 7) {
                    legend(fill: MM.accentSoft, stroke: MM.accent, "Merlin Mouse bölgesi")
                    legend(fill: MM.warnBg, stroke: MM.warnDot, "macOS: ikincil tıklama")
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Orta bölge genişliği").font(.system(size: 12.5)).foregroundStyle(MM.text)
                        Spacer()
                        Text("%\(Int((s.zoneWidth * 100).rounded()))")
                            .font(.system(size: 12.5, design: .monospaced)).foregroundStyle(MM.text2)
                    }
                    Slider(value: $s.zoneWidth, in: 0.15...0.45)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 280)
    }

    private func legend(fill: Color, stroke: Color, _ text: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4).fill(fill).frame(width: 12, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(stroke, lineWidth: 1.5))
            Text(text).font(.system(size: 12.5)).foregroundStyle(MM.text2)
        }
    }
}
