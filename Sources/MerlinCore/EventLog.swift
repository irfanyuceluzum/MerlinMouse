import Foundation

/// Deneme modundaki tek bir kayıt.
public struct EventLogEntry: Equatable, Identifiable {
    public let id = UUID()
    public var date: Date
    public var text: String
    /// Kuru denemede üretildi (eylem çalıştırılmadı).
    public var dryRun: Bool

    public init(date: Date = Date(), text: String, dryRun: Bool) {
        self.date = date
        self.text = text
        self.dryRun = dryRun
    }
}

/// Son N olayı tutan halka; en yeni önce.
public struct EventLog: Equatable {
    public var capacity: Int
    /// En yeni başta.
    public private(set) var entries: [EventLogEntry] = []

    public init(capacity: Int = 12) { self.capacity = max(1, capacity) }

    public mutating func append(_ entry: EventLogEntry) {
        entries.insert(entry, at: 0)
        if entries.count > capacity { entries.removeLast(entries.count - capacity) }
    }

    public mutating func clear() { entries.removeAll() }
}
