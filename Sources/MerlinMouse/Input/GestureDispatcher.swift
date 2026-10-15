import Foundation
import MerlinCore

/// Tanınan basmasız hareketleri atamalarla eşleştirip eylemi yürütür (ana kuyruk).
enum GestureDispatcher {
    /// Etkin çimdikleme oturumunda eşleşen yakınlaştırma atamasının yöntemi ve düzenleyicileri (ana kuyruk).
    private static var pinchStyle: ZoomStyle = .gesture
    private static var pinchModifiers: [String] = []
    /// Büyütme hareketi açık mı: "başladı" gönderildi, "bitti" henüz gönderilmedi.
    private static var magnifyOpen = false

    static func handle(_ gestures: [RecognizedGesture]) {
        for gesture in gestures {
            let trigger = gesture.trigger
            guard Settings.shared.enabled, !AppModel.shared.isPaused, InputTap.shared.isRunning,
                  let binding = BindingStore.shared.index.match(trigger, bundleID: FrontApp.shared.bundleID)
            else { continue }
            if InputState.shared.dryRun {
                AppModel.shared.recordEvent(LF("Deneme: %@ → %@", trigger.title, binding.action.title), dryRun: true)
                continue
            }
            ActionExecutor.run(binding.action)
            InputTap.shared.onAction?("\(binding.action.title) · \(trigger.title)")
        }
    }

    /// Çimdikleme olayları (ana kuyruk): başlangıçta eşleştirir ve bir kez raporlar, sonra yönteme göre
    /// `gesture`'da sürekli büyütme (`.moved`), `wheel` / `keys`'te adım adım (`.step`) yakınlaştırır.
    /// `pinchActive` yalnız gerçek (kuru olmayan) oturumda açılır; her kapanış `endPinchSession`'dan geçer.
    static func handlePinch(_ events: [PinchEvent]) {
        let state = InputState.shared
        for event in events {
            switch event {
            case .began:
                endPinchSession()
                let trigger = Trigger(kind: .pinch, fingers: 2)
                guard Settings.shared.enabled, !AppModel.shared.isPaused, InputTap.shared.isRunning,
                      let binding = BindingStore.shared.index.match(trigger, bundleID: FrontApp.shared.bundleID),
                      case .zoom(let style, let modifiers) = binding.action
                else { continue }
                if state.dryRun {
                    AppModel.shared.recordEvent(LF("Deneme: %@ → %@", trigger.title, binding.action.title), dryRun: true)
                    continue
                }
                pinchStyle = style
                pinchModifiers = GestureAction.zoomModifiers(modifiers, style: style)
                state.pinchActive = true
                if style == .gesture {
                    magnifyOpen = true
                    ActionExecutor.magnify(phase: ActionExecutor.Magnify.phaseBegan, amount: 0)
                }
                InputTap.shared.onAction?("\(binding.action.title) · \(trigger.title)")
            case .moved(let distance):
                guard sessionContinues(), pinchStyle == .gesture else { continue }
                // Hassasiyet arttıkça (adım küçüldükçe) büyütme hızlanır; bir adım ≈ 0.1 büyütme.
                let gain = 0.1 / Settings.shared.pinchStep
                let sign: Double = Settings.shared.pinchInvert ? -1 : 1
                ActionExecutor.magnify(phase: ActionExecutor.Magnify.phaseChanged,
                                       amount: Double(distance) * gain * sign)
            case .step(let direction):
                guard sessionContinues(), pinchStyle != .gesture else { continue }
                ActionExecutor.zoomStep(direction: direction, style: pinchStyle, modifiers: pinchModifiers)
            case .ended:
                endPinchSession()
            }
        }
    }

    /// Çimdikleme oturumunu kapatır: açık büyütme hareketine önce "bitti" gönderir (uygulamada yarım
    /// hareket takılı kalmasın), sonra `pinchActive`'i sıfırlar. Bitiş, duraklatma, kapatma, kuru denemeye
    /// geçiş ve aygıt yeniden başlama yollarının hepsi buradan geçer (ana kuyruk).
    static func endPinchSession() {
        if magnifyOpen {
            magnifyOpen = false
            ActionExecutor.magnify(phase: ActionExecutor.Magnify.phaseEnded, amount: 0)
        }
        InputState.shared.pinchActive = false
    }

    /// Oturum sürüyor ve hâlâ izinli mi; kapatıldı, duraklatıldı ya da kuru denemeye geçildiyse oturumu kapatır.
    private static func sessionContinues() -> Bool {
        guard InputState.shared.pinchActive else { return false }
        guard Settings.shared.enabled, !AppModel.shared.isPaused, !InputState.shared.dryRun else {
            endPinchSession()
            return false
        }
        return true
    }
}
