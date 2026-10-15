import Foundation
import IOKit
import Combine
import UserNotifications
import MerlinCore

/// Magic Mouse pil yüzdesini IOKit'ten okur, yayınlar ve düşük pilde bildirim gönderir.
final class BatteryMonitor: ObservableObject {
    static let shared = BatteryMonitor()

    @Published private(set) var percent: Int?
    @Published private(set) var lastRead: Date?

    private let queue = DispatchQueue(label: "MerlinMouse.battery", qos: .utility)
    private var timer: Timer?
    private var policy: BatteryAlertPolicy
    private static let notifiedKey = "batteryNotified"

    private init() {
        let saved = (UserDefaults.standard.array(forKey: Self.notifiedKey) as? [Int]) ?? []
        policy = BatteryAlertPolicy(notified: Set(saved))
    }

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        queue.async { [weak self] in
            let value = Self.readPercent()
            DispatchQueue.main.async { self?.apply(value) }
        }
    }

    private func apply(_ value: Int?) {
        if value != percent {
            Log.write("Magic Mouse pili: " + (value.map { "%\($0)" } ?? "okunamadı"))
        }
        percent = value
        if value != nil { lastRead = Date() }
        guard let value, Settings.shared.batteryAlertsEnabled else { return }
        if let threshold = policy.update(percent: value) {
            UserDefaults.standard.set(Array(policy.notified).sorted(), forKey: Self.notifiedKey)
            notify(threshold: threshold, percent: value)
        } else {
            UserDefaults.standard.set(Array(policy.notified).sorted(), forKey: Self.notifiedKey)
        }
    }

    private func notify(threshold: Int, percent: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else {
                Log.write("Pil bildirimi gönderilemedi: bildirim izni yok")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = threshold <= 10 ? "Magic Mouse pili kritik: %\(percent)" : "Magic Mouse pili %\(percent)"
            content.body = "Şarj etmeyi unutma; şarj sırasında fare kullanılamaz."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "battery-\(threshold)", content: content, trigger: nil)
            center.add(request) { error in
                if let error { Log.write("Pil bildirimi eklenemedi: \(error.localizedDescription)") }
                else { Log.write("Pil bildirimi gönderildi · eşik %\(threshold)") }
            }
        }
    }

    /// Eşleşen ilk Magic Mouse'un BatteryPercent değeri.
    private static func readPercent() -> Int? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDeviceManagementHIDEventService"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            func int(_ key: String) -> Int? {
                (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber)?.intValue
            }
            guard let vendor = int("VendorID"), let product = int("ProductID"),
                  MagicMouseIDs.isMagicMouse(vendorID: vendor, productID: product),
                  let battery = int("BatteryPercent") else { continue }
            return battery
        }
        return nil
    }
}
