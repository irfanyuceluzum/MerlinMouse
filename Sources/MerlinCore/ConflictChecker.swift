import Foundation

public enum ConflictLevel: String, Hashable, CaseIterable {
    case reserved, unsupported, duplicate, replacesDisabled, macOS, btt, caution, shadows

    /// Kaydetmeyi engelleyen düzeyler.
    public var blocksSave: Bool {
        switch self {
        case .reserved, .unsupported, .duplicate: return true
        case .replacesDisabled, .macOS, .btt, .caution, .shadows: return false
        }
    }
}

public struct Conflict: Equatable {
    public var level: ConflictLevel
    public var title: String
    public var detail: String
    /// Çakışan atamanın eylem başlığı (yalnız `replacesDisabled`).
    public var subject: String?
    /// Kapalı rakip temel atama: kayıtta silinmez, yalnız kapalı kalır.
    public var keepsRival: Bool

    public init(level: ConflictLevel, title: String, detail: String, subject: String? = nil,
                keepsRival: Bool = false) {
        self.keepsRival = keepsRival
        self.level = level
        self.title = title
        self.detail = detail
        self.subject = subject
    }
}

/// Core tercih okumaz; ortam dışarıdan verilir.
public struct ConflictEnvironment: Equatable {
    public var mouseButtonMode: String?
    public var oneFingerDoubleTap: Int
    public var twoFingerDoubleTap: Int
    public var twoFingerHorizSwipe: Int
    public var bttRunning: Bool
    public var oneFingerHorizSwipePages: Int
    public var controlScrollZoom: Bool

    public init(mouseButtonMode: String? = nil, oneFingerDoubleTap: Int = 0,
                twoFingerDoubleTap: Int = 0, twoFingerHorizSwipe: Int = 0,
                bttRunning: Bool = false, oneFingerHorizSwipePages: Int = 0,
                controlScrollZoom: Bool = false) {
        self.oneFingerHorizSwipePages = oneFingerHorizSwipePages
        self.controlScrollZoom = controlScrollZoom
        self.mouseButtonMode = mouseButtonMode
        self.oneFingerDoubleTap = oneFingerDoubleTap
        self.twoFingerDoubleTap = twoFingerDoubleTap
        self.twoFingerHorizSwipe = twoFingerHorizSwipe
        self.bttRunning = bttRunning
    }
}

public enum ConflictChecker {
    public static func check(_ binding: GestureBinding,
                             among: [GestureBinding],
                             env: ConflictEnvironment) -> [Conflict] {
        let t = binding.trigger.normalized
        var out: [Conflict] = []

        // Ayrılmış: kullanıcı davranışını bozacak tetikler.
        if (t.kind == .press || t.kind == .hold), t.modifier == .none, t.fingers == 1,
           t.zone == .any || t.zone == .left {
            out.append(Conflict(level: .reserved, title: MerlinText.t("Normal sol tıklama"),
                                detail: MerlinText.t("Tek parmakla sol bölgeye basmak normal sol tıklamadır; dönüştürülemez.")))
        }
        if t.kind == .swipe, t.fingers < 3 {
            out.append(Conflict(level: .reserved, title: MerlinText.t("Kaydırma ile karışır"),
                                detail: MerlinText.t("Bir veya iki parmakla kaydırma normal kaydırmayla karışır; en az üç parmak gerekir.")))
        }
        if t.kind == .tap, t.fingers == 1, t.zone != .rear {
            out.append(Conflict(level: .reserved, title: MerlinText.t("Fareyi tutarken kazara tetiklenir"),
                                detail: MerlinText.t("Tek parmakla dokunma, fareyi tutarken istemeden tetiklenir.")))
        }
        if t.fingers == 0, t.modifier == .none {
            out.append(Conflict(level: .reserved, title: MerlinText.t("Parmak sayısı gerekli"),
                                detail: MerlinText.t("Herhangi bir parmak yalnız Fn/Option/Command/Shift gibi tuşlu tetiklerde kullanılabilir.")))
        }

        if t.kind == .hold {
            out.append(Conflict(level: .unsupported, title: MerlinText.t("Basılı tut henüz desteklenmiyor"),
                                detail: MerlinText.t("Bu tetik şimdilik çalışmaz.")))
        }
        // Çimdikleme ile yakınlaştırma yalnız birbirine atanır (Magic Mouse'ta macOS çimdiklemesi yok).
        // Eşleştirme yöntemden ve düzenleyiciden bağımsız: her `.zoom(style:modifiers:)` yakınlaştırmadır.
        if t.kind == .pinch, !binding.action.isZoom {
            out.append(Conflict(level: .unsupported, title: MerlinText.t("Çimdikleme yalnız yakınlaştırmaya"),
                                detail: MerlinText.t("Çimdikleme yalnız yakınlaştırma eylemine atanabilir.")))
        }
        if t.kind != .pinch, binding.action.isZoom {
            out.append(Conflict(level: .unsupported, title: MerlinText.t("Yakınlaştırma yalnız çimdiklemeyle"),
                                detail: MerlinText.t("Yakınlaştırma eylemi yalnız çimdiklemeyle kullanılır.")))
        }

        let dup = among.first {
            $0.id != binding.id && $0.enabled && $0.appBundleID == binding.appBundleID && $0.trigger.normalized == t
        }
        if let dup {
            let detail = dup.isBuiltIn
                ? MerlinText.f("Kaydedersen temel '%@' ataması kapatılır; istediğinde yeniden açabilirsin.", dup.action.title)
                : MerlinText.f("Kaydedersen önceki '%@' ataması silinir ve yerine bu geçer.", dup.action.title)
            out.append(Conflict(level: .duplicate, title: MerlinText.t("Aynı tetik zaten atanmış"),
                                detail: detail, subject: dup.action.title, keepsRival: dup.isBuiltIn))
        }

        // Kapalı rakip varsa (açık rakip olsa da) kayıtta silineceği için her zaman bildirilir.
        for off in among where off.id != binding.id && !off.enabled && off.appBundleID == binding.appBundleID && off.trigger.normalized == t {
            if off.isBuiltIn {
                out.append(Conflict(level: .replacesDisabled, title: MerlinText.t("Kapalı bir ataması var"),
                                    detail: MerlinText.t("Bu hareketin kapalı bir temel ataması var; kaydedersen yeni atama çalışır, temel atama kapalı kalır."),
                                    subject: off.action.title, keepsRival: true))
                continue
            }
            out.append(Conflict(level: .replacesDisabled, title: MerlinText.t("Kapalı bir ataması var"),
                                detail: MerlinText.f("Bu hareket kapalı '%@' atamasına bağlı. Kaydedersen yeni atama onun yerine geçer.", off.action.title),
                                subject: off.action.title))
        }

        if binding.enabled, let app = binding.appBundleID,
           let g = among.first(where: {
               $0.id != binding.id && $0.enabled && $0.appBundleID == nil && $0.trigger.normalized == t
           }) {
            out.append(Conflict(level: .shadows, title: MerlinText.t("Genel atamanın yerine geçer"),
                                detail: MerlinText.f("%@'de '%@' yerine bu çalışır.", binding.appName ?? app, g.action.title)))
        }

        if t.kind == .press, t.fingers == 1, t.zone == .right, env.mouseButtonMode == "TwoButton" {
            out.append(Conflict(level: .macOS, title: MerlinText.t("macOS ikincil tıklama"),
                                detail: MerlinText.t("Fare ayarlarında sağ taraf ikincil tıklama olarak ayarlı.")))
        }
        if t.kind == .doubleTap, t.fingers == 1, env.oneFingerDoubleTap != 0 {
            out.append(Conflict(level: .macOS, title: MerlinText.t("macOS Akıllı büyütme"),
                                detail: MerlinText.t("Tek parmakla çift dokunma macOS'ta Akıllı büyütme olarak açık.")))
        }
        if t.kind == .doubleTap, t.fingers == 2, env.twoFingerDoubleTap != 0 {
            out.append(Conflict(level: .macOS, title: MerlinText.t("macOS Mission Control"),
                                detail: MerlinText.t("İki parmakla çift dokunma macOS'ta Mission Control olarak açık.")))
        }

        if env.bttRunning, t.kind == .press, t.modifier == .none, t.fingers == 2 || t.fingers == 3 {
            out.append(Conflict(level: .btt, title: MerlinText.t("BetterTouchTool'da da atanmış olabilir"),
                                detail: MerlinText.t("BetterTouchTool çalışıyor; aynı hareket orada da tanımlıysa iki eylem birden tetiklenebilir.")))
        }

        if (t.kind == .tap || t.kind == .doubleTap), t.fingers == 1, t.zone == .rear {
            out.append(Conflict(level: .caution, title: MerlinText.t("Avuç değerken tetiklenmez"),
                                detail: MerlinText.t("Avuç değerken tetiklenmez; yalnız parmaklar kalkmışken dokunun.")))
        }

        if t.kind == .press, t.modifier == .option || t.modifier == .command || t.modifier == .shift {
            out.append(Conflict(level: .caution, title: MerlinText.t("Uygulamalar bu tuş + tıklamayı kullanır"),
                                detail: MerlinText.t("Birçok uygulama bu düzenleyiciyle tıklamayı kendi işi için kullanır.")))
        }
        return out
    }
}
