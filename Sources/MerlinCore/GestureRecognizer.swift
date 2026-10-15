import Foundation

/// Tek bir parmak noktası; y: 0 arka/avuç → 1 ön (yön çevirme çağıranda yapılır).
public struct TouchPoint: Equatable {
    public var id: Int32
    public var x: Float
    public var y: Float

    public init(id: Int32, x: Float, y: Float) {
        self.id = id
        self.x = x
        self.y = y
    }
}

/// Bir andaki tüm aktif dokunuşlar.
public struct TouchFrame {
    public var touches: [TouchPoint]
    public var timestamp: Double

    public init(touches: [TouchPoint], timestamp: Double) {
        self.touches = touches
        self.timestamp = timestamp
    }
}

/// Basmadan yapılan, tanınmış hareket.
public enum RecognizedGesture: Equatable {
    case tap(fingers: Int, zone: Zone)
    case doubleTap(fingers: Int, zone: Zone)
    case swipe(fingers: Int, direction: SwipeDirection)

    public var trigger: Trigger {
        switch self {
        case .tap(let f, let z): return Trigger(kind: .tap, fingers: f, zone: z)
        case .doubleTap(let f, let z): return Trigger(kind: .doubleTap, fingers: f, zone: z)
        case .swipe(let f, let d): return Trigger(kind: .swipe, fingers: f, direction: d)
        }
    }
}

/// Dokunma, çift dokunma ve 3+ parmak kaydırmayı karelerden tanıyan saf durum makinesi.
public struct GestureRecognizer {
    public var layout: ZoneLayout = .standard
    public var tapMaxDuration: Double = 0.35
    public var tapMaxMove: Float = 0.04
    public var landingWindow: Double = 0.15
    public var swipeMinDistance: Float = 0.12
    public var doubleTapWindow: Double = 0.35
    public var wantsDoubleTap: (Int, Zone) -> Bool = { _, _ in false }

    private struct Session {
        var start: Double
        var seen: Set<Int32> = []
        var origins: [Int32: (Float, Float)] = [:]
        var fingers = 0
        var invalid = false
        var clicked = false
        var maxMove: Float = 0
        var firstZoneX: Float = 0
        var firstZoneY: Float = 1
        var firstCentroid: (Float, Float)?
        var lastCentroid: (Float, Float)?
    }

    /// Arka (logo) bölgesindeki tek parmaklı dokunma oturumu.
    private struct RearSession {
        var id: Int32
        var start: Double
        var origin: (Float, Float)
        var maxMove: Float = 0
        var invalid = false
        var clicked = false
    }

    private struct Pending {
        var fingers: Int
        var zone: Zone
        var end: Double
        var deadline: Double
    }

    private var session: Session?
    private var rear: RearSession?
    private var surfaceWasEmpty = true
    private var pending: Pending?

    public init() {}

    /// Bekleyen tek dokunmanın süresinin dolacağı an.
    public var pendingDeadline: Double? { pending?.deadline }

    /// Fiziksel tıklama oldu: açık oturum hiçbir hareket üretmez.
    public mutating func noteClick() {
        session?.clicked = true
        rear?.clicked = true
    }

    public mutating func process(_ frame: TouchFrame) -> [RecognizedGesture] {
        let front = frame.touches.filter { Double($0.y) >= layout.frontLimit }
        let t = frame.timestamp
        var out: [RecognizedGesture] = []

        updateRear(frame, at: t, into: &out)

        if front.isEmpty {
            if let s = session {
                session = nil
                finish(s, end: t, into: &out)
            }
        } else {
            if session == nil { session = Session(start: t) }
            update(front, at: t)
        }
        surfaceWasEmpty = frame.touches.isEmpty
        expire(now: t, into: &out)
        return out
    }

    /// Arka dokunma: yüzey boşken tek parmak arkaya iner, oturum boyunca başka parmak gelmez.
    private mutating func updateRear(_ frame: TouchFrame, at t: Double, into out: inout [RecognizedGesture]) {
        let all = frame.touches
        if var r = rear {
            if all.isEmpty {
                rear = nil
                if !r.invalid, !r.clicked, t - r.start <= tapMaxDuration, r.maxMove < tapMaxMove {
                    registerTap(fingers: 1, zone: .rear, start: r.start, end: t, into: &out)
                }
                return
            }
            if all.count != 1 || all[0].id != r.id { r.invalid = true }
            if let p = all.first(where: { $0.id == r.id }) {
                r.maxMove = max(r.maxMove, hypot(p.x - r.origin.0, p.y - r.origin.1))
            }
            rear = r
        } else if surfaceWasEmpty, all.count == 1, Double(all[0].y) < layout.frontLimit {
            rear = RearSession(id: all[0].id, start: t, origin: (all[0].x, all[0].y))
        }
    }

    /// Bekleyen tek dokunmayı, süresi dolduysa `.tap` olarak döndürür.
    public mutating func flush(now: Double) -> [RecognizedGesture] {
        var out: [RecognizedGesture] = []
        expire(now: now, into: &out)
        return out
    }

    private mutating func update(_ front: [TouchPoint], at t: Double) {
        guard var s = session else { return }
        for p in front where !s.seen.contains(p.id) {
            s.seen.insert(p.id)
            s.origins[p.id] = (p.x, p.y)
            if t - s.start <= landingWindow {
                if s.fingers == 0 { s.firstZoneX = p.x; s.firstZoneY = p.y }
                s.fingers += 1
                s.firstCentroid = nil
            } else {
                s.invalid = true
            }
        }
        for p in front {
            if let o = s.origins[p.id] { s.maxMove = max(s.maxMove, hypot(p.x - o.0, p.y - o.1)) }
        }
        if !s.invalid && front.count == s.fingers {
            let cx = front.reduce(0) { $0 + $1.x } / Float(front.count)
            let cy = front.reduce(0) { $0 + $1.y } / Float(front.count)
            if s.firstCentroid == nil { s.firstCentroid = (cx, cy) }
            s.lastCentroid = (cx, cy)
        }
        session = s
    }

    private mutating func finish(_ s: Session, end: Double, into out: inout [RecognizedGesture]) {
        guard !s.invalid, !s.clicked, s.fingers > 0 else { return }
        if end - s.start <= tapMaxDuration && s.maxMove < tapMaxMove {
            let zone: Zone = s.fingers == 1 ? Zone.classify(x: s.firstZoneX, y: s.firstZoneY, layout: layout) : .any
            registerTap(fingers: s.fingers, zone: zone, start: s.start, end: end, into: &out)
            return
        }
        guard s.fingers >= 3, let a = s.firstCentroid, let b = s.lastCentroid else { return }
        let dx = b.0 - a.0
        let dy = b.1 - a.1
        guard hypot(dx, dy) >= swipeMinDistance else { return }
        if abs(dx) > 2 * abs(dy) {
            out.append(.swipe(fingers: s.fingers, direction: dx > 0 ? .right : .left))
        } else if abs(dy) > 2 * abs(dx) {
            out.append(.swipe(fingers: s.fingers, direction: dy > 0 ? .up : .down))
        }
    }

    private mutating func registerTap(fingers: Int, zone: Zone, start: Double, end: Double,
                                      into out: inout [RecognizedGesture]) {
        guard wantsDoubleTap(fingers, zone) else {
            out.append(.tap(fingers: fingers, zone: zone))
            return
        }
        if let p = pending {
            pending = nil
            if p.fingers == fingers && p.zone == zone && start - p.end <= doubleTapWindow {
                out.append(.doubleTap(fingers: fingers, zone: zone))
                return
            }
            out.append(.tap(fingers: p.fingers, zone: p.zone))
        }
        pending = Pending(fingers: fingers, zone: zone, end: end, deadline: end + doubleTapWindow)
    }

    private mutating func expire(now: Double, into out: inout [RecognizedGesture]) {
        guard let p = pending, now >= p.deadline else { return }
        // Süre dolmadan başlamış bir oturum hâlâ sürüyorsa eşleşme ihtimali var; bekle.
        if let s = session, s.start <= p.deadline { return }
        if let r = rear, r.start <= p.deadline { return }
        pending = nil
        out.append(.tap(fingers: p.fingers, zone: p.zone))
    }
}
