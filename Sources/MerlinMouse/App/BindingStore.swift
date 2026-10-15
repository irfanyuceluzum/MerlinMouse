import Foundation
import Combine
import MerlinCore

/// Atamaların uygulama içi tutucusu; değişim dosyaya yazılır, dizin yeniden kurulur.
final class BindingStore: ObservableObject {
    static let shared = BindingStore()

    @Published private(set) var set: BindingSet
    private(set) var index: BindingIndex
    @Published private(set) var recoveryNotice: String?
    private let file: BindingFileStore

    var bindings: [GestureBinding] { self.set.bindings }

    private init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MerlinMouse", isDirectory: true)
        // Eski UserDefaults bayrakları yalnız göç için okunur.
        let s = Settings.shared
        file = BindingFileStore(
            directory: dir,
            legacy: {
                LegacyFlags(zoneClick: s.zoneClick, twoFingerClick: s.twoFingerClick,
                            threeFingerClick: s.threeFingerClick, threeFingerTap: s.threeFingerTap,
                            fnDrag: s.fnDrag)
            },
            log: { Log.write($0) })
        var loaded = file.load()
        // Eski sürümden kalan gereksiz 4 parmak atamalarını bir kez temizle.
        let collapsed = BindingMigrations.collapseRedundantFourFinger(loaded.bindings)
        if collapsed.count != loaded.bindings.count {
            let removed = loaded.bindings.count - collapsed.count
            loaded.bindings = collapsed
            file.save(loaded)
            Log.write("Gereksiz 4 parmak atamaları kaldırıldı: \(removed)")
        }
        // Temel hareketleri işaretle (eski dosyalarda anahtar yok).
        let tagged = BindingMigrations.tagBuiltIns(loaded.bindings)
        if tagged != loaded.bindings {
            let n = zip(tagged, loaded.bindings).filter { $0.builtInKey != $1.builtInKey }.count
            loaded.bindings = tagged
            file.save(loaded)
            Log.write("Temel hareketler işaretlendi: \(n)")
        }
        set = loaded
        index = BindingIndex(bindings: loaded.bindings)
        if let name = file.lastRecoveredBackupName {
            recoveryNotice = "Atama dosyası okunamadı; yedeği \(name) olarak saklandı ve varsayılan atamalar yüklendi."
        }
    }

    func setEnabled(id: UUID, _ enabled: Bool) {
        guard set.bindings.contains(where: { $0.id == id }) else { return }
        var next = set
        next.bindings = BindingSetOps.setEnabled(id, enabled, in: next.bindings)
        apply(next)
    }

    func upsert(_ binding: GestureBinding) {
        var next = set
        next.bindings = BindingSetOps.upsert(binding, in: next.bindings)
        apply(next)
    }

    var profiles: [ProfileApp] { self.set.profiles }

    /// Profil listesine uygulama ekler; aynı bundleID varsa eklemez.
    func addProfile(_ app: ProfileApp) {
        guard !set.profiles.contains(where: { $0.bundleID == app.bundleID }) else { return }
        var next = set
        next.profiles.append(app)
        apply(next)
    }

    /// Yalnız listeden çıkarır; o uygulamanın atamalarına dokunmaz.
    func removeProfile(bundleID: String) {
        var next = set
        next.profiles.removeAll { $0.bundleID == bundleID }
        apply(next)
    }

    func dismissRecoveryNotice() { recoveryNotice = nil }

    /// Temel atamalar silinmez (BindingSetOps.remove).
    func remove(id: UUID) {
        var next = set
        next.bindings = BindingSetOps.remove(id, in: next.bindings)
        apply(next)
    }

    /// Temel atamanın tetik ve eylemini varsayılana döndürür.
    func resetToDefault(id: UUID) {
        guard let b = set.bindings.first(where: { $0.id == id }), b.isBuiltIn else { return }
        upsert(DefaultBindings.resetToDefault(b))
    }

    private func apply(_ next: BindingSet) {
        index = BindingIndex(bindings: next.bindings)
        set = next
        file.save(next)
    }
}
