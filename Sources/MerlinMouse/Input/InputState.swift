import Foundation

/// Modüller arası paylaşılan anlık girdi durumu (ana iş parçacığında okunur/yazılır).
final class InputState {
    static let shared = InputState()

    /// Orta tuşa çevrilmiş bir basma sürüyor mu.
    var middleDragActive = false

    /// Çimdiklemeyle yakınlaştırma sürüyor mu (gerçek kaydırma düşürülür). Kapatmak için
    /// `GestureDispatcher.endPinchSession()` kullan; açık büyütme hareketini de bitirir.
    var pinchActive = false

    /// Kuru deneme: eşleşen atama yalnız raporlanır, olay değişmez ve eylem çalışmaz (Deneme modu sayfası).
    /// Açılınca süren çimdikleme oturumu kapanır.
    var dryRun = false {
        didSet { if dryRun && !oldValue { GestureDispatcher.endPinchSession() } }
    }
}
