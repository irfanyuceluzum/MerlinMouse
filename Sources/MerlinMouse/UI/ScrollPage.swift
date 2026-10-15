import SwiftUI

/// Kaydırma ayarları.
struct ScrollPage: View {
    @ObservedObject private var s = Settings.shared
    @ObservedObject private var front = FrontApp.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MMPageHeader(title: L("Kaydırma"),
                         subtitle: L("Orta tuşla çalışırken ve 3D programlarda Magic Mouse kaydırmasını denetle."))
            MMCard {
                VStack(spacing: 0) {
                    cardTitle(L("Kaydırma ve yakınlaştırma"))
                    MMSwitchRow(title: L("Sürüklerken kaydırmayı engelle"),
                                subtitle: L("Model döndürürken istemeden yakınlaşmaz"),
                                isOn: $s.blockScrollWhileDragging)
                    MMDivider()
                    MMSwitchRow(title: L("Ataleti kapat, adım adım yakınlaştır"),
                                subtitle: L("3D programlarda Magic Mouse kaydırması tekerlek gibi davranır"),
                                isOn: $s.calm3DScroll)
                }
            }
            MMCard {
                VStack(spacing: 0) {
                    cardTitle(L("Öndeki uygulama"))
                    HStack(spacing: 8) {
                        Text(front.name.isEmpty ? "—" : front.name)
                            .font(.system(size: 13.5, weight: .medium)).foregroundStyle(MM.text)
                        if front.is3D {
                            Text("3D").font(.system(size: 11, weight: .bold)).foregroundStyle(MM.accentText)
                                .padding(.horizontal, 7).padding(.vertical, 1)
                                .background(MM.accentSoft, in: Capsule())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.vertical, 14)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32).padding(.vertical, 28)
    }

    private func cardTitle(_ t: String) -> some View {
        Text(t).font(.system(size: 12, weight: .semibold)).foregroundStyle(MM.text)
            .padding(.horizontal, 20).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MM.card2)
            .overlay(alignment: .bottom) { Rectangle().fill(MM.line).frame(height: 1) }
    }
}
