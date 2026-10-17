import CoreGraphics
import Foundation
import MerlinCore

/// Sol/sağ basmaları yakalar; eşleşen atamaya göre fare düğmesine çevirir ya da eylemi yürütür.
final class PressModule: InputModule {
    private var machine = PressStateMachine()

    func handle(_ type: CGEventType, _ event: CGEvent) -> ModuleResult {
        // Kuru deneme yalnız yeni basışları etkiler: yeni basış değişmeden geçer ve raporlanır;
        // önceden açılmış oturumun sürükleme/bırakma olayları normal işlenir (düğme basılı kalmaz).
        if InputState.shared.dryRun, type == .leftMouseDown || type == .rightMouseDown {
            if let binding = matchBinding(type, event) { reportDry(binding) }
            _ = machine.mouseDown(type == .leftMouseDown ? .left : .right, binding: nil, dryRun: true)
            return .pass
        }
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
            if !wasDragged, machine.didDrag, let b = machine.binding {
                switch b.action {
                case .middleClick:
                    report("\(L("Orta tuş sürükleme")) · \(b.trigger.title)")
                case .middleDrag(let mods):
                    report("\(LF("Orta tuş + %@ sürükleme", GestureAction.modifierSymbols(mods))) · \(b.trigger.title)")
                default:
                    break
                }
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

    /// Denenecek aygıtlar `ClickRouting` ile seçilir. Öndeki uygulama için açık trackpad ataması yoksa
    /// `ClickSource`'a hiç bakılmaz ve bugünkü fare yolu birebir çalışır. Kaynak trackpad çıkıp trackpad
    /// eşleşmesi yoksa, farede taze parmak varsa fare yolu da denenir; hiçbiri eşleşmezse olay geçer.
    private func matchBinding(_ type: CGEventType, _ event: CGEvent) -> GestureBinding? {
        let fnDown = type == .leftMouseDown && event.flags.contains(.maskSecondaryFn)
        let index = BindingStore.shared.index
        let bundleID = FrontApp.shared.bundleID
        guard index.hasBindings(device: .trackpad, bundleID: bundleID) else {
            return matchMouse(fnDown: fnDown, index: index, bundleID: bundleID)
        }
        let snap = TouchMonitor.shared.clickSnapshot()
        let route = ClickRouting.route(trackpadBindingsActive: true, mouse: snap.mouse,
                                       trackpad: snap.trackpad, now: snap.now)
        for device in route {
            let found: GestureBinding?
            switch device {
            case .trackpad:
                // Tek parmak yalnız köşedeyse aday olur; köşe dışındaki tek parmak tıklaması hiç değişmez.
                found = PressResolver.trackpadCandidates(fingers: snap.trackpadPoints, fnDown: fnDown,
                                                         corners: Settings.shared.trackpadCorners)
                    .lazy.compactMap { index.match($0, bundleID: bundleID, device: .trackpad) }.first
            case .magicMouse:
                found = matchMouse(fnDown: fnDown, index: index, bundleID: bundleID)
            }
            if let found { return found }
        }
        return nil
    }

    /// Bugünkü fare yolu: öndeki parmaklar, kenar şeridi süzmesi, bölgeler.
    private func matchMouse(fnDown: Bool, index: BindingIndex, bundleID: String?) -> GestureBinding? {
        let monitor = TouchMonitor.shared
        let s = Settings.shared
        // Avuç içini saymamak için yalnızca öndeki parmaklara bak.
        // Açık kenarın şeridinde duran parmak (örn. başparmak) basışta sayılmaz; kenar kapalıysa süzme yok.
        let points = monitor.excludingEdgeStrips(monitor.touches
            .map { TouchPoint(id: $0.id, x: $0.x, y: $0.front(flipped: s.flipY)) })
        let candidates = PressResolver.candidates(fingers: points, fnDown: fnDown,
                                                  layout: s.zoneLayout)
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
            // Düzenleyicili orta tuş: basma, sürükleme ve bırakmanın üçüne de aynı tuşlar eklenir.
            if case .middleDrag(let mods)? = machine.binding?.action {
                event.flags = event.flags.union(ActionExecutor.flags(forModifiers: mods))
            }
            return .pass
        }
    }

    private func reportDry(_ binding: GestureBinding) {
        let text = LF("Deneme: %@ → %@", binding.trigger.title, binding.action.title)
        DispatchQueue.main.async { AppModel.shared.recordEvent(text, dryRun: true) }
    }

    private func report(_ text: String) {
        DispatchQueue.main.async { InputTap.shared.onAction?(text) }
    }
}
