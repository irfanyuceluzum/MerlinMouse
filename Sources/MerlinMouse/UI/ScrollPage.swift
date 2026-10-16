import SwiftUI
import MerlinCore

/// Kaydırma ayarları: sol sütunda kaydırma, çimdikleme ve öndeki uygulama; sağ sütunda kenar kaydırma.
struct ScrollPage: View {
    @ObservedObject private var s = Settings.shared
    @ObservedObject private var front = FrontApp.shared
    @ObservedObject private var store = BindingStore.shared
    /// "Kısayol çifti…" seçilince açılan düzenleyici.
    @State private var editing: EdgeEdit?

    /// Kenar atamasının düzenleyicide açılışı; `presetAction` kayıtlı eylemin yerine gösterilir.
    private struct EdgeEdit: Identifiable {
        let id = UUID()
        let binding: GestureBinding
        let presetAction: GestureAction?
    }

    /// Kenar satırındaki eylem seçenekleri.
    private enum EdgeChoice: Hashable, CaseIterable {
        case volume, brightness, zoom, pair

        var title: String {
            switch self {
            case .volume: return L("Ses")
            case .brightness: return L("Parlaklık")
            case .zoom: return L("Yakınlaştır / uzaklaştır")
            case .pair: return L("Kısayol çifti…")
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MMPageHeader(title: L("Kaydırma"),
                             subtitle: L("Orta tuşla çalışırken ve 3D programlarda Magic Mouse kaydırmasını denetle."))
                if s.editingDevice == .trackpad {
                    mouseOnlyCard
                } else {
                    mouseContent
                }
            }
            .padding(.horizontal, 32).padding(.vertical, 28)
        }
        .sheet(item: $editing) { e in BindingEditorView(existing: e.binding, presetAction: e.presetAction) }
    }

    /// Trackpad seçiliyken: bu sayfanın ayarları yalnız Magic Mouse içindir.
    private var mouseOnlyCard: some View {
        MMCard(padding: 20) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "computermouse").font(.system(size: 22, weight: .regular))
                    .foregroundStyle(MM.accentText)
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("Bu ayarlar yalnız Magic Mouse için"))
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(MM.text)
                        Text(L("Kenar kaydırma ve çimdikleme Magic Mouse'a özgüdür."))
                            .font(.system(size: 13)).foregroundStyle(MM.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    MMPrimaryButton(L("Magic Mouse'a geç"), "computermouse") { s.editingDevice = .magicMouse }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var mouseContent: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(spacing: 20) {
                scrollCard
                pinchCard
                frontCard
            }
            .frame(maxWidth: .infinity, alignment: .top)
            edgeCard
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    // MARK: Sol sütun

    private var scrollCard: some View {
        MMCard {
            VStack(spacing: 0) {
                cardTitle(L("Kaydırma ve yakınlaştırma"))
                MMSwitchRow(title: L("Sürüklerken kaydırmayı engelle"),
                            subtitle: L("Model döndürürken istemeden yakınlaşmaz"),
                            isOn: $s.blockScrollWhileDragging)
                MMDivider()
                MMSwitchRow(title: L("Ataleti kapat, adım adım yakınlaştır"),
                            subtitle: L("3D programlarda Magic Mouse kaydırması tekerlek gibi davranır"),
                            isOn: $s.calm3DScroll)
            }
        }
    }

    private var pinchCard: some View {
        MMCard {
            VStack(spacing: 0) {
                cardTitle(L("Çimdikleme"))
                note(L("İki parmağı açıp kapatarak trackpad'deki gibi yakınlaştır. Bir programda çalışmazsa o programa profil ekleyip yöntemi Fare tekerleği yap. Çimdiklerken kaydırma durur."))
                MMSwitchRow(title: L("Yönü ters çevir"),
                            subtitle: L("Parmakları açmak uzaklaştırır"),
                            isOn: $s.pinchInvert)
                MMDivider()
                sliderRow(L("Hassasiyet"), value: pinchSensitivity, in: 0...1, min: L("Az"), max: L("Çok"))
            }
        }
    }

    private var frontCard: some View {
        MMCard {
            VStack(spacing: 0) {
                cardTitle(L("Öndeki uygulama"))
                HStack(spacing: 8) {
                    if !front.name.isEmpty {
                        AppIconView(bundleID: front.bundleID, name: front.name, size: 20)
                    }
                    Text(front.name.isEmpty ? "—" : front.name)
                        .font(.system(size: 13.5, weight: .medium)).foregroundStyle(MM.text)
                    if front.is3D {
                        Text("3D").font(.system(size: 11, weight: .bold)).foregroundStyle(MM.accentText)
                            .padding(.horizontal, 7).padding(.vertical, 1)
                            .background(MM.accentSoft, in: Capsule())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
            }
        }
    }

    // MARK: Kenar kaydırma

    private var edgeCard: some View {
        MMCard {
            VStack(spacing: 0) {
                cardTitle(L("Kenar kaydırma"))
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Farenin sol ya da sağ kenarında tek parmakla yukarı kaydırınca artar, aşağı kaydırınca azalır."))
                    Text(L("Şerit, tıklama alanından uzakta, farenin arka-orta kısmındadır; uçlarını Bölgeler sayfasındaki haritada sürükleyerek uzat ya da kısalt."))
                    Text(L("Sayfa kaydırması yalnız kenar hareketi başladıktan sonra durur. Şeritteki parmak basma hareketlerinde sayılmaz; tıklama olursa kenar hareketi iptal olur."))
                }
                .font(.system(size: 12)).foregroundStyle(MM.text2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.vertical, 14)
                MMDivider()
                // Şeridin yeri ve genişliği yalnız Bölgeler sayfasındaki haritadan ayarlanır.
                Button { MainWindow.Page.zones.open() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap").font(.system(size: 12, weight: .medium))
                        Text(L("Şeridin yeri ve genişliği: Bölgeler sayfası ›")).font(.system(size: 13))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(MM.accentText)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                MMDivider()
                edgeRow(.left)
                MMDivider()
                edgeRow(.right)
                MMDivider()
                sliderRow(L("Hassasiyet"), value: edgeSensitivity, in: 0...1, min: L("Az"), max: L("Çok"))
                MMDivider()
                MMSwitchRow(title: L("İnce adım"), subtitle: L("Ses ve parlaklık çeyrek adımlarla değişir."),
                            isOn: $s.edgeFineSteps)
                MMDivider()
                MMSwitchRow(title: L("Yönü ters çevir"), subtitle: L("Aşağı kaydırmak artırır."),
                            isOn: $s.edgeInvert)
            }
        }
    }

    private func key(_ side: EdgeSide) -> String { side == .left ? "edge-left" : "edge-right" }

    /// Genel kapsamdaki temel kenar ataması; kayıtta yoksa (örn. eski bir yedekten dönüş) tanımdan kapalı taslak.
    private func edgeBinding(_ side: EdgeSide) -> GestureBinding {
        if let b = store.bindings.first(where: { $0.builtInKey == key(side) }) { return b }
        let d = DefaultBindings.definitions.first { $0.key == key(side) }
        return GestureBinding(trigger: d?.trigger ?? Trigger(kind: .edgeSlide, zone: side.zone).normalized,
                              action: d?.action ?? .volume, enabled: false, builtInKey: key(side))
    }

    private func choice(_ action: GestureAction) -> EdgeChoice {
        switch action {
        case .brightness: return .brightness
        case .zoom: return .zoom
        case .stepShortcut: return .pair
        default: return .volume
        }
    }

    private func setChoice(_ c: EdgeChoice, side: EdgeSide) {
        var b = edgeBinding(side)
        switch c {
        case .volume: b.action = .volume
        case .brightness: b.action = .brightness
        case .zoom:
            if !b.action.isZoom { b.action = .zoom(style: .gesture, modifiers: []) }
        case .pair:
            openPairEditor(b)
            return
        }
        store.upsert(b)
    }

    /// Kısayol çifti düzenleyicisi: kayıtlı çift varsa onunla, yoksa boş çiftle açılır; kaydedilene kadar değişmez.
    private func openPairEditor(_ b: GestureBinding) {
        let empty = KeyCombo(keyCode: 0, modifiers: [], display: "")
        if case .stepShortcut = b.action {
            editing = EdgeEdit(binding: b, presetAction: nil)
        } else {
            editing = EdgeEdit(binding: b, presetAction: .stepShortcut(up: empty, down: empty))
        }
    }

    private func edgeRow(_ side: EdgeSide) -> some View {
        let b = edgeBinding(side)
        let name = side == .left ? L("Sol kenar") : L("Sağ kenar")
        var status = b.enabled ? L("Açık") : L("Kapalı")
        if case .stepShortcut(let up, let down) = b.action { status += " · \(up.display) / \(down.display)" }
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 13.5, weight: .medium)).foregroundStyle(MM.text)
                Text(status).font(.system(size: 12)).foregroundStyle(b.enabled ? MM.okDot : MM.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Picker(LF("%@ eylemi", name), selection: Binding(
                get: { choice(edgeBinding(side).action) },
                set: { setChoice($0, side: side) })) {
                ForEach(EdgeChoice.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .frame(maxWidth: 190)
            if case .stepShortcut = b.action {
                Button { openPairEditor(b) } label: {
                    Image(systemName: "pencil").font(.system(size: 12, weight: .semibold)).foregroundStyle(MM.text2)
                }
                .buttonStyle(.plain)
                .help(L("Kısayol çiftini düzenle"))
                .accessibilityLabel(L("Kısayol çiftini düzenle"))
            }
            MMSwitch(isOn: Binding(
                get: { edgeBinding(side).enabled },
                set: { on in
                    if let saved = store.bindings.first(where: { $0.builtInKey == key(side) }) {
                        store.setEnabled(id: saved.id, on)
                    } else {
                        var d = edgeBinding(side)
                        d.enabled = on
                        store.upsert(d)
                    }
                }), label: name)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    // MARK: Yardımcılar

    /// Hassasiyet 0 (az) … 1 (çok); arttıkça adım küçülür.
    private var pinchSensitivity: Binding<Double> {
        Binding(get: { PinchRecognizer.sensitivity(forStep: s.pinchStep) },
                set: { s.pinchStep = PinchRecognizer.step(forSensitivity: $0) })
    }

    private var edgeSensitivity: Binding<Double> {
        Binding(get: { EdgeSlideRecognizer.sensitivity(forStep: s.edgeStep) },
                set: { s.edgeStep = EdgeSlideRecognizer.step(forSensitivity: $0) })
    }

    private func sliderRow(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>,
                           min: String, max: String) -> some View {
        HStack(spacing: 16) {
            Text(title).font(.system(size: 13.5, weight: .medium)).foregroundStyle(MM.text)
            Spacer(minLength: 12)
            Slider(value: value, in: range) {
                Text(title)
            } minimumValueLabel: {
                Text(min).font(.system(size: 12)).foregroundStyle(MM.text2)
            } maximumValueLabel: {
                Text(max).font(.system(size: 12)).foregroundStyle(MM.text2)
            }
            .labelsHidden()
            .tint(MM.accent)
            .frame(maxWidth: 260)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12)).foregroundStyle(MM.text2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 12)
    }

    private func cardTitle(_ t: String) -> some View {
        Text(t).font(.system(size: 12, weight: .semibold)).foregroundStyle(MM.text)
            .padding(.horizontal, 20).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MM.card2)
            .overlay(alignment: .bottom) { Rectangle().fill(MM.line).frame(height: 1) }
    }
}
