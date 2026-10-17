import AppKit
import ApplicationServices
import Combine
import UserNotifications

/// Erişilebilirlik izni: canlı yoklamalı durum, izin isteme, sıfırlama ve izin kaybı bildirimi.
/// `AppModel` bunu sahiplenir ve değişiklikleri kendi `objectWillChange`'ine iletir.
final class AccessibilityManager: ObservableObject {
    @Published private(set) var trusted = false
    /// İzin sıfırlama başarısız olduysa doğru; yönerge dil değişince de güncel kalsın diye metin hesaplanır.
    @Published private(set) var permissionResetFailed = false
    /// İzin sıfırlama başarısız olursa kullanıcıya gösterilen yönerge.
    var permissionHelp: String? {
        permissionResetFailed
            ? L("Sıfırlanamadı. Sistem Ayarları › Gizlilik ve Güvenlik › Erişilebilirlik'te Merlin Mouse'u – ile silip + ile /Applications/MerlinMouse.app'i yeniden ekle.")
            : nil
    }

    /// Bu açılışta macOS izin penceresi gösterildi mi (tek ekran kuralı).
    private var promptedThisLaunch = false
    /// İzin sıfırlanıyor (tccutil sürüyor): yakalayıcı bu arada yeniden kurulmaz.
    private var resetInProgress = false

    /// Erişilebilirlik izinleri değişince macOS bu bildirimi yollar; izin geri alındıysa yakalayıcı
    /// 2 sn'lik turu beklemeden kalksın. TCC kaydı gecikebildiği için kısa aralıklarla birkaç kez bakılır.
    func observeSystemChanges() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [weak self] _ in
            self?.checkTrust(prompt: false)
            for delay in [0.25, 0.75, 1.5] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self?.checkTrust(prompt: false) }
            }
        }
    }

    func checkTrust(prompt: Bool) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        let axTrusted = AXIsProcessTrustedWithOptions(options)
        // AXIsProcessTrusted önbellekli: izin geri alınsa da "var" der. Gerçek durum canlı yoklamayla doğrulanır.
        let nowTrusted = axTrusted && InputTap.canCreateActiveTap()
        if prompt && !axTrusted { promptedThisLaunch = true }
        if nowTrusted != trusted || prompt { Log.write("Erişilebilirlik izni: \(nowTrusted ? "var" : "yok")") }
        if nowTrusted != trusted {
            let lost = trusted && !nowTrusted
            trusted = nowTrusted
            // Kullanıcının kendi başlattığı sıfırlamada bildirim gönderilmez.
            if lost && !resetInProgress { notifyPermissionLost() }
        }
        // İzin gitti: yakalayıcı hemen kalkar, yoksa sistemin fare olayları donar.
        if !nowTrusted && InputTap.shared.isRunning {
            InputTap.shared.stop()
            GestureDispatcher.endPinchSession()
            GestureDispatcher.endEdgeSession()
            Log.write("İzin yok: olay yakalayıcı durduruldu")
        }
        if trusted && !resetInProgress && !InputTap.shared.isRunning {
            Log.write(InputTap.shared.start() ? "Olay yakalayıcı çalışıyor" : "Olay yakalayıcı başlatılamadı")
        }
    }

    /// İzin çalışırken geri alındı: menü çubuğu uygulaması olduğu için ayrıca sistem bildirimi gönderilir.
    private func notifyPermissionLost() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else {
                Log.write("İzin bildirimi gönderilemedi: bildirim izni yok")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = L("Erişilebilirlik izni kaldırıldı")
            content.body = L("Merlin Mouse hareketleri şu an dönüştüremiyor. İzni yeniden vermek için menü çubuğundaki Merlin Mouse simgesine tıkla.")
            content.sound = .default
            let request = UNNotificationRequest(identifier: "permission-lost", content: content, trigger: nil)
            center.add(request) { error in
                if let error { Log.write("İzin bildirimi eklenemedi: \(error.localizedDescription)") }
            }
        }
    }

    /// İzin ister: bu açılışta ilk kez macOS'un izin penceresini (uygulamayı listeye de ekler),
    /// sonrasında (ya da izin zaten varsa) yalnız Sistem Ayarları'nı açar.
    func requestPermission() {
        // Önbellekteki AX "var" diyorsa macOS izin penceresini göstermez; o durumda da Ayarlar açılır.
        if trusted || promptedThisLaunch || AXIsProcessTrusted() {
            openAccessibilitySettings()
        } else {
            checkTrust(prompt: true)
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Eski (yeniden derleme yüzünden geçersiz kalan) Erişilebilirlik kaydını siler, izni yeniden ister.
    func resetAccessibilityPermission() {
        let bundleID = Bundle.main.bundleIdentifier ?? "dev.merlinmouse.MerlinMouse"
        permissionResetFailed = false
        // İzin silinmeden ÖNCE yakalayıcı kalkar; çalışırken silinirse fare ve ekran donar.
        // Sıfırlama bitene kadar yakalayıcı yeniden kurulmaz.
        resetInProgress = true
        InputTap.shared.stop()
        GestureDispatcher.endPinchSession()
        GestureDispatcher.endEdgeSession()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", "Accessibility", bundleID]
            var ok = false
            do {
                try process.run()
                process.waitUntilExit()
                ok = process.terminationStatus == 0
                Log.write("İzin sıfırlama (tccutil) · çıkış \(process.terminationStatus)")
            } catch {
                Log.write("İzin sıfırlama başarısız: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.resetInProgress = false
                // Sıfırlama başarılıysa uygulama yeniden başlar: AX önbelleği bu süreçte "var" demeye devam
                // ettiği için izin penceresi ancak yeni süreçte çıkar (açılışta tek ekran olarak).
                // Başarısızsa yalnız Sistem Ayarları açılır.
                if ok {
                    self.relaunch()
                } else {
                    self.permissionResetFailed = true
                    self.checkTrust(prompt: false)
                    self.openAccessibilitySettings()
                }
            }
        }
    }

    /// Uygulamayı kapatıp 1 sn sonra yeniden açar (yeni süreç izni baştan okur).
    private func relaunch() {
        Log.write("İzin sıfırlandı: uygulama yeniden başlatılıyor")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        do {
            try process.run()
            NSApp.terminate(nil)
        } catch {
            Log.write("Yeniden başlatılamadı: \(error.localizedDescription)")
            openAccessibilitySettings()
        }
    }
}
