import Foundation

/// Düzenleyicinin canlı denetimi: çakışmalar, eksik alan ve kaydedilebilirlik.
public enum BindingValidation {
    public static func evaluate(_ binding: GestureBinding,
                                among: [GestureBinding],
                                env: ConflictEnvironment)
        -> (conflicts: [Conflict], missing: String?, canSave: Bool) {
        let conflicts = ConflictChecker.check(binding, among: among, env: env)
        var missing: String?
        switch binding.action {
        case .shortcut(let combo):
            if combo.keyCode == 0 && combo.display.isEmpty { missing = "Kısayol kaydedilmedi" }
        case .openApp(let path, _):
            if path.isEmpty { missing = "Uygulama seçilmedi" }
        case .runShortcut(let name):
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing = "Kestirme adı boş" }
        default:
            break
        }
        let canSave = !conflicts.contains { $0.level.blocksSave } && missing == nil
        return (conflicts, missing, canSave)
    }

    /// Kaydetme kipi: engelleyici → blocked; yineleneni onayla geçmek → override; aksi direct.
    public enum SaveMode: Equatable {
        case blocked
        case direct
        case override(Conflict)
    }

    /// Engelleyici = ayrılmış / desteklenmiyor / eksik alan. Yinelenen onayla geçilebilir.
    public static func saveMode(conflicts: [Conflict], missing: String?) -> SaveMode {
        if missing != nil { return .blocked }
        if conflicts.contains(where: { $0.level == .reserved || $0.level == .unsupported }) { return .blocked }
        if let dup = conflicts.first(where: { $0.level == .duplicate }) { return .override(dup) }
        return .direct
    }

    /// Kayıtta kapalı atama(lar) silinecekse kullanıcıya gösterilecek bilgi; yoksa nil.
    public static func removalNotice(conflicts: [Conflict]) -> String? {
        let rivals = conflicts.filter { $0.level == .replacesDisabled && !$0.keepsRival }
        guard let first = rivals.first else { return nil }
        if rivals.count == 1 {
            return "Kaydedersen kapalı '\(first.subject ?? "başka bir")' ataması silinir ve yerine bu geçer."
        }
        return "Kaydedersen kapalı \(rivals.count) atama silinir ve yerine bu geçer."
    }

    /// Tek kartta gösterilecek en ağır çakışma.
    public static func heaviest(_ conflicts: [Conflict]) -> Conflict? {
        let order: [ConflictLevel] = [.reserved, .unsupported, .duplicate, .macOS, .btt, .shadows, .caution, .replacesDisabled]
        for level in order {
            if let c = conflicts.first(where: { $0.level == level }) { return c }
        }
        return nil
    }
}
