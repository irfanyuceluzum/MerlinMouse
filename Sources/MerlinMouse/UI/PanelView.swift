import SwiftUI

/// Menü çubuğundan açılan panel.
struct PanelView: View {
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var s = Settings.shared
    @ObservedObject private var front = FrontApp.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if !model.trusted { permissionCard }
            liveSection
            section("Orta tuş") {
                toggle("Orta bölgeye bas · tıkla ya da sürükle", $s.zoneClick)
                if s.zoneClick {
                    HStack {
                        Text("Orta bölge genişliği").font(.caption).foregroundStyle(.secondary)
                        Slider(value: $s.zoneWidth, in: 0.15...0.45).controlSize(.small)
                        Text("%\(Int(s.zoneWidth * 100))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                toggle("İki parmakla bas", $s.twoFingerClick)
                toggle("Üç parmakla bas", $s.threeFingerClick)
                toggle("Üç parmakla dokun (basmadan)", $s.threeFingerTap)
                toggle("Fn + sol sürükleme", $s.fnDrag)
            }
            section("Kaydırma") {
                toggle("Orta tuşla sürüklerken kaydırmayı engelle", $s.blockScrollWhileDragging)
                toggle("3D programlarda ataleti kapat", $s.calm3DScroll)
            }
            ForEach(model.warnings) { warningCard($0) }
            appearancePicker
            footer
        }
        .padding(16)
        .frame(width: 344)
        .tint(.merlinAccent)
    }

    // MARK: Bölümler

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.merlinAccent)
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: "magicmouse").font(.system(size: 17, weight: .medium)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 2) {
                Text("Merlin Mouse").font(.headline)
                Text(model.miceCount > 0 ? "Magic Mouse bağlı" : "Magic Mouse bulunamadı")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Etkin", isOn: $s.enabled).toggleStyle(.switch).labelsHidden()
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Erişilebilirlik izni gerekli", systemImage: "lock.shield")
                .font(.callout.weight(.semibold)).foregroundStyle(Color.merlinWarn)
            Text("Tıklamaları orta tuşa çevirebilmek için Sistem Ayarları › Gizlilik ve Güvenlik › Erişilebilirlik'te Merlin Mouse'u aç.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Ayarları aç") { model.openAccessibilitySettings() }.controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var liveSection: some View {
        HStack(alignment: .top, spacing: 14) {
            MouseMap(touches: model.liveTouches, zoneWidth: s.zoneClick ? s.zoneWidth : 0, flipped: s.flipY)
            VStack(alignment: .leading, spacing: 6) {
                Text("SON EYLEM").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(model.lastAction).font(.callout.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                Spacer().frame(height: 4)
                Text("ÖNDEKİ UYGULAMA").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(front.name.isEmpty ? "—" : front.name).font(.callout)
                    if front.is3D {
                        Text("3D").font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.merlinAccent.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.merlinAccent)
                    }
                }
                Spacer().frame(height: 4)
                Text("Parmakların haritada canlı görünür. Ön taraf yukarıda olmalı.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var appearancePicker: some View {
        HStack {
            Text("Görünüm").font(.callout)
            Spacer()
            Picker("Görünüm", selection: $s.appearance) {
                Text("Sistem").tag("system")
                Text("Gündüz").tag("light")
                Text("Gece").tag("dark")
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 200)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            DisclosureGroup("Gelişmiş") {
                VStack(alignment: .leading, spacing: 6) {
                    toggle("Ön / arka yönünü ters çevir", $s.flipY)
                    Text("Aygıtlar: \(model.deviceInfo.isEmpty ? "—" : model.deviceInfo)")
                        .font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                    Button("Fareyi yeniden tara") { model.startTouches() }.controlSize(.small)
                }
                .padding(.top, 6)
            }
            .font(.callout)
            HStack {
                Spacer()
                Button("Merlin Mouse'tan çık") { NSApp.terminate(nil) }.controlSize(.small)
            }
        }
    }

    // MARK: Yardımcılar

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) { content() }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func toggle(_ title: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) { Text(title).font(.callout) }
            .toggleStyle(.switch).controlSize(.mini)
    }

    private func warningCard(_ w: Warning) -> some View {
        let color: Color = w.source == .btt ? .merlinBTT : .merlinWarn
        return VStack(alignment: .leading, spacing: 4) {
            Label(w.title, systemImage: w.source == .btt ? "arrow.left.arrow.right" : "exclamationmark.triangle")
                .font(.callout.weight(.semibold)).foregroundStyle(color)
            Text(w.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Magic Mouse üst görünümü: orta bölge ve canlı parmak konumları.
struct MouseMap: View {
    var touches: [Touch]
    var zoneWidth: Double
    var flipped: Bool

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1.5)
            let shape = Path(roundedRect: rect,
                             cornerSize: CGSize(width: rect.width * 0.46, height: rect.width * 0.42),
                             style: .continuous)
            // Gerçek fare gibi her iki modda da beyaz yüzey
            context.fill(shape, with: .linearGradient(
                Gradient(colors: [Color(white: 1.0), Color(white: 0.90)]),
                startPoint: CGPoint(x: rect.maxX, y: rect.minY), endPoint: CGPoint(x: rect.minX, y: rect.maxY)))
            context.stroke(shape, with: .color(Color(white: 0.78)), lineWidth: 1.5)

            var inner = context
            inner.clip(to: shape)
            let frontHeight = size.height * CGFloat(1 - TouchMonitor.frontLimit)
            if zoneWidth > 0 {
                let w = size.width * zoneWidth
                inner.fill(Path(CGRect(x: (size.width - w) / 2, y: 0, width: w, height: frontHeight)),
                           with: .color(Color.merlinAccent.opacity(0.18)))
            }
            var dash = Path()
            dash.move(to: CGPoint(x: 0, y: frontHeight))
            dash.addLine(to: CGPoint(x: size.width, y: frontHeight))
            inner.stroke(dash, with: .color(Color(white: 0.6)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))

            for t in touches {
                let x = CGFloat(t.x) * size.width
                let y = (1 - CGFloat(t.front(flipped: flipped))) * size.height
                let r: CGFloat = 7
                inner.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                           with: .color(Color.merlinAccent.opacity(0.85)))
            }
        }
        .frame(width: 78, height: 156)
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .accessibilityLabel("Magic Mouse dokunma haritası")
    }
}
