import Foundation

/// Başka bir fare uygulamasının Merlin Mouse'la çakışabileceği alan.
public enum MouseUtilityOverlap: String, CaseIterable, Hashable {
    /// Magic Mouse hareketlerini işler.
    case gestures
    /// Kaydırmayı değiştirir.
    case scroll
    /// Fare tuşlarını değiştirir.
    case buttons

    /// Kullanıcıya gösterilen tek cümlelik açıklama.
    public var sentence: String {
        switch self {
        case .gestures: return MerlinText.t("Magic Mouse hareketlerini işler; aynı hareket iki kez çalışabilir.")
        case .scroll: return MerlinText.t("Kaydırmayı değiştirir; çimdikleme ve kenar kaydırmada kaydırma engeli beklenmedik davranabilir.")
        case .buttons: return MerlinText.t("Fare tuşlarını değiştirir; orta tuş dönüşümü iki kez işlenebilir.")
        }
    }
}

/// Merlin Mouse'la aynı olayları işleyebilecek bilinen bir fare uygulaması.
public struct MouseUtility: Hashable, Identifiable {
    public let id: String
    public let name: String
    /// Paket kimliği önekleri (büyük/küçük harf duyarsız).
    public let bundleIDPrefixes: [String]
    /// Uygulama adında aranan anahtar kelimeler (büyük/küçük harf duyarsız).
    public let nameKeywords: [String]
    public let overlaps: Set<MouseUtilityOverlap>

    public init(id: String, name: String, bundleIDPrefixes: [String], nameKeywords: [String],
                overlaps: Set<MouseUtilityOverlap>) {
        self.id = id
        self.name = name
        self.bundleIDPrefixes = bundleIDPrefixes
        self.nameKeywords = nameKeywords
        self.overlaps = overlaps
    }

    public var warningTitle: String { MerlinText.f("%@ çalışıyor", name) }

    /// Çakışma türlerinin cümleleri, sabit sırayla (hareket, kaydırma, tuş) birleştirilmiş.
    public var warningDetail: String {
        MouseUtilityOverlap.allCases.filter { overlaps.contains($0) }.map(\.sentence).joined(separator: " ")
    }

    /// Çalışan bir uygulama bu kayda uyuyor mu? Merlin Mouse ve BetterTouchTool hiçbir zaman uymaz.
    public func matches(bundleID: String?, name appName: String?) -> Bool {
        if MouseUtilityCatalog.isExcluded(bundleID: bundleID, name: appName) { return false }
        if let id = bundleID?.lowercased(),
           bundleIDPrefixes.contains(where: { id.hasPrefix($0.lowercased()) }) {
            return true
        }
        if let n = appName?.lowercased(),
           nameKeywords.contains(where: { n.contains($0.lowercased()) }) {
            return true
        }
        return false
    }
}

/// Bilinen fare uygulamaları ve çalışanlar arasından eşleşenleri bulma.
public enum MouseUtilityCatalog {
    public static let all: [MouseUtility] = [
        MouseUtility(id: "macmousefix", name: "Mac Mouse Fix",
                     bundleIDPrefixes: ["com.nuebling.mac-mouse-fix"], nameKeywords: ["mac mouse fix"],
                     overlaps: [.scroll, .buttons]),
        MouseUtility(id: "jitouch", name: "Jitouch",
                     bundleIDPrefixes: ["com.jitouch"], nameKeywords: ["jitouch"],
                     overlaps: [.gestures]),
        MouseUtility(id: "middleclick", name: "MiddleClick",
                     bundleIDPrefixes: ["art.ginzburg.middleclick"], nameKeywords: ["middleclick"],
                     overlaps: [.gestures]),
        MouseUtility(id: "steermouse", name: "SteerMouse",
                     bundleIDPrefixes: ["jp.plentycom.boa.steermouse"], nameKeywords: ["steermouse"],
                     overlaps: [.buttons, .scroll]),
        MouseUtility(id: "linearmouse", name: "LinearMouse",
                     bundleIDPrefixes: ["com.lujjjh.linearmouse"], nameKeywords: ["linearmouse"],
                     overlaps: [.scroll, .buttons]),
        MouseUtility(id: "scrollreverser", name: "Scroll Reverser",
                     bundleIDPrefixes: ["com.pilotmoon.scroll-reverser"], nameKeywords: ["scroll reverser"],
                     overlaps: [.scroll]),
        // Ad çok kısa ve genel ("Mosaic" gibi); yalnız paket kimliğiyle eşleşir.
        MouseUtility(id: "mos", name: "Mos",
                     bundleIDPrefixes: ["com.caldis.mos"], nameKeywords: [],
                     overlaps: [.scroll]),
        MouseUtility(id: "smoothscroll", name: "SmoothScroll",
                     bundleIDPrefixes: [], nameKeywords: ["smoothscroll"],
                     overlaps: [.scroll]),
        MouseUtility(id: "logioptions", name: "Logi Options+",
                     bundleIDPrefixes: ["com.logi.optionsplus"], nameKeywords: ["logi options", "logioptionsplus"],
                     overlaps: [.buttons, .scroll]),
        MouseUtility(id: "usboverdrive", name: "USB Overdrive",
                     bundleIDPrefixes: [], nameKeywords: ["usb overdrive"],
                     overlaps: [.buttons, .scroll]),
    ]

    /// Merlin Mouse'un kendisi ve (kendi `.btt` mantığı olan) BetterTouchTool.
    static func isExcluded(bundleID: String?, name: String?) -> Bool {
        if let id = bundleID?.lowercased(),
           id.hasPrefix("dev.merlinmouse") || id.hasPrefix("com.hegenberg.bettertouchtool") {
            return true
        }
        if let n = name?.lowercased(), n.contains("bettertouchtool") { return true }
        return false
    }

    /// Çalışan uygulamalardan eşleşen fare uygulamaları; tekrarsız, katalog sırasıyla.
    public static func detect(running: [(bundleID: String?, name: String?)]) -> [MouseUtility] {
        all.filter { u in running.contains { u.matches(bundleID: $0.bundleID, name: $0.name) } }
    }
}
