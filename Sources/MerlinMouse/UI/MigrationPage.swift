import SwiftUI
import AppKit
import MerlinCore

/// BetterTouchTool'dan geçiş sihirbazı. BTT'de hiçbir şey değiştirilmez; yalnız okunur.
struct MigrationPage: View {
    @ObservedObject private var store = BindingStore.shared

    @State private var step = 1
    @State private var scanning = false
    @State private var errorText: String?
    @State private var scan: BTTScan?
    @State private var selected = Set<Int>()
    @State private var imported: [BTTItem] = []

    private let steps = ["BTT'yi tara", "Devralınacakları seç", "BTT'de kapat", "BTT'yi bırak"]

    /// Listedeki bir satırın hesaplanmış durumu.
    private struct Row: Identifiable {
        let item: BTTItem
        var id: Int { item.id }
        var selectable: Bool
        var note: String?
        var status: BindingStatusKind?
        var statusLabel: String?
        var exists: Bool
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MMPageHeader(title: "BTT'den geçiş",
                             subtitle: "BetterTouchTool'daki Magic Mouse atamalarını Merlin Mouse'a taşı. BTT'de hiçbir şey değiştirilmez; yalnız okunur.")
                stepper
                switch step {
                case 1: stepScan
                case 2: stepSelect
                case 3: stepClose
                default: stepDone
                }
            }
            .padding(.horizontal, 32).padding(.vertical, 28)
        }
    }

    // MARK: Adım göstergesi

    private var stepper: some View {
        HStack(spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, name in
                let n = i + 1
                let current = n == step, done = n < step
                HStack(spacing: 6) {
                    if done { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                    Text("\(n) · \(name)").font(.system(size: 13, weight: current ? .medium : .regular))
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundStyle(current ? MM.accentInk : (done ? MM.accentText : MM.neuText))
                .background(current ? MM.accent : (done ? MM.accentSoft : MM.neuBg), in: Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(current ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Adım 1

    private var stepScan: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let errorText {
                MMBanner(kind: .warning, title: "Tarama yapılamadı", message: errorText,
                         actionTitle: "Tamam") { self.errorText = nil }
            }
            MMCard(padding: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("BetterTouchTool'u tara").font(.system(size: 16, weight: .semibold)).foregroundStyle(MM.text)
                    Text("BetterTouchTool açıkken Merlin Mouse atamalarını okur ve Magic Mouse hareketlerini listeler. İlk seferde macOS Otomasyon izni ister. Hiçbir şey değiştirilmez, ham veri kaydedilmez.")
                        .font(.system(size: 13)).foregroundStyle(MM.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 12) {
                        if scanning {
                            ProgressView().controlSize(.small)
                            Text("Taranıyor…").font(.system(size: 13)).foregroundStyle(MM.text2)
                        } else {
                            MMPrimaryButton("BTT'yi tara", "magnifyingglass") { startScan() }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func startScan() {
        scanning = true
        errorText = nil
        BTTScanner.scan { result in
            scanning = false
            switch result {
            case .failure(let e):
                errorText = e.message
            case .success(let s):
                scan = s
                let rows = makeRows(s)
                selected = Set(rows.filter { $0.selectable && !$0.exists && $0.item.enabled }.map { $0.id })
                step = 2
            }
        }
    }

    // MARK: Adım 2

    private func makeRows(_ s: BTTScan) -> [Row] {
        let env = AppModel.shared.conflictEnvironment()
        return s.magicMouse.map { item in
            guard BTTImport.importable(item), let t = item.trigger, let a = item.action else {
                return Row(item: item, selectable: false, note: item.reason, status: nil, statusLabel: nil, exists: false)
            }
            let probe = GestureBinding(trigger: t, action: a, enabled: true)
            let exists = item.enabled && store.bindings.contains {
                $0.enabled && $0.appBundleID == nil && $0.trigger.normalized == t.normalized
            }
            let conflicts = ConflictChecker.check(probe, among: store.bindings, env: env)
            if let hard = conflicts.first(where: { $0.level.blocksSave && $0.level != .duplicate }) {
                return Row(item: item, selectable: false, note: hard.detail, status: nil, statusLabel: nil, exists: false)
            }
            // Zaten var: yinelenen çakışma beklenen durumdur, rozet yerine etiket gösterilir.
            let shown = conflicts.filter { $0.level != .duplicate }
            let kind = BindingStatus.kind(enabled: true, conflicts: shown)
            return Row(item: item, selectable: true, note: nil, status: exists ? nil : kind, statusLabel: nil, exists: exists)
        }
    }

    private var stepSelect: some View {
        let s = scan ?? BTTScan()
        let rows = makeRows(s)
        let importableRows = rows.filter { $0.selectable }
        let others = rows.filter { !$0.selectable }
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("BetterTouchTool'da bulunan fare hareketleri")
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(MM.text)
                Text("Seçtiklerin Merlin Mouse'a aktarılır; böylece BTT'yi bırakınca bu hareketler kaybolmaz.")
                    .font(.system(size: 13.5)).foregroundStyle(MM.text2)
            }

            MMCard {
                VStack(spacing: 0) {
                    sectionHeader("Magic Mouse · Merlin Mouse devralabilir", warn: false)
                    if rows.isEmpty {
                        Text("BTT'de Magic Mouse ataması bulunamadı.")
                            .font(.system(size: 13)).foregroundStyle(MM.text2)
                            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(importableRows) { r in
                        importableRow(r)
                        MMDivider()
                    }
                    ForEach(others) { r in
                        grayRow(r)
                        MMDivider()
                    }
                }
            }

            let lost = lostGroups(s)
            if !lost.isEmpty {
                MMCard {
                    VStack(spacing: 0) {
                        sectionHeader("BTT'yi kaldırınca kaybolacaklar · Merlin Mouse devralamaz", warn: true)
                        ForEach(lost, id: \.name) { g in
                            HStack {
                                Text(g.name).font(.system(size: 13.5, weight: .medium)).foregroundStyle(MM.text)
                                Spacer()
                                Text("\(g.count)").font(.system(size: 13.5)).foregroundStyle(MM.text2)
                            }
                            .padding(.horizontal, 20).padding(.vertical, 12)
                            MMDivider()
                        }
                        Text("Kaldırmadan önce BTT'de gözden geçir; BTT'nin dışa aktarma yedeğini almanı öneririz.")
                            .font(.system(size: 12.5)).foregroundStyle(MM.text2)
                            .padding(.horizontal, 20).padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            HStack(spacing: 12) {
                Spacer(minLength: 0)
                MMSecondaryButton("Şimdilik atla") { reset() }
                let n = selected.count
                MMPrimaryButton(n == 0 ? "Devral" : "\(n) hareketi devral") { importSelected(rows) }
                    .opacity(n == 0 ? 0.45 : 1).allowsHitTesting(n > 0)
            }
        }
    }

    private func sectionHeader(_ text: String, warn: Bool) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold))
            .foregroundStyle(warn ? MM.warnText : MM.text)
            .padding(.horizontal, 20).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(warn ? MM.warnBg : MM.card2)
            .overlay(alignment: .bottom) { Rectangle().fill(warn ? MM.warnLine : MM.line).frame(height: 1) }
    }

    private func importableRow(_ r: Row) -> some View {
        let on = Binding(get: { selected.contains(r.id) },
                         set: { if $0 { selected.insert(r.id) } else { selected.remove(r.id) } })
        let t = r.item.trigger, a = r.item.action
        return HStack(spacing: 12) {
            Toggle("", isOn: on).labelsHidden().toggleStyle(.checkbox)
                .accessibilityLabel(r.item.description)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.item.description).font(.system(size: 13.5, weight: .medium)).foregroundStyle(MM.text)
                Text(r.item.enabled ? "BTT: \(r.item.actionName)" : "BTT'de kapalı · \(r.item.actionName)")
                    .font(.system(size: 12)).foregroundStyle(MM.text2).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text("→ \(t?.title ?? "") · \(a?.title ?? "")")
                .font(.system(size: 13, weight: .medium)).foregroundStyle(MM.accentText)
            if r.exists {
                MMStatusBadge(kind: .free, label: "Zaten var")
            } else if let k = r.status {
                MMStatusBadge(kind: k)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    private func grayRow(_ r: Row) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: .constant(false)).labelsHidden().toggleStyle(.checkbox).disabled(true)
            Text(r.item.description.isEmpty ? "Adsız hareket" : r.item.description)
                .font(.system(size: 13.5)).foregroundStyle(MM.text2)
            Spacer(minLength: 8)
            Text(r.note ?? "Devralınamıyor")
                .font(.system(size: 12.5)).foregroundStyle(MM.text2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    private func lostGroups(_ s: BTTScan) -> [(name: String, count: Int)] {
        var grouped: [String: Int] = [:]
        for (cls, n) in s.otherCounts { grouped[BTTImport.className(cls), default: 0] += n }
        let order = ["Trackpad", "Klavye kısayolu", "Touch Bar", "Diğer tetikleyiciler"]
        return order.compactMap { name in grouped[name].map { (name: name, count: $0) } }
    }

    private func importSelected(_ rows: [Row]) {
        var done: [BTTItem] = []
        for r in rows where selected.contains(r.id) && r.selectable {
            guard let t = r.item.trigger, let a = r.item.action else { continue }
            store.upsert(GestureBinding(trigger: t, action: a, enabled: true))
            done.append(r.item)
        }
        Log.write("BTT'den devralındı: \(done.count) hareket")
        imported = done
        step = done.isEmpty ? 4 : 3
    }

    // MARK: Adım 3

    private var stepClose: some View {
        VStack(alignment: .leading, spacing: 18) {
            MMBanner(kind: .warning, title: "BTT'de bu hareketleri kapat",
                     message: "BetterTouchTool › Magic Mouse'ta bu hareketleri kapat; yoksa eylem iki kez çalışır.")
            MMCard {
                VStack(spacing: 0) {
                    sectionHeader("Devralınan hareketler", warn: false)
                    ForEach(imported) { item in
                        HStack {
                            Text(item.description).font(.system(size: 13.5, weight: .medium)).foregroundStyle(MM.text)
                            Spacer()
                            Text("→ \(item.trigger?.title ?? "") · \(item.action?.title ?? "")")
                                .font(.system(size: 13)).foregroundStyle(MM.accentText)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        MMDivider()
                    }
                }
            }
            HStack(spacing: 12) {
                Spacer(minLength: 0)
                MMSecondaryButton("BetterTouchTool'u aç", "arrow.up.forward.app") { openBTT() }
                MMPrimaryButton("Kapattım") { step = 4 }
            }
        }
    }

    private func openBTT() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: BTTScanner.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: Adım 4

    private var stepDone: some View {
        let lost = lostGroups(scan ?? BTTScan())
        return VStack(alignment: .leading, spacing: 18) {
            MMCard(padding: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("BTT'yi artık bırakabilirsin").font(.system(size: 18, weight: .semibold)).foregroundStyle(MM.text)
                    Text(imported.isEmpty ? "Hiçbir hareket devralınmadı."
                                          : "\(imported.count) hareket Merlin Mouse'a devralındı.")
                        .font(.system(size: 13.5)).foregroundStyle(MM.text)
                    if !lost.isEmpty {
                        Text("BTT'yi kaldırırsan şunlar kaybolur: " + lost.map { "\($0.count) \($0.name.lowercased())" }.joined(separator: ", ") + ".")
                            .font(.system(size: 13)).foregroundStyle(MM.warnText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer(minLength: 0)
                MMPrimaryButton("Bitti") { reset() }
            }
        }
    }

    private func reset() {
        step = 1
        scan = nil
        selected = []
        imported = []
        errorText = nil
    }
}
