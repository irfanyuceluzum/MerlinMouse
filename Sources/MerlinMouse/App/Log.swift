import Foundation

/// ~/Library/Logs/MerlinMouse.log dosyasına kısa durum satırları yazar.
/// Test sırasında ne olduğunu görmek için: tail -f ~/Library/Logs/MerlinMouse.log
enum Log {
    private static let queue = DispatchQueue(label: "MerlinMouse.log")
    private static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/MerlinMouse.log")
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static func write(_ message: String) {
        let line = "\(formatter.string(from: Date())) \(message)\n"
        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }
}
