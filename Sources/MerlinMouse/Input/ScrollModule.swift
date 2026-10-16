import CoreGraphics
import MerlinCore

/// Kaydırma olaylarını düşürme kuralları (orta tuş sürüklemesi, çimdikleme, kenar kaydırma, 3D atalet).
final class ScrollModule: InputModule {
    func handle(_ type: CGEventType, _ event: CGEvent) -> ModuleResult {
        guard type == .scrollWheel else { return .pass }
        let settings = Settings.shared
        let state = InputState.shared
        let drop = ScrollPolicy.shouldDrop(
            middleDragActive: state.middleDragActive,
            blockWhileDragging: settings.blockScrollWhileDragging,
            calm3D: settings.calm3DScroll,
            frontIs3D: FrontApp.shared.is3D,
            momentumPhase: event.getIntegerValueField(.scrollWheelEventMomentumPhase),
            pinchActive: state.pinchActive,
            // Kuru denemede olaylar değişmez: kenarda başlayan kaydırma da geçer.
            edgeActive: state.edgeActive && !state.dryRun)
        return drop ? .drop : .pass
    }
}
