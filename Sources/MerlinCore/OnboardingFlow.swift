import Foundation

/// İlk açılış rehberinin adımları.
public enum OnboardingStep: Int, CaseIterable {
    case permission, recognizeMouse, firstGesture, done
}

/// Rehberin adım durumu: koşullar sağlandıkça kendiliğinden ilerler, kullanıcı da elle ilerletebilir.
public struct OnboardingFlow: Equatable {
    public var step: OnboardingStep
    /// Son `update` çağrısındaki koşullar (`canAdvance` bunlardan hesaplanır).
    private var trusted = false
    private var mouseRecognized = false
    private var middleActionSeen = false

    public init(step: OnboardingStep = .permission) { self.step = step }

    /// Her `update` en fazla bir adım ilerletir; böylece kullanıcı her adımı görür.
    public mutating func update(trusted: Bool, miceCount: Int, touchSeen: Bool, middleActionSeen: Bool) {
        self.trusted = trusted
        self.mouseRecognized = miceCount > 0 && touchSeen
        self.middleActionSeen = middleActionSeen
        if canAdvance { next() }
    }

    /// Geçerli adımın koşulu sağlandı mı.
    public var canAdvance: Bool {
        switch step {
        case .permission: return trusted
        case .recognizeMouse: return mouseRecognized
        case .firstGesture: return middleActionSeen
        case .done: return false
        }
    }

    public var isFinished: Bool { step == .done }

    public mutating func next() {
        if let n = OnboardingStep(rawValue: step.rawValue + 1) { step = n }
    }

    public mutating func back() {
        if let p = OnboardingStep(rawValue: step.rawValue - 1) { step = p }
    }

    public mutating func skip() { step = .done }
}
