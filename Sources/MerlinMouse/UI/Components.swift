import SwiftUI
import MerlinCore

/// Kart: köşe 16, 1 px kenar, gündüz/gece gölgesi.
struct MMCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = 0
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        content()
            .padding(padding)
            .background(MM.card, in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(MM.line, lineWidth: 1))
            .shadow(color: scheme == .dark ? .black.opacity(0.45) : Color(red: 17 / 255, green: 17 / 255, blue: 26 / 255).opacity(0.06),
                    radius: scheme == .dark ? 15 : 10, y: scheme == .dark ? 10 : 6)
    }
}

/// Sayfa başlığı: 24 pt yarı kalın başlık, açıklama, sağda isteğe bağlı eylemler.
struct MMPageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: () -> Trailing

    init(title: String, subtitle: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 24, weight: .semibold)).foregroundStyle(MM.text)
                Text(subtitle).font(.system(size: 13.5)).foregroundStyle(MM.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            trailing()
        }
    }
}

extension MMPageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct MMPrimaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    init(_ title: String, _ systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 13, weight: .semibold)) }
                Text(title).font(.system(size: 13.5, weight: .medium))
            }
            .foregroundStyle(MM.accentInk)
            .padding(.horizontal, 18).frame(height: 40)
            .background(MM.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct MMSecondaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    init(_ title: String, _ systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 13, weight: .semibold)) }
                Text(title).font(.system(size: 13.5))
            }
            .foregroundStyle(MM.text)
            .padding(.horizontal, 16).frame(height: 40)
            .background(MM.card, in: shape)
            .overlay(shape.strokeBorder(MM.line, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }
}

/// Atama durum rozeti (ikonlu kapsül).
struct MMStatusBadge: View {
    let kind: BindingStatusKind
    /// Ayrılmış / Desteklenmiyor / Yinelenen gibi `blocked` alt türleri için metin.
    var label: String?

    private var spec: (text: String, icon: String, bg: Color, fg: Color, border: Color?) {
        switch kind {
        case .free: return ("Serbest", "checkmark", MM.accentSoft, MM.accentText, nil)
        case .macOS: return ("macOS ile çakışıyor", "exclamationmark.triangle", MM.card, MM.warnText, MM.warnLine)
        case .btt: return ("BetterTouchTool", "arrow.left.arrow.right", MM.bttBg, MM.bttText, nil)
        case .caution: return ("Dikkat", "exclamationmark", MM.warnBg, MM.warnText, nil)
        case .blocked: return ("Ayrılmış", "lock", MM.neuBg, MM.neuText, nil)
        case .disabled: return ("Kapalı", "power", MM.neuBg, MM.neuText, nil)
        case .replacesDisabled: return ("Kapalı ataması var", "arrow.triangle.2.circlepath", MM.neuBg, MM.neuText, nil)
        case .shadows: return ("Genel atamayı ezer", "square.stack.3d.up", MM.accentSoft, MM.accentText, nil)
        }
    }

    var body: some View {
        let s = spec
        HStack(spacing: 6) {
            Image(systemName: s.icon).font(.system(size: 10, weight: .bold))
            Text(label ?? s.text).font(.system(size: 12, weight: .semibold)).lineLimit(1)
        }
        .foregroundStyle(s.fg)
        .padding(.horizontal, 10).padding(.vertical, 3)
        .background(s.bg, in: Capsule())
        .overlay { if let b = s.border { Capsule().strokeBorder(b, lineWidth: 1) } }
        .fixedSize()
    }
}

/// Tasarımdaki 42×25 anahtar.
struct MMSwitch: View {
    @Binding var isOn: Bool
    var label: String = "Aç / kapat"

    var body: some View {
        Button { isOn.toggle() } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? MM.accent : MM.togOff)
                Circle().fill(Color.white).frame(width: 21, height: 21)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                    .padding(2)
            }
            .frame(width: 42, height: 25)
            .animation(.easeOut(duration: 0.12), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "Açık" : "Kapalı")
    }
}

/// Başlık + açıklama + anahtar satırı.
struct MMSwitchRow: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13.5, weight: .medium)).foregroundStyle(MM.text)
                if let subtitle {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(MM.text2)
                }
            }
            Spacer(minLength: 12)
            MMSwitch(isOn: $isOn, label: title)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }
}

/// 11 pt büyük harfli bölüm etiketi.
struct MMSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.66)
            .foregroundStyle(MM.text2)
    }
}

/// Kartın içindeki ince ayırıcı.
struct MMDivider: View {
    var body: some View { Rectangle().fill(MM.line2).frame(height: 1) }
}

/// Uyarı / bilgi şeridi.
struct MMBanner: View {
    enum Kind { case warning, info }
    let kind: Kind
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    init(kind: Kind, title: String, message: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.kind = kind
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        let warn = kind == .warning
        let fg = warn ? MM.warnText : MM.accentText
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack(spacing: 12) {
            Image(systemName: warn ? "exclamationmark.triangle" : "info.circle")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(fg)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(fg)
                if let message {
                    Text(message).font(.system(size: 12.5)).foregroundStyle(MM.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle).font(.system(size: 12.5, weight: .medium)).foregroundStyle(fg)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(MM.card, in: Capsule())
                        .overlay(Capsule().strokeBorder(warn ? MM.warnLine : MM.accentLine, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(warn ? MM.warnBg : MM.accentSoft, in: shape)
        .overlay(shape.strokeBorder(warn ? MM.warnLine : MM.accentLine, lineWidth: 1))
    }
}
