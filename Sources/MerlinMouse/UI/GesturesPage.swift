import SwiftUI
import MerlinCore

/// Genel (tüm uygulamalar) hareket atamaları.
struct GesturesPage: View {
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var store = BindingStore.shared
    @ObservedObject private var s = Settings.shared
    @State private var adding = false
    @State private var twoButton = false

    /// Düzenlenen aygıt üst çubuktaki seçiciden gelir.
    private var device: InputDeviceKind { s.editingDevice }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MMPageHeader(title: L("Hareketler"),
                         subtitle: device == .trackpad
                            ? L("Trackpad'in boş hareketlerini orta tuş eylemlerine bağla.")
                            : L("Magic Mouse yüzeyindeki hareketleri orta tuş eylemlerine bağla.")) {
                MMPrimaryButton(L("Hareket ekle"), "plus") { adding = true }
            }
            DevicePassiveBanner()
            banners
            if device == .trackpad {
                TrackpadGesturesContent()
                    .frame(maxHeight: .infinity)
            } else {
                HStack(alignment: .top, spacing: 20) {
                    zoneCard
                    BindingListView(scope: nil)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 32).padding(.vertical, 28)
        .onAppear { twoButton = AppModel.shared.conflictEnvironment().mouseButtonMode == "TwoButton" }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            twoButton = AppModel.shared.conflictEnvironment().mouseButtonMode == "TwoButton"
        }
        .sheet(isPresented: $adding) { BindingEditorView(existing: nil, device: device) }
    }

    @ViewBuilder private var banners: some View {
        if !model.trusted {
            MMBanner(kind: .warning, title: L("Erişilebilirlik izni gerekli"),
                     message: (model.permissionHelp.map { $0 + "\n" } ?? "")
                        + L("Tıklamaları orta tuşa çevirebilmek için Merlin Mouse'a izin ver. Listede açık görünüyorsa ama çalışmıyorsa: uygulama yeniden derlendiği için eski kayıt geçersizdir."),
                     actionTitle: L("İzni sıfırla ve yeniden iste")) { model.resetAccessibilityPermission() }
                .secondary(L("Ayarları aç")) { model.requestPermission() }
        }
        if let notice = store.recoveryNotice {
            MMBanner(kind: .info, title: notice, actionTitle: L("Tamam")) { store.dismissRecoveryNotice() }
        }
        if model.isPaused {
            MMBanner(kind: .info, title: L("Merlin Mouse duraklatıldı"),
                     actionTitle: L("Devam et")) { model.resume() }
        }
    }

    private var zoneCard: some View {
        MMCard(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Dokunma bölgeleri")).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(MM.text)
                    Text(L("Sınırlar Bölgeler sayfasında ayarlanır."))
                        .font(.system(size: 12)).foregroundStyle(MM.text2)
                }
                // Yalnız gösterir; tek düzenleme yeri Bölgeler sayfasıdır.
                MouseZoneMap(touches: model.liveTouches, layout: s.zoneLayout, flipped: s.flipY,
                             image: model.mouseImage, secondaryRightZone: twoButton, width: 150, showEdges: true)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 8) {
                    let r = ZoneReadout(layout: s.zoneLayout, edgeWidth: s.edgeWidth, edgeBounds: s.edgeBounds)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LF("Sol %lld · Orta %lld · Sağ %lld", r.left, r.center, r.right))
                        Text(LF("Arka %lld · Orta yükseklik %lld (yüzde)", r.rear, r.centerHeight)).foregroundStyle(MM.text2)
                    }
                    .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(MM.text)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    Button { MainWindow.Page.zones.open() } label: {
                        Text(L("Bölgeleri düzenle ›")).font(.system(size: 12))
                            .foregroundStyle(MM.text)
                            .padding(.horizontal, 10).frame(height: 26)
                            .background(MM.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(MM.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                VStack(alignment: .leading, spacing: 6) {
                    legend(fill: MM.accentSoft, stroke: MM.accent, L("Orta bölge"))
                    legend(fill: MM.warnBg, stroke: MM.warnDot, L("Sağ: macOS ikincil tıklama"))
                        .help(L("Sağ tıklama alanını macOS belirler; buradaki sağ bölge yalnız Merlin Mouse hareketleri içindir."))
                    legend(fill: MM.bttBg, stroke: MM.bttDot, L("Arka (logo): dokunma hareketleri"))
                        .help(L("Arka bölgeye yalnız dokunma ve çift dokunma atanabilir; avuç değerken tetiklenmez."))
                    legend(fill: MM.okDot.opacity(0.2), stroke: MM.okDot, L("Kenar şeritleri: ses / parlaklık"))
                }
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 280)
    }

    private func legend(fill: Color, stroke: Color, _ text: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4).fill(fill).frame(width: 12, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(stroke, lineWidth: 1.5))
            Text(text).font(.system(size: 12)).foregroundStyle(MM.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
