import Foundation

/// Geliştiricinin diğer uygulamalarından biri (Genel sayfasındaki tanıtım listesi).
public struct DeveloperApp: Equatable, Identifiable {
    public let id: String
    public let name: String
    /// Çeviri anahtarı; görünen metin `summary` ile alınır.
    public let summaryKey: String
    /// Bağlantı şimdilik çalışmayabilir (ör. gizli depo); adres buradan tek yerde değiştirilir.
    public let url: URL
    /// Uygulama paketindeki simge: `Resources/DeveloperApps/<iconName>.png`.
    public let iconName: String

    public var summary: String { MerlinText.t(summaryKey) }
}

public enum DeveloperApps {
    public static let all: [DeveloperApp] = [
        DeveloperApp(
            id: "padbridge",
            name: "PadBridge",
            summaryKey: "Android tableti ya da telefonu Mac'in trackpad'i, Touch Bar'ı, Deck'i ve klavyesi yapar.",
            url: URL(string: "https://github.com/irfanyuceluzum/PadBridge")!,
            iconName: "PadBridge"
        ),
    ]
}
