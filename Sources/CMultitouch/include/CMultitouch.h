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

/// Magic Mouse aygıtlarını bulur ve dokunma akışını başlatır.
/// Bulunan fare sayısını döner; framework yüklenemezse -1.
int OTMultitouchStart(OTFrameHandler handler);

/// Aygıt eklenince/çıkarılınca (Bluetooth bağlanma/kopma) ana run loop'ta `onChange` çağrılır.
/// Bir kez kurulur; sonraki çağrılar yok sayılır. Ana iş parçacığından çağrılmalı.
void OTMultitouchWatchDevices(void (*onChange)(void));

/// Akışı durdurur ve aygıt listesini bırakır.
void OTMultitouchStop(void);

/// Son taramada görülen aygıtların kısa açıklaması (hata ayıklama için).
const char *OTMultitouchDescribe(void);

/// Son taramada görülen bir dokunma aygıtı (yalnız tanım; akış başlatılmaz).
typedef struct {
    int family;   ///< MultitouchSupport aile kimliği; okunamadıysa -1.
    int builtIn;  ///< 1: dahili (MacBook trackpad'i), 0: harici.
    int started;  ///< 1: Magic Mouse olarak dokunma akışı başlatıldı.
} OTDeviceInfo;

/// Son `OTMultitouchStart` taramasındaki aygıtları `out`'a (en çok `max` tane) yazar; yazılan sayıyı döner.
/// Trackpad'ler yalnız sayılır ve tanımlanır: akışları başlatılmaz, geri çağrı kaydedilmez.
int OTMultitouchDevices(OTDeviceInfo *out, int max);
