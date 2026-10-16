import Combine
import Foundation

/// Trackpad'deki canlı parmaklar (ana kuyrukta yayınlanır). `AppModel`'den ayrı tutulur: trackpad sık kullanıldığı
/// için her kare `AppModel`'i dinleyen tüm görünümleri yeniden çizdirmesin; yalnız bunu dinleyen görünüm güncellenir.
final class TrackpadLiveTouches: ObservableObject {
    static let shared = TrackpadLiveTouches()

    @Published private(set) var touches: [Touch] = []

    /// Ana kuyrukta çağrılır; boştan boşa yineleyen kareler yayınlanmaz.
    func update(_ next: [Touch]) {
        if next.isEmpty && touches.isEmpty { return }
        touches = next
    }
}
