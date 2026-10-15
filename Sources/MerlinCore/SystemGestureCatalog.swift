import Foundation

/// Sistem hareketleri sayfasında gösterilen tek satır.
public struct SystemGestureRow: Equatable {
    public var gesture: String
    public var task: String
    public var isOn: Bool
    public var note: String
    /// Rozette sayılır: yalnız macOS'ta değiştirilebilen satırlar.
    public var isConfigurable: Bool

    public init(gesture: String, task: String, isOn: Bool, note: String, isConfigurable: Bool = false) {
        self.gesture = gesture
        self.task = task
        self.isOn = isOn
        self.note = note
        self.isConfigurable = isConfigurable
    }
}

/// macOS'un Magic Mouse hareketleri ve Merlin Mouse açısından durumları.
public enum SystemGestureCatalog {
    public static func rows(env: ConflictEnvironment) -> [SystemGestureRow] {
        func note(_ on: Bool) -> String {
            on ? "Atanırsa uyarı verilir" : "Kullanılabilir; macOS'ta açılırsa uyarı verilir"
        }
        var rows = [
            SystemGestureRow(gesture: "Sağ tarafa tıklama", task: "İkincil tıklama",
                             isOn: env.mouseButtonMode == "TwoButton",
                             note: note(env.mouseButtonMode == "TwoButton"), isConfigurable: true),
            SystemGestureRow(gesture: "Tek parmakla çift dokunma", task: "Akıllı büyütme",
                             isOn: env.oneFingerDoubleTap != 0, note: note(env.oneFingerDoubleTap != 0), isConfigurable: true),
            SystemGestureRow(gesture: "İki parmakla çift dokunma", task: "Mission Control",
                             isOn: env.twoFingerDoubleTap != 0, note: note(env.twoFingerDoubleTap != 0), isConfigurable: true),
            SystemGestureRow(gesture: "İki parmakla yana kaydırma", task: "Tam ekran uygulamalar arası geçiş",
                             isOn: env.twoFingerHorizSwipe != 0, note: note(env.twoFingerHorizSwipe != 0), isConfigurable: true),
            SystemGestureRow(gesture: "Tek parmakla kaydırma", task: "Kaydırma",
                             isOn: true, note: "Ayrılmış, atanamaz"),
            SystemGestureRow(gesture: "⌃ Control + tıklama", task: "İkincil tıklama",
                             isOn: true, note: "Ayrılmış, atanamaz"),
        ]
        if env.bttRunning {
            rows.append(SystemGestureRow(gesture: "BetterTouchTool", task: "2 ve 3 parmak tıklaması atanmış olabilir",
                                         isOn: true, note: "Aynı harekete atarsan iki eylem birden tetiklenebilir"))
        }
        return rows
    }
}
