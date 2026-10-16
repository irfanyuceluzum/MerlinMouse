import Foundation

/// Hazır profildeki tek atama: tetik → eylem.
public struct PresetBinding: Equatable {
    public let trigger: Trigger
    public let action: GestureAction

    public init(trigger: Trigger, action: GestureAction) {
        self.trigger = trigger.normalized
        self.action = action
    }
}

/// Bilinen bir uygulama için hazır atama seti.
public struct AppPreset: Equatable, Identifiable {
    public let id: String
    public let name: String
    /// Bilinen paket kimlikleri (boş olabilir: kullanıcı uygulamayı seçer).
    public let bundleIDs: [String]
    /// Küçük harf; uygulama adı / kimliği aramada ve doğrulamada kullanılır.
    public let nameMatch: String
    public let bindings: [PresetBinding]
    /// Çevrilmiş kısa notlar.
    public let notes: [String]
    /// Kaynak bağlantıları (URL).
    public let sources: [String]
}

public enum AppPresets {
    /// Hazır profiller; notlar her çağrıda seçili dilde üretilir.
    public static var all: [AppPreset] {
        [
            AppPreset(
                id: "blender", name: "Blender",
                bundleIDs: ["org.blenderfoundation.blender"], nameMatch: "blender",
                bindings: [
                    PresetBinding(trigger: Trigger(kind: .press, fingers: 2), action: .middleDrag(modifiers: ["shift"])),
                    PresetBinding(trigger: Trigger(kind: .press, fingers: 3), action: .middleDrag(modifiers: ["control"])),
                    PresetBinding(trigger: Trigger(kind: .tap, fingers: 1, zone: .rear),
                                  action: .middleDrag(modifiers: ["option"])),
                ],
                notes: [
                    MerlinText.t("Orta bölgeye basıp sürükle: görünümü döndür."),
                    MerlinText.t("Shift + orta sürükleme kaydırır, Ctrl + orta sürükleme yakınlaştırır (Blender kılavuzu)."),
                    MerlinText.t("Çimdikleme genel atamadan gelir: Blender'da trackpad gibi yakınlaştırır."),
                ],
                sources: [
                    "https://docs.blender.org/manual/en/4.5/editors/3dview/navigate/navigation.html",
                    "https://docs.blender.org/manual/en/4.5/editors/preferences/input.html",
                ]),
            AppPreset(
                id: "bambu-studio", name: "Bambu Studio",
                bundleIDs: ["com.bambulab.bambu-studio"], nameMatch: "bambu",
                bindings: [
                    PresetBinding(trigger: Trigger(kind: .press, fingers: 1, zone: .center), action: .middleClick),
                    PresetBinding(trigger: Trigger(kind: .press, fingers: 2), action: .middleClick),
                    PresetBinding(trigger: Trigger(kind: .pinch, fingers: 2), action: .zoom(style: .wheel, modifiers: [])),
                ],
                notes: [
                    MerlinText.t("Sol sürükleme döndürür; orta ya da sağ sürükleme kaydırır; tekerlek yakınlaştırır."),
                    MerlinText.t("Genel atamaları değiştirsen de Bambu Studio'da bu davranış korunur."),
                    MerlinText.t("Çimdikleme bu profilde fare tekerleği gönderir."),
                ],
                sources: [
                    "https://wiki.bambulab.com/en/software/bambu-studio/3d-scene-operations",
                    "https://forum.bambulab.com/t/move-pan-and-tilt-to-right-mouse-button-left-button-selecting/33857",
                ]),
            AppPreset(
                id: "chitubox", name: "CHITUBOX",
                bundleIDs: [], nameMatch: "chitubox",
                bindings: [
                    PresetBinding(trigger: Trigger(kind: .pinch, fingers: 2), action: .zoom(style: .wheel, modifiers: ["control"])),
                ],
                notes: [
                    MerlinText.t("Sağ sürükleme döndürür (sağ bölgeye basıp sürükle)."),
                    MerlinText.t("Ctrl + tekerlek yakınlaştırır; çimdikleme bunu gönderir."),
                    MerlinText.t("Ctrl + ok tuşları görünümü kaydırır. Orta tuş davranışı belgelerde yok; genel orta tuş atamaları denenebilir."),
                ],
                sources: [
                    "https://docs.chitubox.com/en-US/chitubox-basic/v1.9.5/application-overview/ui-introduction",
                ]),
        ]
    }

    public static func preset(id: String) -> AppPreset? {
        all.first { $0.id == id }
    }

    /// Seçilen uygulama bu profile benziyor mu: bilinen kimlik ya da kimlik/ad içinde `nameMatch`.
    public static func matches(_ preset: AppPreset, bundleID: String?, name: String?) -> Bool {
        if let bundleID, preset.bundleIDs.contains(bundleID) { return true }
        let needle = preset.nameMatch.lowercased()
        guard !needle.isEmpty else { return false }
        return [bundleID, name].contains { ($0 ?? "").lowercased().contains(needle) }
    }

    /// Profili uygulamaya özel Magic Mouse atamaları olarak ekler. Aynı kapsamda aynı tetiğe sahip (açık ya da kapalı)
    /// bir Magic Mouse ataması varsa o tetik atlanır; trackpad atamaları engel sayılmaz. Mevcut hiçbir atama
    /// değiştirilmez ya da silinmez.
    public static func apply(_ preset: AppPreset, bundleID: String, appName: String,
                             to set: BindingSet) -> (set: BindingSet, added: Int, skipped: Int) {
        var next = set
        if !next.profiles.contains(where: { $0.bundleID == bundleID }) {
            next.profiles.append(ProfileApp(bundleID: bundleID, name: appName))
        }
        var added = 0, skipped = 0
        for p in preset.bindings {
            let t = p.trigger.normalized
            let taken = next.bindings.contains {
                $0.device == .magicMouse && $0.appBundleID == bundleID && $0.trigger.normalized == t
            }
            if taken {
                skipped += 1
                continue
            }
            next.bindings.append(GestureBinding(trigger: t, action: p.action, enabled: true,
                                                appBundleID: bundleID, appName: appName, builtInKey: nil))
            added += 1
        }
        return (next, added, skipped)
    }
}
