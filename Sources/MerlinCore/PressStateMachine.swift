import Foundation

public enum MouseSide: Equatable {
    case left, right
}

public enum PressDecision: Equatable {
    /// Olay olduğu gibi geçer.
    case pass
    /// Olay verilen düğme numarasının (2, 3, 4) fare olayına çevrilir.
    case convert(buttonNumber: Int64)
    /// Olay düşürülür.
    case drop
}

/// Basma oturumunun saf durum makinesi: tek seferde tek oturum açık olabilir.
public struct PressStateMachine {
    private enum Kind: Equatable {
        case convert(Int64)
        case swallow
    }

    private struct Session {
        var side: MouseSide
        var kind: Kind
    }

    private var session: Session?

    /// Son (ya da etkin) oturumun sürüklenip sürüklenmediği; rapor metni için.
    public private(set) var didDrag = false
    /// Son (ya da etkin) oturumu açan atama; rapor metni için.
    public private(set) var binding: GestureBinding?

    public init() {}

    /// Orta tuşa çevrilmiş bir oturum açık mı (kaydırma engeli için).
    public var isMiddleDragActive: Bool {
        if let session, session.kind == .convert(2) { return true }
        return false
    }

    public mutating func mouseDown(_ side: MouseSide, binding: GestureBinding?) -> (PressDecision, runAction: GestureAction?) {
        guard session == nil, let binding else { return (.pass, nil) }
        self.binding = binding
        didDrag = false
        if let n = binding.action.buttonNumber {
            session = Session(side: side, kind: .convert(Int64(n)))
            return (.convert(buttonNumber: Int64(n)), nil)
        }
        session = Session(side: side, kind: .swallow)
        return (.drop, binding.action)
    }

    public mutating func mouseDragged(_ side: MouseSide) -> PressDecision {
        guard let session, session.side == side else { return .pass }
        switch session.kind {
        case .convert(let n):
            didDrag = true
            return .convert(buttonNumber: n)
        case .swallow:
            return .drop
        }
    }

    public mutating func mouseUp(_ side: MouseSide) -> PressDecision {
        guard let current = session, current.side == side else { return .pass }
        session = nil
        switch current.kind {
        case .convert(let n): return .convert(buttonNumber: n)
        case .swallow: return .drop
        }
    }
}
