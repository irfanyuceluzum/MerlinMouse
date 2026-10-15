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

    public init(level: ConflictLevel, title: String, detail: String, subject: String? = nil) {
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
            out.append(Conflict(level: .reserved, title: "Normal sol tıklama",
                                detail: "Tek parmakla sol bölgeye basmak normal sol tıklamadır; dönüştürülemez."))
        }
        if t.kind == .swipe, t.fingers < 3 {
            out.append(Conflict(level: .reserved, title: "Kaydırma ile karışır",
                                detail: "Bir veya iki parmakla kaydırma normal kaydırmayla karışır; en az üç parmak gerekir."))
        }
        if t.kind == .tap, t.fingers == 1 {
            out.append(Conflict(level: .reserved, title: "Fareyi tutarken kazara tetiklenir",
                                detail: "Tek parmakla dokunma, fareyi tutarken istemeden tetiklenir."))
        }
        if t.fingers == 0, t.modifier == .none {
            out.append(Conflict(level: .reserved, title: "Parmak sayısı gerekli",
                                detail: "Herhangi bir parmak yalnız Fn/Option/Command/Shift gibi tuşlu tetiklerde kullanılabilir."))
        }

        if t.kind == .hold {
            out.append(Conflict(level: .unsupported, title: "Basılı tut henüz desteklenmiyor",
                                detail: "Bu tetik şimdilik çalışmaz."))
        }

        let dup = among.contains {
            $0.id != binding.id && $0.enabled && $0.appBundleID == binding.appBundleID && $0.trigger.normalized == t
        }
        if dup {
            out.append(Conflict(level: .duplicate, title: "Aynı tetik zaten atanmış",
                                detail: "Bu kapsamda aynı tetiğe başka bir atama var."))
        }

        // Kapalı rakip varsa (açık rakip olsa da) kayıtta silineceği için her zaman bildirilir.
        for off in among where off.id != binding.id && !off.enabled && off.appBundleID == binding.appBundleID && off.trigger.normalized == t {
            out.append(Conflict(level: .replacesDisabled, title: "Kapalı bir ataması var",
                                detail: "Bu hareket kapalı '\(off.action.title)' atamasına bağlı. Kaydedersen yeni atama onun yerine geçer.",
                                subject: off.action.title))
        }

        if binding.enabled, let app = binding.appBundleID,
           let g = among.first(where: {
               $0.id != binding.id && $0.enabled && $0.appBundleID == nil && $0.trigger.normalized == t
           }) {
            out.append(Conflict(level: .shadows, title: "Genel atamanın yerine geçer",
                                detail: "\(binding.appName ?? app)'de '\(g.action.title)' yerine bu çalışır."))
        }

        if t.kind == .press, t.fingers == 1, t.zone == .right, env.mouseButtonMode == "TwoButton" {
            out.append(Conflict(level: .macOS, title: "macOS ikincil tıklama",
                                detail: "Fare ayarlarında sağ taraf ikincil tıklama olarak ayarlı."))
        }
        if t.kind == .doubleTap, t.fingers == 1, env.oneFingerDoubleTap != 0 {
            out.append(Conflict(level: .macOS, title: "macOS Akıllı büyütme",
                                detail: "Tek parmakla çift dokunma macOS'ta Akıllı büyütme olarak açık."))
        }
        if t.kind == .doubleTap, t.fingers == 2, env.twoFingerDoubleTap != 0 {
            out.append(Conflict(level: .macOS, title: "macOS Mission Control",
                                detail: "İki parmakla çift dokunma macOS'ta Mission Control olarak açık."))
        }

        if env.bttRunning, t.kind == .press, t.modifier == .none, t.fingers == 2 || t.fingers == 3 {
            out.append(Conflict(level: .btt, title: "BetterTouchTool'da da atanmış olabilir",
                                detail: "BetterTouchTool çalışıyor; aynı hareket orada da tanımlıysa iki eylem birden tetiklenebilir."))
        }

        if t.kind == .press, t.modifier == .option || t.modifier == .command || t.modifier == .shift {
            out.append(Conflict(level: .caution, title: "Uygulamalar bu tuş + tıklamayı kullanır",
                                detail: "Birçok uygulama bu düzenleyiciyle tıklamayı kendi işi için kullanır."))
        }
        return out
    }
}
