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
    public static let freeGestures: [String] = [
        "Orta bölgeye tıklama", "Orta bölgede basılı sürükleme", "Üç parmakla dokunma",
        "Üç parmakla tıklama", "Fn + tıklama / sürükleme",
    ]

    /// Rozet ve tablo bu sayıyı kullanır: açık ve değiştirilebilir satırlar.
    public static func conflictCount(env: ConflictEnvironment) -> Int {
        rows(env: env).filter { $0.isConfigurable && $0.status == .on }.count
    }

    public static func rows(env: ConflictEnvironment) -> [SystemGestureRow] {
        func configurable(_ gesture: String, _ task: String, _ on: Bool) -> SystemGestureRow {
            SystemGestureRow(gesture: gesture, task: task, status: on ? .on : .off,
                             note: on ? "Çakışır, atanırsa uyarı verilir"
                                      : "Kullanılabilir; macOS'ta açılırsa uyarı verilir",
                             isConfigurable: true)
        }
        var rows = [
            configurable("Sağ tarafa tıklama", "İkincil tıklama", env.mouseButtonMode == "TwoButton"),
            configurable("Tek parmakla çift dokunma", "Akıllı büyütme", env.oneFingerDoubleTap != 0),
            configurable("İki parmakla çift dokunma", "Mission Control", env.twoFingerDoubleTap != 0),
            configurable("İki parmakla sola / sağa kaydırma", "Tam ekran uygulamalar arası geçiş",
                         env.twoFingerHorizSwipe != 0),
            configurable("Tek parmakla sola / sağa kaydırma", "Sayfalar arası geçiş",
                         env.oneFingerHorizSwipePages != 0),
            SystemGestureRow(gesture: "Tek parmakla yukarı / aşağı", task: "Kaydırma",
                             status: .always, note: "Orta tuşla sürüklerken engellenir"),
            SystemGestureRow(gesture: "⌃ Control + tıklama", task: "İkincil tıklama",
                             status: .always, note: "Ayrılmış, atanamaz"),
            configurable("⌃ Control + kaydırma", "Erişilebilirlik yakınlaştırması", env.controlScrollZoom),
            SystemGestureRow(gesture: "⌘ ⌥ ⇧ + tıklama", task: "Uygulamaya göre değişir",
                             status: .appLevel, note: "Profil başına kontrol edilir"),
        ]
        if env.bttRunning {
            rows.append(SystemGestureRow(gesture: "BetterTouchTool", task: "2 ve 3 parmak tıklaması atanmış olabilir",
                                         status: .on, note: "Aynı harekete atarsan iki eylem birden tetiklenebilir"))
        }
        return rows
    }
}
