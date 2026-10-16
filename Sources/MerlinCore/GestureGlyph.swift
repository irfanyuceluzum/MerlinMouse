import Foundation

/// Simgedeki parmak noktası (6 pt çap); dolu = basma/kaydırma/çimdikleme, boş = dokunma.
public struct GlyphDot: Equatable {
    public let x: Double
    public let y: Double
    public let hollow: Bool

    public init(x: Double, y: Double, hollow: Bool) {
        self.x = x
        self.y = y
        self.hollow = hollow
    }
}

/// Fiziksel tıklamayı gösteren 1 pt halka.
public struct GlyphRing: Equatable {
    public let x: Double
    public let y: Double
    public let radius: Double

    public init(x: Double, y: Double, radius: Double) {
        self.x = x
        self.y = y
        self.radius = radius
    }
}

/// Ok ya da kısa metin ("↑", "2×", "fn" …); konum metnin merkezidir.
public struct GlyphLabel: Equatable {
    public let x: Double
    public let y: Double
    public let text: String
    public let size: Double

    public init(x: Double, y: Double, text: String, size: Double) {
        self.x = x
        self.y = y
        self.text = text
        self.size = size
    }
}

/// Bir tetiği anlatan küçük fare simgesinin çizim tarifi (28×36 pt kutu, koordinatlar pt).
public struct GestureGlyph: Equatable {
    // Kutu ve fare gövdesi ölçüleri.
    public static let width: Double = 28
    public static let height: Double = 36
    public static let bodyX: Double = 2
    public static let bodyY: Double = 1
    public static let bodyWidth: Double = 24
    public static let bodyHeight: Double = 34
    public static let bodyTopRadius: Double = 12
    public static let bodyBottomRadius: Double = 11
    public static let bodyStroke: Double = 1.5
    public static let dotDiameter: Double = 6
    /// Arka bölge vurgusunun başladığı y (gövde sonuna kadar sürer).
    public static let rearTop: Double = 22

    public var dots: [GlyphDot] = []
    public var rings: [GlyphRing] = []
    public var labels: [GlyphLabel] = []
    /// Arka (logo) bölgesi vurgulanır mı?
    public var rear = false
    /// Kenar kaydırmada vurgulanan şerit (gövde boyunca, gövdeye kırpılır); yoksa nil.
    public var edge: EdgeSide?
    /// Kenar şeridinin genişliği (gövde kenarından içeri).
    public static let edgeStripeWidth: Double = 10

    static let labelSize: Double = 9
    static let arrowSize: Double = 10

    // Trackpad gövdesi: kutunun ortasında yatay yuvarlatılmış dikdörtgen.
    public static let trackpadBodyWidth: Double = 26
    public static let trackpadBodyHeight: Double = 18
    public static let trackpadBodyRadius: Double = 4
    public static var trackpadBodyX: Double { (width - trackpadBodyWidth) / 2 }
    public static var trackpadBodyY: Double { (height - trackpadBodyHeight) / 2 }

    /// Fare simgesindeki y'yi trackpad gövdesinin ortasına sıkıştırır.
    public static func trackpadY(_ y: Double) -> Double { 11 + y * 0.5 }

    /// Aygıta göre tarif: trackpad'de noktalar, halkalar ve etiketler gövdenin ortasına sıkıştırılır;
    /// arka bölge ve kenar şeridi trackpad'de yoktur.
    public init(trigger: Trigger, device: InputDeviceKind) {
        self.init(trigger: trigger)
        guard device == .trackpad else { return }
        dots = dots.map { GlyphDot(x: $0.x, y: Self.trackpadY($0.y), hollow: $0.hollow) }
        rings = rings.map { GlyphRing(x: $0.x, y: Self.trackpadY($0.y), radius: $0.radius) }
        labels = labels.map { GlyphLabel(x: $0.x, y: Self.trackpadY($0.y), text: $0.text, size: $0.size) }
        rear = false
        edge = nil
    }

    public init(trigger: Trigger) {
        let t = trigger.normalized
        switch t.kind {
        case .press, .hold:
            buildPress(t)
        case .tap:
            buildTap(t, double: false)
        case .doubleTap:
            buildTap(t, double: true)
        case .swipe:
            buildSwipe(t)
        case .pinch:
            dots = [GlyphDot(x: 9, y: 14, hollow: false), GlyphDot(x: 19, y: 14, hollow: false)]
            labels = [GlyphLabel(x: 14, y: 25, text: "↔", size: Self.arrowSize)]
        case .edgeSlide:
            let right = t.zone == .rightEdge
            edge = right ? .right : .left
            dots = [GlyphDot(x: right ? 21 : 7, y: 16, hollow: false)]
            labels = [GlyphLabel(x: right ? 13 : 15, y: 16, text: "↕", size: Self.arrowSize)]
        }
    }

    // MARK: Konumlar

    /// Tek parmağın bölgeye göre konumu (arka hariç).
    static func zonePoint(_ zone: Zone) -> (Double, Double) {
        switch zone {
        case .left: return (8, 12)
        case .right: return (20, 11)
        case .any, .center, .rear, .leftEdge, .rightEdge: return (14, 12)
        }
    }

    /// Parmak sayısına göre noktalar: 2 → iki, 3+ → üç; 1 ya da 0 → orta.
    static func fingerPoints(_ fingers: Int) -> [(Double, Double)] {
        switch fingers {
        case 2: return [(10, 12), (18, 12)]
        case let n where n >= 3: return [(8, 12), (14, 10), (20, 12)]
        default: return [(14, 12)]
        }
    }

    // MARK: Türler

    private mutating func buildPress(_ t: Trigger) {
        if t.modifier != .none {
            dots = [GlyphDot(x: 14, y: 11, hollow: false)]
            rings = [GlyphRing(x: 14, y: 11, radius: 6)]
            labels = [GlyphLabel(x: 14, y: 24, text: Self.modifierText(t.modifier), size: Self.labelSize)]
            return
        }
        if t.fingers <= 1 {
            if t.zone == .rear {
                rear = true
                dots = [GlyphDot(x: 14, y: 28, hollow: false)]
                rings = [GlyphRing(x: 14, y: 28, radius: 6)]
                return
            }
            // Basmada yalnız sağ bölge ayrı çizilir; sol/herhangi (kullanılmaz) orta gibi.
            let p = Self.zonePoint(t.zone == .right ? .right : .center)
            dots = [GlyphDot(x: p.0, y: p.1, hollow: false)]
            rings = [GlyphRing(x: p.0, y: p.1, radius: 6)]
            return
        }
        let pts = Self.fingerPoints(t.fingers)
        dots = pts.map { GlyphDot(x: $0.0, y: $0.1, hollow: false) }
        rings = pts.map { GlyphRing(x: $0.0, y: $0.1, radius: 5) }
    }

    private mutating func buildTap(_ t: Trigger, double: Bool) {
        let twice = GlyphLabel(x: 14, y: 24, text: "2×", size: Self.labelSize)
        if t.fingers <= 1 {
            if t.zone == .rear {
                rear = true
                dots = [GlyphDot(x: 14, y: 28, hollow: true)]
                if double {
                    rings = [GlyphRing(x: 14, y: 28, radius: 5)]
                    labels = [GlyphLabel(x: 14, y: 13, text: "2×", size: Self.labelSize)]
                }
                return
            }
            let p = Self.zonePoint(t.zone)
            dots = [GlyphDot(x: p.0, y: p.1, hollow: true)]
            if double { labels = [twice] }
            return
        }
        let pts = Self.fingerPoints(t.fingers)
        dots = pts.map { GlyphDot(x: $0.0, y: $0.1, hollow: true) }
        if double {
            if t.fingers == 2 { rings = pts.map { GlyphRing(x: $0.0, y: $0.1, radius: 5) } }
            labels = [twice]
        }
    }

    private mutating func buildSwipe(_ t: Trigger) {
        let pts = Self.fingerPoints(t.fingers)
        if t.direction == .up {
            dots = pts.map { GlyphDot(x: $0.0, y: $0.1 + 8, hollow: false) }
            labels = [GlyphLabel(x: 14, y: 9, text: "↑", size: Self.arrowSize)]
            return
        }
        dots = pts.map { GlyphDot(x: $0.0, y: $0.1, hollow: false) }
        let arrow: String
        switch t.direction {
        case .down: arrow = "↓"
        case .left: arrow = "←"
        default: arrow = "→"
        }
        labels = [GlyphLabel(x: 14, y: 23, text: arrow, size: Self.arrowSize)]
    }

    static func modifierText(_ m: PressModifier) -> String {
        switch m {
        case .fn: return "fn"
        case .option: return "⌥"
        case .command: return "⌘"
        case .shift: return "⇧"
        case .none: return ""
        }
    }
}
