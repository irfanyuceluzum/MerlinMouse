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
                     message: (model.permissionHelp.map { $0 + "\n" } ?? "")
                        + "Tıklamaları orta tuşa çevirebilmek için Merlin Mouse'a izin ver. Listede açık görünüyorsa ama çalışmıyorsa: uygulama yeniden derlendiği için eski kayıt geçersizdir.",
                     actionTitle: "İzni sıfırla ve yeniden iste") { model.resetAccessibilityPermission() }
                .secondary("Ayarları aç") { model.openAccessibilitySettings() }
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dokunma bölgeleri").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(MM.text)
                    Text("Sınırları sürükleyerek boyutlandır.")
                        .font(.system(size: 12)).foregroundStyle(MM.text2)
                }
                MouseZoneMap(touches: model.liveTouches, layout: s.zoneLayout, editable: true, flipped: s.flipY,
                             image: model.mouseImage, secondaryRightZone: twoButton, width: 150)
                    .frame(maxWidth: .infinity)
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sol \(pct(s.zoneLayout.leftWidth)) · Orta \(pct(s.zoneLayout.centerWidth)) · Sağ \(pct(s.zoneLayout.rightWidth))")
                        Text("Arka \(pct(s.zoneLayout.frontLimit)) (yüzde)").foregroundStyle(MM.text2)
                    }
                    .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(MM.text)
                    Spacer(minLength: 0)
                    Button { s.resetZoneLayout() } label: {
                        Text("Varsayılana dön").font(.system(size: 12))
                            .foregroundStyle(MM.text)
                            .padding(.horizontal, 10).frame(height: 26)
                            .background(MM.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(MM.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Bölgeleri varsayılan boyutlarına (Sol 35 · Orta 30 · Sağ 35 · Arka 40) döndürür")
                }
                VStack(alignment: .leading, spacing: 6) {
                    legend(fill: MM.accentSoft, stroke: MM.accent, "Orta bölge")
                    legend(fill: MM.warnBg, stroke: MM.warnDot, "Sağ: macOS ikincil tıklama")
                        .help("Sağ tıklama alanını macOS belirler; buradaki sağ bölge yalnız Merlin Mouse hareketleri içindir.")
                    legend(fill: MM.bttBg, stroke: MM.bttDot, "Arka (logo): dokunma hareketleri")
                        .help("Arka bölgeye yalnız dokunma ve çift dokunma atanabilir; avuç değerken tetiklenmez.")
                }
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 280)
    }

    private func pct(_ v: Double) -> Int { Int((v * 100).rounded()) }

    private func legend(fill: Color, stroke: Color, _ text: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4).fill(fill).frame(width: 12, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(stroke, lineWidth: 1.5))
            Text(text).font(.system(size: 12)).foregroundStyle(MM.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
