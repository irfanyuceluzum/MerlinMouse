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
}
