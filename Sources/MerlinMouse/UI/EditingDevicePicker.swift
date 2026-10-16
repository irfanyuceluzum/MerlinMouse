import SwiftUI
import MerlinCore

/// Ana pencerenin üst çubuğundaki "Magic Mouse | Trackpad" seçicisi. Seçim `Settings.editingDevice`'a yazılır
/// (kalıcı); aygıta bağlı bütün sayfalar onu izler. Her seçeneğin yanında bağlı noktası: yeşil bağlı, gri değil.
struct EditingDevicePicker: View {
    @ObservedObject private var s = Settings.shared
    @ObservedObject private var model = AppModel.shared

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        HStack(spacing: 2) {
            option(.magicMouse, icon: "computermouse")
            option(.trackpad, icon: "rectangle.and.hand.point.up.left")
        }
        .padding(2)
        .background(MM.card2, in: shape)
        .overlay(shape.strokeBorder(MM.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("Düzenlenen aygıt"))
    }

    private func option(_ kind: InputDeviceKind, icon: String) -> some View {
        let selected = s.editingDevice == kind
        let connected = model.devicePresence.isPresent(kind)
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        return Button { s.editingDevice = kind } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .medium))
                Text(kind.displayName).font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                Circle().fill(connected ? MM.okDot : MM.togOff).frame(width: 7, height: 7)
            }
            .foregroundStyle(selected ? MM.text : MM.text2)
            .padding(.horizontal, 10).frame(height: 24)
            .background(selected ? MM.card : Color.clear, in: shape)
            .overlay { if selected { shape.strokeBorder(MM.line, lineWidth: 1) } }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.displayName)
        .accessibilityValue(connected ? L("bağlı") : L("bağlı değil"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Seçili aygıt bağlı değilken aygıta bağlı sayfaların üstündeki ortak bilgi şeridi; bağlıysa hiçbir şey.
struct DevicePassiveBanner: View {
    @ObservedObject private var s = Settings.shared
    @ObservedObject private var model = AppModel.shared

    var body: some View {
        if !model.devicePresence.isPresent(s.editingDevice) {
            switch s.editingDevice {
            case .trackpad:
                MMBanner(kind: .info, title: L("Bu Mac'te trackpad yok"),
                         message: L("Trackpad hareketleri pasif. Ayarların korunur; bir Magic Trackpad bağladığında kendiliğinden devreye girer."))
            case .magicMouse:
                MMBanner(kind: .info, title: L("Magic Mouse bağlı değil"),
                         message: L("Magic Mouse hareketleri pasif. Ayarların korunur; fare bağlanınca kendiliğinden devreye girer."))
            }
        }
    }
}
