import AppKit

/// Uygulama simgeleri; paket kimliğine göre önbellekli (bulunamadı sonucu da).
/// Yalnız ana iş parçacığında, arayüzden çağrılır; olay yakalayıcıdan çağrılmaz.
enum AppIcons {
    /// nil değer = arandı, bulunamadı.
    private static var cache: [String: NSImage?] = [:]

    static func icon(bundleID: String) -> NSImage? {
        dispatchPrecondition(condition: .onQueue(.main))
        if let hit = cache[bundleID] { return hit }
        var image: NSImage?
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            image = NSWorkspace.shared.icon(forFile: url.path)
        }
        cache[bundleID] = .some(image)
        return image
    }

    /// Menü gibi çerçevenin işlemediği yerler için verilen boyda kopya.
    static func resized(_ image: NSImage, side: CGFloat) -> NSImage {
        let copy = (image.copy() as? NSImage) ?? image
        copy.size = NSSize(width: side, height: side)
        return copy
    }

    /// Kimliklerden ilk bulunan uygulamanın simgesi.
    static func firstIcon(bundleIDs: [String]) -> NSImage? {
        for id in bundleIDs {
            if let img = icon(bundleID: id) { return img }
        }
        return nil
    }
}
