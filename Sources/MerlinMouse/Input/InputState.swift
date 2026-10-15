import Foundation

/// Modüller arası paylaşılan anlık girdi durumu (ana iş parçacığında okunur/yazılır).
final class InputState {
    static let shared = InputState()

    /// Orta tuşa çevrilmiş bir basma sürüyor mu.
    var middleDragActive = false
}
