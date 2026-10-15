import Foundation

/// Uygulama dili seçimi: Sistem / Türkçe / English.
public enum AppLanguage: String, CaseIterable {
    case system, tr, en

    /// Desteklenen dil kodunu (`tr` ya da `en`) çözer.
    /// `system`: tercih listesindeki ilk `tr`/`en` önekli dil; hiçbiri yoksa `en`.
    public static func resolve(_ choice: AppLanguage, preferred: [String]) -> String {
        switch choice {
        case .tr: return "tr"
        case .en: return "en"
        case .system:
            for tag in preferred {
                let lower = tag.lowercased()
                if lower.hasPrefix("tr") { return "tr" }
                if lower.hasPrefix("en") { return "en" }
            }
            return "en"
        }
    }

    /// Kayıtlı metinden seçim; tanınmayan değer `system` sayılır.
    public static func from(stored: String) -> AppLanguage {
        AppLanguage(rawValue: stored) ?? .system
    }

    /// `resolve` için ham metin kolaylığı.
    public static func resolve(_ stored: String, preferred: [String]) -> String {
        resolve(from(stored: stored), preferred: preferred)
    }
}
