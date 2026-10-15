import SwiftUI
import MerlinCore

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
                    cardTitle(L("Çimdikleme"))
                    Text(L("İki parmağı açıp kapatarak trackpad'deki gibi yakınlaştır. Bir programda çalışmazsa o programa profil ekleyip yöntemi Fare tekerleği yap. Çimdiklerken kaydırma durur."))
                        .font(.system(size: 12)).foregroundStyle(MM.text2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20).padding(.top, 12)
                    MMSwitchRow(title: L("Yönü ters çevir"),
                                subtitle: L("Parmakları açmak uzaklaştırır"),
                                isOn: $s.pinchInvert)
                    MMDivider()
                    HStack(spacing: 16) {
                        Text(L("Hassasiyet")).font(.system(size: 13.5, weight: .medium)).foregroundStyle(MM.text)
                        Spacer(minLength: 12)
                        Slider(value: pinchSensitivity, in: 0...1) {
                            Text(L("Hassasiyet"))
                        } minimumValueLabel: {
                            Text(L("Az")).font(.system(size: 12)).foregroundStyle(MM.text2)
                        } maximumValueLabel: {
                            Text(L("Çok")).font(.system(size: 12)).foregroundStyle(MM.text2)
                        }
                        .labelsHidden()
                        .tint(MM.accent)
                        .frame(maxWidth: 320)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 14)
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

    /// Hassasiyet 0 (az) … 1 (çok); arttıkça adım küçülür.
    private var pinchSensitivity: Binding<Double> {
        Binding(get: { PinchRecognizer.sensitivity(forStep: s.pinchStep) },
                set: { s.pinchStep = PinchRecognizer.step(forSensitivity: $0) })
    }

    private func cardTitle(_ t: String) -> some View {
        Text(t).font(.system(size: 12, weight: .semibold)).foregroundStyle(MM.text)
            .padding(.horizontal, 20).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MM.card2)
            .overlay(alignment: .bottom) { Rectangle().fill(MM.line).frame(height: 1) }
    }
}
