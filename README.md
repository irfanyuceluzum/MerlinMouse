# Merlin Mouse

Apple Magic Mouse için menü çubuğu uygulaması. Magic Mouse'un dokunmatik yüzeyini
okuyup orta tuşu olmayan farede **orta tıklama ve orta tuşla sürükleme** sağlar;
3D ve dilimleyici programlarda (Chitubox, Bambu Studio, Blender, Lychee…) görünümü
kaydırmak/döndürmek için tasarlandı.

> Erken prototip. Yol haritasında: yapılandırılabilir hareket → eylem atamaları
> (basış şekli, parmak sayısı, bölge, kısayol, uygulama başına profil) ve tam
> ayar penceresi.

## Neler yapıyor

- **Orta bölgeye bas** → orta tıklama; basılı tutup sürükle → orta tuş sürüklemesi
- **İki / üç parmakla bas** → orta tıklama
- **Fn + sol sürükleme** → orta tuş sürüklemesi
- **Üç parmakla dokun** (isteğe bağlı) → orta tıklama
- Orta tuşla sürüklerken **kaydırmayı engeller** (model istemeden yakınlaşmaz)
- 3D programlarda **ataletli kaydırmayı kapatır** (yakınlaştırma adım adım)
- macOS fare hareketleri ve BetterTouchTool ile **çakışma uyarıları**
- Menü çubuğu panelinde **canlı dokunma haritası**, Sistem / Gündüz / Gece görünümü

Normal sol tıklama hiçbir zaman değiştirilmez. MacBook'un dahili trackpad'i dinlenmez.

## Gereksinimler

- macOS 14 veya üstü
- Swift 5.9+ (Xcode ya da Command Line Tools)
- Magic Mouse

## Derleme ve çalıştırma

```bash
./build.sh
open build/MerlinMouse.app
```

İlk açılışta **Sistem Ayarları › Gizlilik ve Güvenlik › Erişilebilirlik** bölümünde
Merlin Mouse'a izin ver. Tıklamaları orta tuşa çevirebilmek için bu izin gerekir.

`build.sh`, anahtar zincirinde bir "Apple Development" sertifikası varsa onunla imzalar;
yoksa yerel (ad-hoc) imza kullanır. Ad-hoc imzada her yeniden derlemeden sonra
Erişilebilirlik iznini kapatıp açman gerekir.

Tanılama:

```bash
build/MerlinMouse.app/Contents/MacOS/MerlinMouse --probe   # bulunan dokunma aygıtları
tail -f ~/Library/Logs/MerlinMouse.log                     # durum ve her orta tuş eylemi
```

## Nasıl çalışıyor

- `Sources/CMultitouch` — macOS'un belgelenmemiş `MultitouchSupport.framework`'üne
  `dlopen` ile bağlanır ve yalnız Magic Mouse'un parmak konumlarını okur.
- `Sources/MerlinMouse/Input` — bir `CGEventTap` sol/sağ tıklamaları yakalar; o anki
  parmak konumuna göre kurala uyanları orta tuş (button 2) olaylarına çevirir.
- `Sources/MerlinMouse/UI` — SwiftUI menü çubuğu paneli.

## Notlar

- Gizli bir sistem framework'ü kullandığı için App Store'da dağıtılamaz ve bir macOS
  güncellemesiyle bozulabilir.
- Apple Inc. ile bağlantısı yoktur. Magic Mouse, Apple Inc.'in ticari markasıdır.

## Lisans

[MIT](LICENSE)
