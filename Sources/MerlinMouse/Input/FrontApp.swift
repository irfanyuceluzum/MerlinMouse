import AppKit

/// Öndeki uygulamayı izler; 3D / dilimleyici programları tanır.
final class FrontApp: ObservableObject {
    static let shared = FrontApp()

    private static let keywords = [
        "chitubox", "lychee", "blender", "bambu", "prusa", "orca", "cura", "fusion",
        "freecad", "rhino", "sketchup", "cinema 4d", "maya", "zbrush", "meshmixer", "shapr3d",
    ]

    @Published private(set) var name = ""
    @Published private(set) var is3D = false
    /// Önbellekli; olay yakalayıcı geri çağrısı sistemi sorgulamasın diye.
    @Published private(set) var bundleID: String?

    private init() {
        update(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            self?.update(note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
        }
    }

    private func update(_ app: NSRunningApplication?) {
        name = app?.localizedName ?? ""
        bundleID = app?.bundleIdentifier
        let haystack = "\(app?.bundleIdentifier ?? "") \(name)".lowercased()
        is3D = Self.keywords.contains { haystack.contains($0) }
    }
}
