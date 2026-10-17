import Foundation
import MerlinCore

/// Atama ve ayar yedeği: dosyaya ve iCloud Drive'a yazar, geri yükler. Fare görseli yedeğe girmez.
enum BackupManager {
    static let fileExtension = "merlinbackup"

    struct ICloudBackup: Identifiable {
        let url: URL
        let name: String
        let date: Date
        var id: URL { url }
    }

    private static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    private static var cloudDocs: URL {
        home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }

    private static var cloudFolder: URL { cloudDocs.appendingPathComponent("Merlin Mouse", isDirectory: true) }

    private static var supportDir: URL {
        home.appendingPathComponent("Library/Application Support/MerlinMouse", isDirectory: true)
    }

    static var iCloudAvailable: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: cloudDocs.path, isDirectory: &isDir) && isDir.boolValue
    }

    private static func stamp(_ format: String, _ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f.string(from: date)
    }

    /// Kaydetme penceresinde önerilen ad.
    static func defaultFileName() -> String {
        let mac = Host.current().localizedName ?? "Mac"
        return "Merlin Mouse yedek \(stamp("yyyy-MM-dd HH-mm")) (\(mac)).\(fileExtension)"
    }

    private static func snapshot() -> MerlinBackup {
        let s = Settings.shared
        let settings = BackupSettings(zoneLayout: s.zoneLayout, appearance: s.appearance, language: s.language,
                                      flipY: s.flipY, blockScrollWhileDragging: s.blockScrollWhileDragging,
                                      calm3DScroll: s.calm3DScroll, batteryAlertsEnabled: s.batteryAlertsEnabled,
                                      pinchInvert: s.pinchInvert, pinchStep: s.pinchStep, edgeWidth: s.edgeWidth,
                                      edgeStep: s.edgeStep, edgeFineSteps: s.edgeFineSteps, edgeInvert: s.edgeInvert,
                                      edgeBounds: s.edgeBounds, trackpadCorners: s.trackpadCorners,
                                      editingDevice: s.editingDevice.rawValue)
        return MerlinBackup(bindings: BindingStore.shared.set, settings: settings)
    }

    static func exportTo(url: URL) throws {
        try snapshot().encode().write(to: url, options: .atomic)
        Log.write("Yedek yazıldı: \(url.lastPathComponent)")
    }

    /// iCloud Drive'daki "Merlin Mouse" klasörüne yazar; yazılan dosyayı döndürür.
    @discardableResult
    static func exportToICloud() throws -> URL {
        try FileManager.default.createDirectory(at: cloudFolder, withIntermediateDirectories: true)
        let url = cloudFolder.appendingPathComponent(defaultFileName())
        try exportTo(url: url)
        return url
    }

    /// En yeni 10 iCloud yedeği.
    static func latestICloudBackups() -> [ICloudBackup] {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: cloudFolder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return [] }
        let list = items.filter { $0.pathExtension == fileExtension }.map { url -> ICloudBackup in
            let date = (try? url.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
            return ICloudBackup(url: url, name: url.deletingPathExtension().lastPathComponent, date: date)
        }
        return Array(list.sorted { $0.date > $1.date }.prefix(10))
    }

    /// Önce geçerli durumu otomatik yedekler, sonra dosyayı uygular. Dosya geçersizse hiçbir şeye dokunmaz.
    static func importFrom(url: URL) throws {
        let backup = try MerlinBackup.decode(try Data(contentsOf: url))
        try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        let auto = supportDir.appendingPathComponent("yedek-önce-geri-yükleme-\(stamp("yyyy-MM-dd HH-mm-ss")).json")
        try snapshot().encode().write(to: auto, options: .atomic)

        BindingStore.shared.replaceAll(backup.bindings)
        // Değerler sıkıştırılmış gelir; yedekte olmayan alan atlanır (mevcut ayar değişmez).
        let st = backup.settings.restorable(), s = Settings.shared
        if let v = st.zoneLayout { s.zoneLayout = v }
        if let v = st.appearance { s.appearance = v }
        if let v = st.language { s.language = v }
        if let v = st.flipY { s.flipY = v }
        if let v = st.blockScrollWhileDragging { s.blockScrollWhileDragging = v }
        if let v = st.calm3DScroll { s.calm3DScroll = v }
        if let v = st.batteryAlertsEnabled { s.batteryAlertsEnabled = v }
        if let v = st.pinchInvert { s.pinchInvert = v }
        if let v = st.pinchStep { s.pinchStep = v }
        if let v = st.edgeWidth { s.edgeWidth = v }
        if let v = st.edgeStep { s.edgeStep = v }
        if let v = st.edgeFineSteps { s.edgeFineSteps = v }
        if let v = st.edgeInvert { s.edgeInvert = v }
        if let v = st.edgeBounds { s.edgeBounds = v }
        if let v = st.trackpadCorners { s.trackpadCorners = v }
        if let v = st.editingDevice.flatMap(InputDeviceKind.init(rawValue:)) { s.editingDevice = v }
        Log.write("Yedek geri yüklendi: \(url.lastPathComponent)")
    }
}
