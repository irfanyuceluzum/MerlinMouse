import CoreGraphics
import MerlinCore

/// Kaydırma olaylarını düşürme kuralları (orta tuş sürüklemesi, çimdikleme, kenar kaydırma, 3D atalet).
final class ScrollModule: InputModule {
    func handle(_ type: CGEventType, _ event: CGEvent) -> ModuleResult {
        guard type == .scrollWheel else { return .pass }
        let settings = Settings.shared
        let state = InputState.shared
        // Geri çağrı iş parçacığının canlı bayrakları: oturum başladı ama ana kuyruğa henüz ulaşmadı.
        let live = TouchMonitor.shared.liveScroll.read()
        let drop = ScrollPolicy.shouldDrop(
            middleDragActive: state.middleDragActive,
            blockWhileDragging: settings.blockScrollWhileDragging,
            calm3D: settings.calm3DScroll,
            frontIs3D: FrontApp.shared.is3D,
            momentumPhase: event.getIntegerValueField(.scrollWheelEventMomentumPhase),
            // Kuru denemede olaylar değişmez (`pinchActive` kuru denemede zaten açılmaz).
            pinchActive: state.pinchActive || (live.pinch && !state.dryRun),
            // Kuru denemede olaylar değişmez: kenarda başlayan kaydırma da geçer.
            edgeActive: (state.edgeActive || live.edge) && !state.dryRun)
        return drop ? .drop : .pass
    }
}
