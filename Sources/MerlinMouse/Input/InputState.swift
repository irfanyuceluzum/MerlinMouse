import Foundation

/// Modüller arası paylaşılan anlık girdi durumu (ana iş parçacığında okunur/yazılır).
final class InputState {
    static let shared = InputState()

    /// Orta tuşa çevrilmiş bir basma sürüyor mu.
    var middleDragActive = false

    /// Çimdiklemeyle yakınlaştırma sürüyor mu (gerçek kaydırma düşürülür). Kapatmak için
    /// `GestureDispatcher.endPinchSession()` kullan; açık büyütme hareketini de bitirir.
    var pinchActive = false

    /// Kenar hareketi başladı (gerçek kaydırma düşürülür; adaylıkta geçer). `TouchMonitor` tanıyıcının canlı
    /// durumunu yazar; kapanış yollarında `GestureDispatcher.endEdgeSession()` sıfırlar.
    var edgeActive = false

    /// Kuru deneme: eşleşen atama yalnız raporlanır, olay değişmez ve eylem çalışmaz (Bölgeler sayfası).
    /// Açılınca süren çimdikleme ve kenar kaydırma oturumu kapanır.
    var dryRun = false {
        didSet {
            if dryRun && !oldValue {
                GestureDispatcher.endPinchSession()
                GestureDispatcher.endEdgeSession()
            }
        }
    }
}
