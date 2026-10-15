import SwiftUI
import AppKit

/// Tasarım sisteminin renk belirteçleri (gündüz / gece); görünüm NSApp.appearance'a uyar.
enum MM {
    private static func ns(_ light: (UInt32, Double), _ dark: (UInt32, Double)) -> NSColor {
        func c(_ v: (UInt32, Double)) -> NSColor {
            NSColor(srgbRed: CGFloat((v.0 >> 16) & 0xFF) / 255, green: CGFloat((v.0 >> 8) & 0xFF) / 255,
                    blue: CGFloat(v.0 & 0xFF) / 255, alpha: CGFloat(v.1))
        }
        let l = c(light), d = c(dark)
        return NSColor(name: nil) { ap in
            ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? d : l
        }
    }
    private static func tok(_ light: (UInt32, Double), _ dark: (UInt32, Double)) -> Color {
        Color(nsColor: ns(light, dark))
    }

    static let win = tok((0xFBFBFD, 1), (0x1C1C1E, 1))
    static let side = tok((0xF3F3F6, 1), (0x232325, 1))
    static let card = tok((0xFFFFFF, 1), (0x2A2A2D, 1))
    static let card2 = tok((0xF8F8FA, 1), (0x303033, 1))
    static let line = tok((0xE3E3E8, 1), (0xFFFFFF, 0.09))
    static let line2 = tok((0xEEEEF2, 1), (0xFFFFFF, 0.055))
    static let text = tok((0x1D1D1F, 1), (0xF5F5F7, 1))
    static let text2 = tok((0x6E6E73, 1), (0xA1A1A6, 1))
    static let accent = tok((0x2F5BD3, 1), (0x4767EE, 1))
    static let accentInk = tok((0xFFFFFF, 1), (0xFFFFFF, 1))
    static let accentText = tok((0x2449B5, 1), (0xA9BBFF, 1))
    static let accentSoft = tok((0x2F5BD3, 0.09), (0x6E8CFF, 0.16))
    static let accentLine = tok((0x2F5BD3, 0.35), (0x8CA5FF, 0.45))
    static let warnBg = tok((0xFFF4E8, 1), (0xFF9F0A, 0.13))
    static let warnText = tok((0x8F4A00, 1), (0xFFC27A, 1))
    static let warnLine = tok((0xF2D2AE, 1), (0xFF9F0A, 0.32))
    static let warnDot = tok((0xE07B12, 1), (0xFF9F0A, 1))
    static let bttBg = tok((0xF5F0FC, 1), (0xBF5AF2, 0.15))
    static let bttText = tok((0x6534A8, 1), (0xD9BCFF, 1))
    static let bttLine = tok((0xDFD0F4, 1), (0xBF5AF2, 0.36))
    static let bttDot = tok((0x8E5CD9, 1), (0xBF5AF2, 1))
    static let neuBg = tok((0xEFEFF2, 1), (0xFFFFFF, 0.07))
    static let neuText = tok((0x4A4A4F, 1), (0xC7C7CC, 1))
    static let togOff = tok((0xD5D5DA, 1), (0x4A4A4E, 1))
    static let okDot = tok((0x248A3D, 1), (0x30D158, 1))
}

/// Eski adlar belirteçlere yönlenir.
extension Color {
    static let merlinAccent = MM.accent
    static let merlinWarn = MM.warnText
    static let merlinBTT = MM.bttText
}
