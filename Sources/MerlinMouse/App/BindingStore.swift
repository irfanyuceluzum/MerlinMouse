import Foundation
import Combine
import MerlinCore

/// Atamaların uygulama içi tutucusu; değişim dosyaya yazılır, dizin yeniden kurulur.
final class BindingStore: ObservableObject {
    static let shared = BindingStore()

    @Published private(set) var set: BindingSet
    private(set) var index: BindingIndex
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
        let loaded = file.load()
        set = loaded
        index = BindingIndex(bindings: loaded.bindings)
    }

    func setEnabled(id: UUID, _ enabled: Bool) {
        guard let i = set.bindings.firstIndex(where: { $0.id == id }) else { return }
        var next = set
        next.bindings[i].enabled = enabled
        apply(next)
    }

    func upsert(_ binding: GestureBinding) {
        var next = set
        if let i = next.bindings.firstIndex(where: { $0.id == binding.id }) {
            next.bindings[i] = binding
        } else {
            next.bindings.append(binding)
        }
        apply(next)
    }

    func remove(id: UUID) {
        var next = set
        next.bindings.removeAll { $0.id == id }
        apply(next)
    }

    private func apply(_ next: BindingSet) {
        index = BindingIndex(bindings: next.bindings)
        set = next
        file.save(next)
    }
}
