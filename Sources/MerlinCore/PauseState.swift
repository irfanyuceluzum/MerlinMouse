import Foundation

/// Geçici duraklatma durumu (panel kartı kullanır).
public struct PauseState: Equatable {
    public var pausedUntil: Date?

    public init(pausedUntil: Date? = nil) {
        self.pausedUntil = pausedUntil
    }

    public func isPaused(now: Date) -> Bool {
        guard let until = pausedUntil else { return false }
        return now < until
    }

    public static func pausing(for interval: TimeInterval, from now: Date) -> PauseState {
        PauseState(pausedUntil: now.addingTimeInterval(interval))
    }
}
