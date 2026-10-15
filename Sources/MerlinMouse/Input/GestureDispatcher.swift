import Foundation
import MerlinCore

/// Tanınan basmasız hareketleri atamalarla eşleştirip eylemi yürütür (ana kuyruk).
enum GestureDispatcher {
    static func handle(_ gestures: [RecognizedGesture]) {
        for gesture in gestures {
            let trigger = gesture.trigger
            guard Settings.shared.enabled, !AppModel.shared.isPaused, InputTap.shared.isRunning,
                  let binding = BindingStore.shared.index.match(trigger, bundleID: FrontApp.shared.bundleID)
            else { continue }
            ActionExecutor.run(binding.action)
            InputTap.shared.onAction?("\(binding.action.title) · \(trigger.title)")
        }
    }
}
