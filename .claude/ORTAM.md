# Proje profili — Merlin Mouse

macOS menü çubuğu uygulaması: Magic Mouse dokunmatik yüzeyini okuyup tıklamaları
orta tuşa ve başka eylemlere çevirir. SwiftPM paketi, Swift 5 dil modu, macOS 14+.

## Harita
- `Package.swift` — iki hedef: `CMultitouch` (C köprüsü) ve `MerlinMouse` (uygulama).
- `Sources/CMultitouch/` — özel MultitouchSupport.framework'e dlopen köprüsü; yalnız Magic Mouse'u (aile 112–127, dahili olmayan) dinler.
- `Sources/MerlinMouse/App/` — giriş noktası (`MerlinMouseApp.swift`), durum (`AppModel.swift`), ayarlar (`Settings.swift`), günlük (`Log.swift`).
- `Sources/MerlinMouse/Input/` — dokunma okuyucu (`TouchMonitor.swift`), olay yakalayıcı + öndeki uygulama (`EventTapper.swift`).
- `Sources/MerlinMouse/UI/` — menü çubuğu paneli ve fare haritası (`PanelView.swift`).
- `Resources/Info.plist` — paket kimliği `dev.merlinmouse.MerlinMouse`, LSUIElement.
- `build.sh` — release derleme + `build/MerlinMouse.app` paketleme + imzalama.

## Büyük dosyalar
- Yok (kaynakların hepsi < 20 KB).

## Bakılmayacak dizinler
- `.build/`, `build/`, `.claude/tmp/`

## Yazma yasakları (implementer hiçbir durumda yazmaz)
- `.build/`, `build/` — derleme çıktısı.
- `.claude/` — orkestra profili; yalnız kullanıcı onayıyla değişir.
- `Resources/Info.plist` içindeki `CFBundleIdentifier` — değişirse Erişilebilirlik izni kaybolur.

## Canlı sisteme giden komutlar (hiçbir ajan çalıştırmaz)
- `open build/MerlinMouse.app`, `pkill … MerlinMouse` — kullanıcının çalışan uygulamasını açar/kapatır; fare girdisini etkiler. Yalnız ana oturum, kullanıcıya söyleyerek.
- `tccutil …`, TCC veritabanı — güvenlik izinleri; asla.
- `defaults write com.apple.*`, BetterTouchTool'a AppleScript — sistem/BTT ayarlarını değiştirir; asla.
- `codesign` dışında anahtar zinciri / sertifika komutları (`security add…`, `security import`) — asla.

## Biçimlendirme (yalnız yeni dosyalarda)
- Biçimlendirici yok; 4 boşluk girinti, mevcut dosyaların üslubu.

## Kod kuralları (implementer)
- Yorumlar ve arayüz metinleri Türkçe; yorum yoğunluğu çevredeki kod kadar.
- Swift 5 dil modu (tools 5.9); Swift 6 katı eşzamanlılık özelliklerine dayanma.
- Olay yakalayıcı geri çağrısı ana iş parçacığında ve hızlı olmalı: dosya/ağ/süreç işi yapma, gerekiyorsa `DispatchQueue.main.async` ile ertele.
- Kendi ürettiğin her sentetik olayı `EventTapper.syntheticTag` ile işaretle; yakalayıcı bunları atlar.
- `TouchMonitor` geri çağrısı arka iş parçacığında gelir; paylaşılan durumu kilitle koru, arayüze `DispatchQueue.main.async` ile gönder.
- Yeni özellik = ayrı modül/dosya; mevcut sınıfa yığma.
- SwiftUI'de kendi tiplerin SwiftUI adlarıyla çakışmasın (`Binding`, `Settings` vb. yeni tip adı kullanma).

## Korunacak davranışlar
- Tek parmakla sol bölgeye normal sol tıklama hiçbir koşulda dönüştürülmez/geciktirilmez.
- Dahili trackpad dinlenmez; yalnız Magic Mouse.
- Orta tuşla sürüklerken kaydırma engeli; 3D programlarda atalet kapatma.
- `~/Library/Logs/MerlinMouse.log` günlüğü (başlangıç, fare, izin, her eylem).
- `MerlinMouse --probe` tanılama çıktısı.
- İzin yokken sessiz bekleme, izin gelince yakalayıcıyı kendiliğinden başlatma.

## Risk listesi (danisman)
- Olay yakalayıcıda yavaşlık/kilitlenme tüm fare girdisini dondurur; zaman aşımında yeniden etkinleştirme şart.
- Sentetik olay döngüsü (kendi olayını tekrar yakalamak).
- `MTFinger` yapı düzeni belgelenmemiş; macOS güncellemesinde bozulabilir.
- Yanlış dönüştürme: dinlenen parmaklar yüzünden normal tıklamanın orta tıka dönmesi.
- Kapsam: uygulamaya özel atamanın genel atamayı doğru ezmesi.

## Ortam kısıtları
- macOS 27, Swift 6.4, Xcode kurulu; Python'da PIL/numpy yok.
- Kod imzalama sertifikası yok → ad-hoc imza; her yeniden derlemede Erişilebilirlik izni yenilenmeli.
- Ajanlar uygulamayı çalıştıramaz; davranış testi kullanıcının gerçek faresiyle yapılır, ajan doğrulaması derleme + kod incelemesidir.
