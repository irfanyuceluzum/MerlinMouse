import AppKit
import MerlinCore

/// BetterTouchTool atamalarını SALT OKUNUR tarar (yalnız `get_triggers`); BTT'de hiçbir şey değiştirmez.
/// Ham JSON diske ve loga yazılmaz.
enum BTTScanner {
    static let bundleID = "com.hegenberg.BetterTouchTool"
    private static let timeout: TimeInterval = 60

    static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    /// Tamamlanma ana iş parçacığında çağrılır.
    static func scan(completion: @escaping (Result<BTTScan, ScanError>) -> Void) {
        guard isRunning else {
            DispatchQueue.main.async { completion(.failure(ScanError("BetterTouchTool çalışmıyor"))) }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = run()
            if case .success(let s) = result {
                Log.write("BTT tarandı: \(s.magicMouse.count) Magic Mouse ataması")
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    struct ScanError: Error {
        let message: String
        init(_ message: String) { self.message = message }
    }

    private static func run() -> Result<BTTScan, ScanError> {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", "tell application \"BetterTouchTool\" to get_triggers"]
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        do { try p.run() } catch {
            return .failure(ScanError("osascript başlatılamadı"))
        }

        var timedOut = false
        let lock = NSLock()
        let killer = DispatchWorkItem {
            lock.lock(); timedOut = true; lock.unlock()
            if p.isRunning { p.terminate() }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)

        // Boru dolup kilitlenmesin diye stderr ayrı kuyrukta okunur.
        var errData = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            errData = err.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        group.wait()
        killer.cancel()

        lock.lock(); let didTimeOut = timedOut; lock.unlock()
        if didTimeOut { return .failure(ScanError("BetterTouchTool yanıt vermedi (60 sn zaman aşımı)")) }

        if p.terminationStatus != 0 {
            let msg = String(data: errData, encoding: .utf8) ?? ""
            if msg.contains("-1743") || msg.lowercased().contains("not authorized") {
                return .failure(ScanError("İzin verilmedi: Sistem Ayarları › Gizlilik ve Güvenlik › Otomasyon'da Merlin Mouse için BetterTouchTool'u aç."))
            }
            return .failure(ScanError("BetterTouchTool taranamadı. Uygulamanın açık olduğundan emin ol."))
        }
        do {
            return .success(try BTTImport.parse(outData))
        } catch {
            return .failure(ScanError("BetterTouchTool'dan gelen veri okunamadı."))
        }
    }
}
