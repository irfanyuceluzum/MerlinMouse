import SwiftUI
import MerlinCore

enum EditorActionKind: String, CaseIterable, Identifiable {
    case middle, middleDrag, back, forward, shortcut, system, openApp, runShortcut, zoom
    case volume, brightness, pair
    var id: String { rawValue }

    /// Adım eylemleri (kenar kaydırma ve çimdikleme dışında sunulmaz).
    static let stepKinds: [EditorActionKind] = [.volume, .brightness, .zoom, .pair]

    /// Tetik türüne göre sunulan eylemler: çimdiklemede yalnız yakınlaştırma, kenar kaydırmada adım
    /// eylemleri, diğerlerinde adım eylemleri hariç hepsi.
    static func choices(for kind: GestureKind) -> [EditorActionKind] {
        switch kind {
        case .pinch: return [.zoom]
        case .edgeSlide: return stepKinds
        default: return allCases.filter { !stepKinds.contains($0) }
        }
    }

    var title: String {
        switch self {
        case .middle: return L("Orta tıklama")
        case .middleDrag: return L("Düzenleyicili orta tuş")
        case .zoom: return L("Yakınlaştır / uzaklaştır")
        case .volume: return L("Ses")
        case .brightness: return L("Parlaklık")
        case .pair: return L("Kısayol çifti")
        case .back: return L("Geri")
        case .forward: return L("İleri")
        case .shortcut: return L("Klavye kısayolu")
        case .system: return L("Sistem eylemi")
        case .openApp: return L("Uygulama aç")
        case .runShortcut: return L("Kestirme çalıştır")
        }
    }
}

/// Düzenleyicinin eylem seçicisi: eylem türü ve türe göre alanlar. Durum düzenleyicide tutulur.
struct EditorActionPicker: View {
    /// Sunulan eylemleri belirleyen tetik türü.
    let triggerKind: GestureKind
    @Binding var kind: EditorActionKind
    @Binding var combo: KeyCombo
    @Binding var sysAction: SystemAction
    @Binding var appPath: String
    @Binding var appName: String
    @Binding var shortcutName: String
    /// Düzenleyicili orta tuşun tuşları (⌃⌥⇧⌘ sırasıyla).
    @Binding var dragMods: [String]
    /// Yakınlaştırma yöntemi (varsayılan trackpad hareketi).
    @Binding var zoomStyle: ZoomStyle
    /// Yakınlaştırmada tekerlekle birlikte tutulan isteğe bağlı tuşlar (yalnız `wheel`; varsayılan hiçbiri).
    @Binding var zoomMods: [String]
    /// Kısayol çiftinin artırma ve azaltma kısayolları.
    @Binding var pairUp: KeyCombo
    @Binding var pairDown: KeyCombo
    @Binding var shortcutList: [String]

    var body: some View {
        Picker(L("Eylem"), selection: $kind) {
            ForEach(EditorActionKind.choices(for: triggerKind)) { Text($0.title).tag($0) }
        }
        switch kind {
        case .middleDrag:
            LabeledContent(L("Düzenleyici tuşlar")) {
                HStack(spacing: 6) {
                    ForEach(GestureAction.middleDragModifierOrder, id: \.self) { modifierChip($0, in: $dragMods) }
                }
            }
        case .zoom:
            Picker(L("Yöntem"), selection: $zoomStyle) {
                ForEach(ZoomStyle.allCases, id: \.self) { Text(Self.zoomStyleName($0)).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(Self.zoomStyleHint(zoomStyle))
                .font(.system(size: 12)).foregroundStyle(MM.text2)
                .fixedSize(horizontal: false, vertical: true)
            if zoomStyle == .wheel {
                LabeledContent(L("Tekerlekle birlikte tut (isteğe bağlı)")) {
                    HStack(spacing: 6) {
                        ForEach(GestureAction.middleDragModifierOrder, id: \.self) { modifierChip($0, in: $zoomMods) }
                    }
                }
            }
        case .shortcut:
            LabeledContent(L("Kısayol")) { ShortcutRecorder(combo: $combo) }
        case .pair:
            LabeledContent(L("Artır")) { ShortcutRecorder(combo: $pairUp) }
            LabeledContent(L("Azalt")) { ShortcutRecorder(combo: $pairDown) }
            Text(L("Yukarı kaydırmak Artır kısayolunu, aşağı kaydırmak Azalt kısayolunu her adımda bir kez gönderir."))
                .font(.system(size: 12)).foregroundStyle(MM.text2)
                .fixedSize(horizontal: false, vertical: true)
        case .system:
            Picker(L("Sistem eylemi"), selection: $sysAction) {
                ForEach(SystemAction.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        case .openApp:
            LabeledContent(L("Uygulama")) {
                Button(appName.isEmpty ? L("Seç…") : appName) {
                    if let p = AppPicker.pickApp() { appPath = p.path; appName = p.name }
                }
            }
        case .runShortcut:
            HStack {
                TextField(L("Kestirme adı"), text: $shortcutName)
                Menu(L("Seç")) {
                    if shortcutList.isEmpty { Text(L("Kestirme bulunamadı")) }
                    ForEach(shortcutList, id: \.self) { n in Button(n) { shortcutName = n } }
                }
                .fixedSize()
            }
            .onAppear { if shortcutList.isEmpty { ShortcutsCLI.list { shortcutList = $0 } } }
        default:
            EmptyView()
        }
    }

    private static func zoomStyleName(_ s: ZoomStyle) -> String {
        switch s {
        case .gesture: return L("Trackpad hareketi")
        case .wheel: return L("Fare tekerleği")
        case .keys: return L("Klavye (⌘+ / ⌘−)")
        }
    }

    private static func zoomStyleHint(_ s: ZoomStyle) -> String {
        switch s {
        case .gesture: return L("Trackpad'deki gibi yalnız içeriği büyütür (Önizleme, Safari, Haritalar, Blender…).")
        case .wheel: return L("3D programlarda tekerlekle yakınlaştırır; gerekirse bir tuşla birlikte.")
        case .keys: return L("Uygulamanın kendi ⌘+ / ⌘− komutunu kullanır; tarayıcıda bütün sayfayı büyütür.")
        }
    }

    /// Düzenleyici tuş aç/kapa çipi (⌃ ⌥ ⇧ ⌘); orta tuş ve yakınlaştırma ortak kullanır.
    private func modifierChip(_ name: String, in mods: Binding<[String]>) -> some View {
        let on = mods.wrappedValue.contains(name)
        let shape = Capsule()
        let label: String
        switch name {
        case "control": label = "⌃ Control"
        case "option": label = "⌥ Option"
        case "shift": label = "⇧ Shift"
        default: label = "⌘ Command"
        }
        return Button {
            var next = mods.wrappedValue
            if on { next.removeAll { $0 == name } } else { next.append(name) }
            mods.wrappedValue = GestureAction.normalizedModifiers(next)
        } label: {
            Text(label).font(.system(size: 12.5, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? MM.accentText : MM.text)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(on ? MM.accentSoft : MM.card, in: shape)
                .overlay(shape.strokeBorder(on ? MM.accent : MM.line, lineWidth: on ? 1.5 : 1))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
