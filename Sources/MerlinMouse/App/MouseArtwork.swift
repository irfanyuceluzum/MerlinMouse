import AppKit
import MerlinCore

/// Kullanıcının kendi Magic Mouse görseli (repoya konmaz): Application Support altındaki PNG.
enum MouseArtwork {
    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MerlinMouse", isDirectory: true)
    }

    static var fileURL: URL { directory.appendingPathComponent("magic-mouse.png") }

    /// Dosya varsa gövdeye kırpılmış görseli döndürür; yoksa ya da okunamazsa nil.
    static func load() -> NSImage? {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let rep = NSBitmapImageRep(data: data) else { return nil }
        // Piksel düzenini bilinen RGBA'ya çevir: yeniden çiz.
        let w = rep.pixelsWide, h = rep.pixelsHigh
        guard w > 0, h > 0, let cg = rep.cgImage,
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let base = { ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h)); return ctx.data }()
        else { return nil }
        let pixels = base.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var alpha = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) { alpha[i] = pixels[i * 4 + 3] }
        guard let box = AlphaBounds.opaqueRect(width: w, height: h, alpha: alpha, threshold: 200),
              let full = ctx.makeImage(),
              let cropped = full.cropping(to: CGRect(x: box.x, y: box.y, width: box.width, height: box.height))
        else { return nil }
        return NSImage(cgImage: cropped, size: NSSize(width: box.width, height: box.height))
    }
}
