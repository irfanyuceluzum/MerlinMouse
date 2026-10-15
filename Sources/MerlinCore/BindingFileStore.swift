import Foundation

/// Atamaları `bindings.json` dosyasında saklar; ilk çalıştırmada eski ayarlardan üretir.
public final class BindingFileStore {
    public let directory: URL
    private let legacy: () -> LegacyFlags
    private let log: (String) -> Void

    public init(directory: URL, legacy: @escaping () -> LegacyFlags, log: @escaping (String) -> Void) {
        self.directory = directory
        self.legacy = legacy
        self.log = log
    }

    /// Son yüklemede bozuk dosya yedeklendiyse yedeğin adı; yoksa nil.
    public private(set) var lastRecoveredBackupName: String?

    public var fileURL: URL { directory.appendingPathComponent("bindings.json") }

    public func load() -> BindingSet {
        let fm = FileManager.default
        lastRecoveredBackupName = nil
        if !fm.fileExists(atPath: fileURL.path) {
            return fresh()
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(BindingSet.self, from: data)
        } catch {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyyMMdd-HHmmss"
            let backup = directory.appendingPathComponent("bindings.bozuk-\(f.string(from: Date())).json")
            do {
                try? fm.removeItem(at: backup)
                try fm.moveItem(at: fileURL, to: backup)
                lastRecoveredBackupName = backup.lastPathComponent
                log("bindings.json okunamadı (\(error)); \(backup.lastPathComponent) olarak taşındı, eski ayarlardan yeniden üretildi")
            } catch {
                log("bindings.json okunamadı ve yedeklenemedi: \(error)")
            }
            return fresh()
        }
    }

    public func save(_ set: BindingSet) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try enc.encode(set).write(to: fileURL, options: .atomic)
        } catch {
            log("bindings.json yazılamadı: \(error)")
        }
    }

    private func fresh() -> BindingSet {
        let set = BindingSet(bindings: DefaultBindings.from(legacy: legacy()))
        save(set)
        return set
    }
}
