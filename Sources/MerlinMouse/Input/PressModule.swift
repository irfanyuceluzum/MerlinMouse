import CoreGraphics
import Foundation
import MerlinCore

/// Sol/sağ basmaları yakalar; eşleşen atamaya göre fare düğmesine çevirir ya da eylemi yürütür.
final class PressModule: InputModule {
    private var machine = PressStateMachine()

    func handle(_ type: CGEventType, _ event: CGEvent) -> ModuleResult {
        switch type {
        case .leftMouseDown, .rightMouseDown:
            TouchMonitor.shared.noteClick()
            let side: MouseSide = type == .leftMouseDown ? .left : .right
            let result = machine.mouseDown(side, binding: matchBinding(type, event))
            InputState.shared.middleDragActive = machine.isMiddleDragActive
            if let action = result.runAction, let binding = machine.binding {
                report("\(action.title) · \(binding.trigger.title)")
                DispatchQueue.main.async { ActionExecutor.run(action) }
            }
            return apply(result.0, event, .otherMouseDown)

        case .leftMouseDragged, .rightMouseDragged:
            let wasDragged = machine.didDrag
            let decision = machine.mouseDragged(type == .leftMouseDragged ? .left : .right)
            if !wasDragged, machine.didDrag, machine.binding?.action == .middleClick, let b = machine.binding {
                report("\(L("Orta tuş sürükleme")) · \(b.trigger.title)")
            }
            return apply(decision, event, .otherMouseDragged)

        case .leftMouseUp, .rightMouseUp:
            let decision = machine.mouseUp(type == .leftMouseUp ? .left : .right)
            InputState.shared.middleDragActive = machine.isMiddleDragActive
            if case .convert = decision, let b = machine.binding, !machine.didDrag {
                if b.action == .middleClick {
                    report("\(L("Orta tıklama")) · \(b.trigger.title)")
                } else {
                    report("\(b.action.title) · \(b.trigger.title)")
                }
            }
            return apply(decision, event, .otherMouseUp)

        default:
            return .pass
        }
    }

    private func matchBinding(_ type: CGEventType, _ event: CGEvent) -> GestureBinding? {
        let s = Settings.shared
        // Avuç içini saymamak için yalnızca öndeki parmaklara bak.
        let points = TouchMonitor.shared.touches
            .map { TouchPoint(id: $0.id, x: $0.x, y: $0.front(flipped: s.flipY)) }
        let fnDown = type == .leftMouseDown && event.flags.contains(.maskSecondaryFn)
        let candidates = PressResolver.candidates(fingers: points, fnDown: fnDown,
                                                  layout: s.zoneLayout)
        let index = BindingStore.shared.index
        let bundleID = FrontApp.shared.bundleID
        for trigger in candidates {
            if let binding = index.match(trigger, bundleID: bundleID) { return binding }
        }
        return nil
    }

    private func apply(_ decision: PressDecision, _ event: CGEvent, _ otherType: CGEventType) -> ModuleResult {
        switch decision {
        case .pass:
            return .pass
        case .drop:
            return .drop
        case .convert(let n):
            event.type = otherType
            event.setIntegerValueField(.mouseEventButtonNumber, value: n)
            return .pass
        }
    }

    private func report(_ text: String) {
        DispatchQueue.main.async { InputTap.shared.onAction?(text) }
    }
}
