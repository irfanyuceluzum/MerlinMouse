import Foundation

/// Fiziksel basışta eşleştirmenin hangi aygıtların atamalarıyla, hangi sırayla deneneceği.
/// Amaç: fare dönüşümü trackpad yüzünden asla kaybolmasın.
public enum ClickRouting {
    /// Sıralı aygıt listesi; çağıran sırayla dener, ilk eşleşmede durur, hiçbiri eşleşmezse olay olduğu gibi geçer.
    /// - Öndeki uygulama için hiç açık trackpad ataması yoksa `ClickSource`'a bakılmaz: yalnız bugünkü fare yolu.
    /// - Kaynak trackpad ise önce trackpad; farede de taze parmak varsa ardından fare (ör. avuç trackpad'e değerken
    ///   fareye tıklama).
    /// - Kaynak fare ya da belirsizse yalnız fare yolu.
    public static func route(trackpadBindingsActive: Bool,
                             mouse: (touches: Int, lastFrame: Double),
                             trackpad: (touches: Int, lastFrame: Double),
                             now: Double) -> [InputDeviceKind] {
        guard trackpadBindingsActive else { return [.magicMouse] }
        guard ClickSource.resolve(mouse: mouse, trackpad: trackpad, now: now) == .trackpad else { return [.magicMouse] }
        let mouseFresh = mouse.touches > 0 && now - mouse.lastFrame <= ClickSource.staleAfter
        return mouseFresh ? [.trackpad, .magicMouse] : [.trackpad]
    }
}
