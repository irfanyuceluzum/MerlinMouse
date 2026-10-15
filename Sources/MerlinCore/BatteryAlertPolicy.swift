import Foundation

/// Pil seviyesi sınıfı (renk ve vurgu için).
public enum BatteryLevelKind: Equatable {
    case normal, low, critical
}

/// Pil bildirimi kararı: hangi eşikte, kaç kez bildirilir.
public struct BatteryAlertPolicy: Equatable {
    public static let thresholds = [20, 10]
    /// Bir eşik, yüzde eşiğin bu kadar puan üstüne çıkınca yeniden bildirilebilir olur.
    public static let resetMargin = 5

    public private(set) var notified: Set<Int>

    public init(notified: Set<Int> = []) { self.notified = notified }

    public static func kind(percent: Int) -> BatteryLevelKind {
        if percent <= 10 { return .critical }
        if percent <= 20 { return .low }
        return .normal
    }

    /// Yeni okumayı işler; bildirilecek eşiği (20 ya da 10) döndürür, yoksa nil.
    /// Aynı anda birden çok eşiğin altına inilirse yalnız en düşüğü döner, diğerleri de bildirilmiş sayılır.
    public mutating func update(percent: Int) -> Int? {
        for t in Self.thresholds where percent >= t + Self.resetMargin {
            notified.remove(t)
        }
        let crossed = Self.thresholds.filter { percent <= $0 && !notified.contains($0) }
        guard let lowest = crossed.min() else { return nil }
        notified.formUnion(crossed)
        return lowest
    }

    /// SF Symbols pil simgesi adı.
    public static func symbolName(percent: Int) -> String {
        if percent >= 88 { return "battery.100" }
        if percent >= 63 { return "battery.75" }
        if percent >= 38 { return "battery.50" }
        if percent >= 13 { return "battery.25" }
        return "battery.0"
    }
}

/// Magic Mouse aygıt kimlikleri (Apple satıcı kodu 76).
public enum MagicMouseIDs {
    public static func isMagicMouse(vendorID: Int, productID: Int) -> Bool {
        vendorID == 76 && [0x030D, 0x0269, 0x0323].contains(productID)
    }
}
