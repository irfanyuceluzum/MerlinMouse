import SwiftUI
import AppKit
import MerlinCore

/// Sistem hareketleri durumu; kenar çubuğu rozeti ve sayfa aynı veriyi kullanır.
final class SystemGestureState: ObservableObject {
    static let shared = SystemGestureState()
    @Published private(set) var rows: [SystemGestureRow] = []
    var onCount: Int { rows.filter { $0.isConfigurable && $0.isOn }.count }

    func refresh() {
        rows = SystemGestureCatalog.rows(env: AppModel.shared.conflictEnvironment())
    }
}

/// macOS'un fare hareketleri ve Merlin Mouse ile ilişkileri.
struct SystemPage: View {
    @ObservedObject private var state = SystemGestureState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("macOS'un Magic Mouse için kullandığı hareketler. Açık olanlara atama yaparsan çakışma uyarısı çıkar.")
                .font(.callout).foregroundStyle(.secondary)
            Table(state.rows, columns: {
                TableColumn("Hareket", value: \.gesture)
                TableColumn("macOS görevi", value: \.task)
                TableColumn("Durum") { row in
                    Text(row.isOn ? "Açık" : "Kapalı")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background((row.isOn ? Color.merlinAccent : Color.secondary).opacity(0.15), in: Capsule())
                        .foregroundStyle(row.isOn ? Color.merlinAccent : Color.secondary)
                }
                .width(70)
                TableColumn("Not", value: \.note)
            })
            HStack {
                Button("Sistem Ayarları › Fare") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Mouse-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Yenile") { state.refresh() }
                Spacer()
            }
        }
        .padding(20)
        .onAppear { state.refresh() }
    }
}

extension SystemGestureRow: Identifiable {
    public var id: String { gesture }
}
