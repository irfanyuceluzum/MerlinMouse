#pragma once

/// Swift tarafına aktarılan sadeleştirilmiş dokunuş.
/// x: 0 = sol, 1 = sağ. y: 0 = arka (avuç), 1 = ön (uç).
typedef struct {
    int identifier;
    int state;
    float x;
    float y;
    float size;
} OTTouch;

typedef void (*OTFrameHandler)(const OTTouch *touches, int count, double timestamp);

/// Trackpad karesi: `slot` başlatılan trackpad aygıtının sırası (0…); aynı trackpad birden çok aygıt
/// olarak görünebildiği için Swift tarafı aygıt başına ayrı durum tutar.
typedef void (*OTDeviceFrameHandler)(int slot, const OTTouch *touches, int count, double timestamp);

/// Magic Mouse aygıtlarını bulur ve dokunma akışını (yeniden) başlatır; trackpad akışına dokunmaz.
/// Bulunan fare sayısını döner; framework yüklenemezse -1.
int OTMultitouchStart(OTFrameHandler handler);

/// Bağlı trackpad'leri (fare olmayan aygıtlar) tarar ve akışlarını (yeniden) başlatır; fare akışına dokunmaz.
/// Başlatılan trackpad aygıtı sayısını döner (NULL işleyiciyle 0); framework yüklenemezse -1.
int OTMultitouchStartTrackpads(OTDeviceFrameHandler handler);

/// Yalnız trackpad akışlarını durdurur ve bırakır.
void OTMultitouchStopTrackpads(void);

/// Şu an akışı açık trackpad aygıtı sayısı.
int OTMultitouchTrackpadCount(void);

/// Aygıt eklenince/çıkarılınca (Bluetooth bağlanma/kopma) ana run loop'ta `onChange` çağrılır.
/// Bir kez kurulur; sonraki çağrılar yok sayılır. Ana iş parçacığından çağrılmalı.
void OTMultitouchWatchDevices(void (*onChange)(void));

/// Fare ve trackpad akışlarının hepsini durdurur ve aygıt listelerini bırakır.
void OTMultitouchStop(void);

/// Son taramada görülen aygıtların kısa açıklaması (hata ayıklama için).
const char *OTMultitouchDescribe(void);

/// Son taramada görülen bir dokunma aygıtı.
typedef struct {
    int family;   ///< MultitouchSupport aile kimliği; okunamadıysa -1.
    int builtIn;  ///< 1: dahili (MacBook trackpad'i), 0: harici.
    int started;  ///< 1: Magic Mouse olarak dokunma akışı başlatıldı.
} OTDeviceInfo;

/// Son `OTMultitouchStart` taramasındaki aygıtları `out`'a (en çok `max` tane) yazar; yazılan sayıyı döner.
/// `started` yalnız fareleri gösterir; trackpad akışları `OTMultitouchTrackpadCount` ile sayılır.
int OTMultitouchDevices(OTDeviceInfo *out, int max);
