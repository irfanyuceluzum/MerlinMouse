import Foundation

/// Bir sistem hareketinin Merlin Mouse açısından durumu.
public enum SystemGestureStatus: String, Equatable {
    case on, off, always, appLevel
}

/// Sistem hareketleri sayfasında gösterilen tek satır.
public struct SystemGestureRow: Equatable {
    public var gesture: String
    public var task: String
    public var status: SystemGestureStatus
    public var note: String
    /// Rozette sayılır: yalnız macOS'ta değiştirilebilen satırlar.
    public var isConfigurable: Bool

    /// Geriye uyum: açık ya da her zaman etkin.
    public var isOn: Bool { status == .on || status == .always }

    public init(gesture: String, task: String, status: SystemGestureStatus, note: String,
                isConfigurable: Bool = false) {
        self.gesture = gesture
        self.task = task
        self.status = status
        self.note = note
        self.isConfigurable = isConfigurable
    }
}

/// macOS'un Magic Mouse hareketleri ve Merlin Mouse açısından durumları.
public enum SystemGestureCatalog {
    /// Merlin Mouse'un çakışmadan kullanabildiği hareketler.
    public static var freeGestures: [String] { [
        MerlinText.t("Orta bölgeye tıklama"), MerlinText.t("Orta bölgede basılı sürükleme"),
        MerlinText.t("Üç parmakla dokunma"), MerlinText.t("Üç parmakla tıklama"),
        MerlinText.t("Fn + tıklama / sürükleme"),
    ] }

    /// Rozet ve tablo bu sayıyı kullanır: açık ve değiştirilebilir satırlar.
    public static func conflictCount(env: ConflictEnvironment) -> Int {
        rows(env: env).filter { $0.isConfigurable && $0.status == .on }.count
    }

    public static func rows(env: ConflictEnvironment) -> [SystemGestureRow] {
        func configurable(_ gesture: String, _ task: String, _ on: Bool) -> SystemGestureRow {
            SystemGestureRow(gesture: gesture, task: task, status: on ? .on : .off,
                             note: on ? MerlinText.t("Çakışır, atanırsa uyarı verilir")
                                      : MerlinText.t("Kullanılabilir; macOS'ta açılırsa uyarı verilir"),
                             isConfigurable: true)
        }
        var rows = [
            configurable(MerlinText.t("Sağ tarafa tıklama"), MerlinText.t("İkincil tıklama"), env.mouseButtonMode == "TwoButton"),
            configurable(MerlinText.t("Tek parmakla çift dokunma"), MerlinText.t("Akıllı büyütme"), env.oneFingerDoubleTap != 0),
            configurable(MerlinText.t("İki parmakla çift dokunma"), MerlinText.t("Mission Control"), env.twoFingerDoubleTap != 0),
            configurable(MerlinText.t("İki parmakla sola / sağa kaydırma"), MerlinText.t("Tam ekran uygulamalar arası geçiş"),
                         env.twoFingerHorizSwipe != 0),
            configurable(MerlinText.t("Tek parmakla sola / sağa kaydırma"), MerlinText.t("Sayfalar arası geçiş"),
                         env.oneFingerHorizSwipePages != 0),
            SystemGestureRow(gesture: MerlinText.t("Tek parmakla yukarı / aşağı"), task: MerlinText.t("Kaydırma"),
                             status: .always, note: MerlinText.t("Orta tuşla sürüklerken engellenir")),
            SystemGestureRow(gesture: MerlinText.t("⌃ Control + tıklama"), task: MerlinText.t("İkincil tıklama"),
                             status: .always, note: MerlinText.t("Ayrılmış, atanamaz")),
            configurable(MerlinText.t("⌃ Control + kaydırma"), MerlinText.t("Erişilebilirlik yakınlaştırması"), env.controlScrollZoom),
            SystemGestureRow(gesture: MerlinText.t("⌘ ⌥ ⇧ + tıklama"), task: MerlinText.t("Uygulamaya göre değişir"),
                             status: .appLevel, note: MerlinText.t("Profil başına kontrol edilir")),
        ]
        if env.bttRunning {
            rows.append(SystemGestureRow(gesture: "BetterTouchTool", task: MerlinText.t("2 ve 3 parmak tıklaması atanmış olabilir"),
                                         status: .on, note: MerlinText.t("Aynı harekete atarsan iki eylem birden tetiklenebilir")))
        }
        return rows
    }
}
