import AppKit
import UniformTypeIdentifiers

/// Kapsam / uygulama seçimi için kimlik + ad.
struct AppChoice: Identifiable, Hashable {
    var id: String
    var name: String
}

struct PickedApp {
    var path: String
    var name: String
    var bundleID: String?
}

enum AppPicker {
    /// Çalışan normal uygulamalar.
    static func runningApps() -> [AppChoice] {
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> AppChoice? in
                guard let id = app.bundleIdentifier, seen.insert(id).inserted else { return nil }
                return AppChoice(id: id, name: app.localizedName ?? id)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Uygulama seçim paneli (.app).
    static func pickApp() -> PickedApp? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = L("Seç")
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return app(at: url)
    }

    /// Paket yolundan ad ve kimlik (kimlik okunamazsa nil).
    static func app(at url: URL) -> PickedApp {
        let bundle = Bundle(url: url)
        let name = (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return PickedApp(path: url.path, name: name, bundleID: bundle?.bundleIdentifier)
    }
}
