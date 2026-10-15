import SwiftUI

/// Kaydırma ayarları.
struct ScrollPage: View {
    @ObservedObject private var s = Settings.shared
    @ObservedObject private var front = FrontApp.shared

    var body: some View {
        Form {
            Section {
                Toggle("Orta tuşla sürüklerken kaydırmayı engelle", isOn: $s.blockScrollWhileDragging)
                Toggle("3D programlarda ataleti kapat", isOn: $s.calm3DScroll)
            }
            Section("Öndeki uygulama") {
                LabeledContent("Uygulama", value: front.name.isEmpty ? "—" : front.name)
                LabeledContent("3D program mu?", value: front.is3D ? "Evet" : "Hayır")
            }
        }
        .formStyle(.grouped)
    }
}
