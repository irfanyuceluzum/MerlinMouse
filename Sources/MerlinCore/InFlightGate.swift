import Foundation

/// Aynı anahtarlı işin üst üste çalışmasını önleyen iş parçacığı güvenli kapı (ör. aynı adlı kestirme).
/// `tryBegin` doğru dönerse iş başlar ve her yolda (`defer`) `end` çağrılmalıdır. Farklı anahtarlar birbirini etkilemez.
public final class InFlightGate<Key: Hashable> {
    /// Giriş isteğinin sonucu.
    public enum Admission: Equatable {
        case begun
        /// Aynı anahtar zaten çalışıyor; `firstRejection` bu çalışma sürerken ilk geri çevirme mi (günlüğe bir kez).
        case busy(firstRejection: Bool)
    }

    private let lock = NSLock()
    private var running: Set<Key> = []
    private var reported: Set<Key> = []

    public init() {}

    public func admit(_ key: Key) -> Admission {
        lock.lock(); defer { lock.unlock() }
        if running.contains(key) {
            let first = reported.insert(key).inserted
            return .busy(firstRejection: first)
        }
        running.insert(key)
        return .begun
    }

    /// Anahtar boşsa işi başlatır ve doğru döner; çalışıyorsa yanlış.
    public func tryBegin(_ key: Key) -> Bool {
        admit(key) == .begun
    }

    /// İşi bitirir; anahtar yeniden girilebilir olur.
    public func end(_ key: Key) {
        lock.lock(); defer { lock.unlock() }
        running.remove(key)
        reported.remove(key)
    }

    public func isRunning(_ key: Key) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return running.contains(key)
    }
}
