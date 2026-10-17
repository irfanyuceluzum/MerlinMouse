import Foundation

/// Trackpad sistem hareketleri tablosunun bir bölümü.
public struct TrackpadGestureSection: Equatable {
    public var title: String
    public var rows: [SystemGestureRow]

    public init(title: String, rows: [SystemGestureRow]) {
        self.title = title
        self.rows = rows
    }
}

/// macOS'un trackpad hareketleri ve Merlin Mouse açısından durumları (`ConflictEnvironment`'ın trackpad alanları).
/// Rozette sayılan (`isConfigurable`) satırlar, Merlin Mouse'un trackpad atamalarıyla çakışabilen ve macOS'ta
/// kapatılabilen hareketlerdir (köşeden ikincil tıklama ve üç parmak hareketleri); diğerleri yalnız bilgi verir.
public enum TrackpadGestureCatalog {
    /// macOS'un trackpad'de kullanmadığı, Merlin Mouse'un atayabildiği serbest hareketler.
    public static var freeGestures: [String] { [
        MerlinText.t("Üç parmakla dokunma"), MerlinText.t("Üç parmakla basma"), MerlinText.t("Dört parmakla dokunma"),
    ] }

    public static func sections(env: ConflictEnvironment) -> [TrackpadGestureSection] {
        func conflicting(_ gesture: String, _ task: String, _ on: Bool) -> SystemGestureRow {
            SystemGestureRow(gesture: gesture, task: task, status: on ? .on : .off,
                             note: on ? MerlinText.t("Çakışır, atanırsa uyarı verilir")
                                      : MerlinText.t("Kullanılabilir; macOS'ta açılırsa uyarı verilir"),
                             isConfigurable: true)
        }
        func info(_ gesture: String, _ task: String, _ on: Bool) -> SystemGestureRow {
            SystemGestureRow(gesture: gesture, task: task, status: on ? .on : .off,
                             note: MerlinText.t("Merlin Mouse'un trackpad hareketleriyle çakışmaz"))
        }
        func always(_ gesture: String, _ task: String) -> SystemGestureRow {
            SystemGestureRow(gesture: gesture, task: task, status: .always,
                             note: MerlinText.t("Her zaman açık; Merlin Mouse kullanmaz"))
        }
        return [
            TrackpadGestureSection(title: MerlinText.t("Dokunma ve tıklama"), rows: [
                info(MerlinText.t("Tek parmakla dokunma"), MerlinText.t("Dokunarak tıklama"), env.trackpadTapToClick),
                always(MerlinText.t("İki parmakla tıklama / dokunma"), MerlinText.t("İkincil tıklama")),
                conflicting(MerlinText.t("Köşeden ikincil tıklama"), MerlinText.t("İkincil tıklama"),
                            env.trackpadCornerSecondaryClick != 0),
                conflicting(MerlinText.t("Üç parmakla dokunma"), MerlinText.t("Bak ve veri algılayıcıları"),
                            env.threeFingerTapLookup),
            ]),
            TrackpadGestureSection(title: MerlinText.t("Kaydırma ve yakınlaştırma"), rows: [
                always(MerlinText.t("İki parmakla kaydırma"), MerlinText.t("Kaydırma")),
                info(MerlinText.t("İki parmakla çimdikleme"), MerlinText.t("Yakınlaştırma / uzaklaştırma"), env.trackpadPinch),
                info(MerlinText.t("İki parmakla çift dokunma"), MerlinText.t("Akıllı büyütme"), env.trackpadSmartZoom),
                info(MerlinText.t("İki parmakla döndürme"), MerlinText.t("Döndürme"), env.trackpadRotate),
            ]),
            TrackpadGestureSection(title: MerlinText.t("Diğer hareketler"), rows: [
                conflicting(MerlinText.t("Üç parmakla sola / sağa kaydırma"),
                            MerlinText.t("Sayfalar ya da tam ekran uygulamalar arası geçiş"),
                            env.threeFingerHorizSwipe != 0),
                conflicting(MerlinText.t("Üç parmakla yukarı / aşağı kaydırma"),
                            MerlinText.t("Mission Control ve Uygulama Exposé"),
                            env.threeFingerVertSwipe != 0),
                info(MerlinText.t("Sağ kenardan iki parmakla kaydırma"), MerlinText.t("Bildirim Merkezi"),
                     env.notificationCenterSwipe),
                info(MerlinText.t("Başparmak ve üç parmakla çimdikleme"), MerlinText.t("Launchpad ve masaüstünü göster"),
                     env.fiveFingerPinch),
            ]),
            TrackpadGestureSection(title: MerlinText.t("Erişilebilirlik"), rows: [
                conflicting(MerlinText.t("Üç parmakla sürükleme"), MerlinText.t("Pencere ve öğe sürükleme"),
                            env.threeFingerDrag),
            ]),
        ]
    }

    /// Tüm satırlar, bölüm sırasıyla.
    public static func rows(env: ConflictEnvironment) -> [SystemGestureRow] {
        sections(env: env).flatMap(\.rows)
    }

    /// Rozet: açık ve Merlin Mouse'un trackpad atamalarıyla çakışabilen satırlar.
    public static func conflictCount(env: ConflictEnvironment) -> Int {
        rows(env: env).filter { $0.isConfigurable && $0.status == .on }.count
    }
}
