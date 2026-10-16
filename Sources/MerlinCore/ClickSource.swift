import Foundation

/// Fiziksel tıklamanın hangi dokunma aygıtından geldiğini, aygıtların son karelerinden kestirir.
public enum ClickSource {
    /// Bundan eski bir kare parmak sayılmaz (sn).
    public static let staleAfter: Double = 0.25

    /// Yalnız birinde (taze) parmak varsa o aygıt; ikisinde de varsa son karesi daha yeni olan (eşitlikte fare);
    /// hiçbirinde yoksa nil (çağıran bugünkü fare yolunu çalıştırır). `lastFrame` ve `now` aynı saatte olmalı.
    public static func resolve(mouse: (touches: Int, lastFrame: Double),
                               trackpad: (touches: Int, lastFrame: Double),
                               now: Double) -> InputDeviceKind? {
        let m = mouse.touches > 0 && now - mouse.lastFrame <= staleAfter
        let t = trackpad.touches > 0 && now - trackpad.lastFrame <= staleAfter
        switch (m, t) {
        case (true, false): return .magicMouse
        case (false, true): return .trackpad
        case (true, true): return trackpad.lastFrame > mouse.lastFrame ? .trackpad : .magicMouse
        case (false, false): return nil
        }
    }
}
