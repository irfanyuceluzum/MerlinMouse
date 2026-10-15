import Foundation

/// Core'daki kullanıcıya görünen metinlerin çeviri girişi.
/// Anahtar Türkçe kaynak metindir; Türkçe için tablo gerekmez (anahtar kendisi döner).
/// Uygulama `lookup`'ı seçili dilin tablosuna bağlar.
public enum MerlinText {
    /// Anahtardan çevrilmiş metni üretir; varsayılan: kimlik (Türkçe).
    public static var lookup: (String) -> String = { $0 }

    /// Düz metin çevirisi.
    public static func t(_ key: String) -> String {
        lookup(key)
    }

    /// Biçimli metin: çevrilmiş şablonla `String(format:)`; sayı biçimi dilden bağımsız sabit.
    public static func f(_ key: String, _ args: CVarArg...) -> String {
        String(format: lookup(key), locale: Locale(identifier: "en_US_POSIX"), arguments: args)
    }
}
