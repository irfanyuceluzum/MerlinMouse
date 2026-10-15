import Foundation
import MerlinCore

/// Uygulama dili: seçimi çözer, İngilizce tabloyu `MerlinText`'e bağlar.
/// Anahtar Türkçe kaynak metindir; Türkçede tablo gerekmez.
enum Localization {
    /// Çözülmüş dil kodu: "tr" ya da "en".
    private(set) static var code = "tr"

    private static var cachedEnglish: [String: String]?

    /// Seçili dili (Sistem = Mac'in dili) çözer ve çeviri girişini ona bağlar.
    static func apply() {
        let resolved = AppLanguage.resolve(Settings.shared.language, preferred: Locale.preferredLanguages)
        code = resolved
        if resolved == "en", let table = englishTable() {
            MerlinText.lookup = { table[$0] ?? $0 }
        } else {
            MerlinText.lookup = { $0 }
        }
    }

    /// Dil adı, her zaman o dilin kendi adıyla.
    static func nativeName(of code: String) -> String {
        code == "tr" ? "Türkçe" : "English"
    }

    /// "Sistem (<çözülen dil>)" seçeneğinin etiketi.
    static var systemChoiceTitle: String {
        let resolved = AppLanguage.resolve(.system, preferred: Locale.preferredLanguages)
        return LF("Sistem (%@)", nativeName(of: resolved))
    }

    private static func englishTable() -> [String: String]? {
        if let cachedEnglish { return cachedEnglish }
        guard let url = Bundle.main.url(forResource: "Localizable", withExtension: "strings",
                                        subdirectory: nil, localization: "en"),
              let table = NSDictionary(contentsOf: url) as? [String: String] else { return nil }
        cachedEnglish = table
        return table
    }
}

/// Uygulama metni: anahtar Türkçe kaynak metindir.
func L(_ key: String) -> String { MerlinText.t(key) }

/// Biçimli uygulama metni (`%@`, `%lld`); sayı biçimi dilden bağımsız sabit.
func LF(_ key: String, _ args: CVarArg...) -> String {
    String(format: MerlinText.lookup(key), locale: Locale(identifier: "en_US_POSIX"), arguments: args)
}
