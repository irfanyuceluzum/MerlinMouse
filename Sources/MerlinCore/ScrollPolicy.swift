import Foundation

/// Kaydırma olayının düşürülüp düşürülmeyeceği kararı.
public enum ScrollPolicy {
    public static func shouldDrop(middleDragActive: Bool, blockWhileDragging: Bool,
                                  calm3D: Bool, frontIs3D: Bool, momentumPhase: Int64) -> Bool {
        // Orta tuşla sürüklerken yüzeye değen parmak modeli yakınlaştırmasın.
        if middleDragActive && blockWhileDragging { return true }
        // 3D programlarda ataletli kaydırmayı at.
        return calm3D && frontIs3D && momentumPhase != 0
    }
}
