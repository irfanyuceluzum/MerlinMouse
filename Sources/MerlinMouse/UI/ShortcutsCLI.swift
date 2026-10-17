import Foundation

/// `shortcuts list` çıktısı; süreç ana iş parçacığı dışında çalışır.
enum ShortcutsCLI {
    static func list(_ done: @escaping ([String]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            p.arguments = ["list"]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = FileHandle.nullDevice
            var names: [String] = []
            do {
                try p.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                names = String(decoding: data, as: UTF8.self)
                    .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            } catch {}
            DispatchQueue.main.async { done(names) }
        }
    }
}
