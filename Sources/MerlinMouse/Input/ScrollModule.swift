import CoreGraphics
import MerlinCore

/// Kaydırma olaylarını düşürme kuralları (orta tuş sürüklemesi, çimdikleme, 3D atalet).
final class ScrollModule: InputModule {
    func handle(_ type: CGEventType, _ event: CGEvent) -> ModuleResult {
        guard type == .scrollWheel else { return .pass }
        let settings = Settings.shared
        let drop = ScrollPolicy.shouldDrop(
            middleDragActive: InputState.shared.middleDragActive,
            blockWhileDragging: settings.blockScrollWhileDragging,
            calm3D: settings.calm3DScroll,
            frontIs3D: FrontApp.shared.is3D,
            momentumPhase: event.getIntegerValueField(.scrollWheelEventMomentumPhase),
            pinchActive: InputState.shared.pinchActive)
        return drop ? .drop : .pass
    }
}
