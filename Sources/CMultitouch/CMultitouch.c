#include "CMultitouch.h"

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

// MultitouchSupport.framework'ün belgelenmemiş yapıları (MiddleClick vb. projelerle aynı düzen).
typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint pos, vel; } MTReadout;
typedef struct {
    int frame;
    double timestamp;
    int identifier, state, fingerID, handID;
    MTReadout normalized;
    float size;
    int zero1;
    float angle, majorAxis, minorAxis;
    MTReadout mm;
    int zero2[2];
    float unk2;
} MTFinger;

typedef void *MTDeviceRef;
typedef int (*MTContactCallback)(MTDeviceRef, MTFinger *, int, double, int);

static CFMutableArrayRef (*pCreateList)(void);
static void (*pRegister)(MTDeviceRef, MTContactCallback);
static void (*pUnregister)(MTDeviceRef, MTContactCallback);
static void (*pStart)(MTDeviceRef, int);
static void (*pStop)(MTDeviceRef);
static bool (*pIsBuiltIn)(MTDeviceRef);
static int (*pGetFamilyID)(MTDeviceRef, int *);
static MTDeviceRef (*pCreateFromService)(io_service_t);
static void (*pRelease)(MTDeviceRef);

#define MAX_MICE 8
static CFMutableArrayRef gList;
static MTDeviceRef gMice[MAX_MICE];
static bool gOwned; // gMice aygıtları servisten oluşturuldu (yani bizim bırakmamız gerek)
static int gMiceCount;
static OTFrameHandler gHandler;
static char gDesc[512];
// Son taramada görülen tüm aygıtlar (tanım).
#define MAX_DEVICES 16
static OTDeviceInfo gDevices[MAX_DEVICES];
static int gDeviceCount;
// Trackpad akışları: işleyici kuruluysa başlatılır; dizin = Swift'e giden yuva numarası.
#define MAX_PADS 4
static MTDeviceRef gPads[MAX_PADS];
static int gPadCount;
static OTDeviceFrameHandler gPadHandler;
static bool gPadsOwned;           // gPads servisten oluşturuldu (bırakmak bizim işimiz)
static CFMutableArrayRef gPadList; // yedek yolda trackpad'lerin listesi

// Kare geri çağrıları MT'nin arka iş parçacığında gelir; başlatma/durdurma ana iş parçacığındadır.
// gMice/gMiceCount/gHandler ve gPads/gPadCount/gPadHandler bu kilitle korunur. Kilit yalnız kısa okuma/yazma
// için tutulur: işleyici ve MT çağrıları (unregister/stop/release) kilit dışında yapılır; böylece uçuştaki bir
// geri çağrı kilidi beklerken durdurma onu beklerse kilitlenme olmaz.
static pthread_mutex_t gStreamLock = PTHREAD_MUTEX_INITIALIZER;

static bool load(void) {
    static void *handle;
    if (handle) return true;
    handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
    if (!handle) return false;
    pCreateList = dlsym(handle, "MTDeviceCreateList");
    pRegister = dlsym(handle, "MTRegisterContactFrameCallback");
    pUnregister = dlsym(handle, "MTUnregisterContactFrameCallback");
    pStart = dlsym(handle, "MTDeviceStart");
    pStop = dlsym(handle, "MTDeviceStop");
    pIsBuiltIn = dlsym(handle, "MTDeviceIsBuiltIn");
    pGetFamilyID = dlsym(handle, "MTDeviceGetFamilyID");
    pCreateFromService = dlsym(handle, "MTDeviceCreateFromService");
    pRelease = dlsym(handle, "MTDeviceRelease");
    return (pCreateList || pCreateFromService) && pRegister && pStart;
}

// En çok 16 parmağı sadeleştirilmiş biçime çevirir; yazılan sayıyı döner.
static int convert(const MTFinger *fingers, int count, OTTouch *touches) {
    int n = count < 16 ? count : 16;
    if (n < 0) n = 0;
    for (int i = 0; i < n; i++) {
        touches[i].identifier = fingers[i].identifier;
        touches[i].state = fingers[i].state;
        touches[i].x = fingers[i].normalized.pos.x;
        touches[i].y = fingers[i].normalized.pos.y;
        touches[i].size = fingers[i].size;
    }
    return n;
}

static int frameCallback(MTDeviceRef device, MTFinger *fingers, int count, double timestamp, int frame) {
    (void)device;
    (void)frame;
    pthread_mutex_lock(&gStreamLock);
    OTFrameHandler handler = gHandler;
    pthread_mutex_unlock(&gStreamLock);
    if (!handler) return 0;
    OTTouch touches[16];
    int n = convert(fingers, count, touches);
    handler(touches, n, timestamp);
    return 0;
}

// Trackpad kareleri: aygıtın yuvası bulunur ve kareyle birlikte iletilir (aygıtlar Swift'te ayrı tutulur).
static int padFrameCallback(MTDeviceRef device, MTFinger *fingers, int count, double timestamp, int frame) {
    (void)frame;
    int slot = -1;
    pthread_mutex_lock(&gStreamLock);
    for (int i = 0; i < gPadCount; i++) {
        if (gPads[i] == device) { slot = i; break; }
    }
    OTDeviceFrameHandler handler = slot >= 0 ? gPadHandler : NULL;
    pthread_mutex_unlock(&gStreamLock);
    if (!handler) return 0;
    OTTouch touches[16];
    int n = convert(fingers, count, touches);
    handler(slot, touches, n, timestamp);
    return 0;
}

// Magic Mouse aile kimlikleri 112–127 aralığında; trackpad'ler 128 ve üstü,
// dahili trackpad'ler ise "built-in" olarak işaretli.
static bool isMouse(MTDeviceRef device, int *familyOut, bool *builtInOut) {
    int family = *familyOut; // IOKit'ten okunmuş olabilir; yoksa -1
    if (family < 0 && pGetFamilyID) pGetFamilyID(device, &family);
    *familyOut = family;
    bool builtIn = pIsBuiltIn ? pIsBuiltIn(device) : false;
    *builtInOut = builtIn;
    if (builtIn) return false;
    if (family >= 112 && family <= 127) return true;
    return family < 0; // aile okunamadıysa: dahili olmayan aygıtı fare say
}

// Yalnız fare akışlarını durdurur (trackpad akışına dokunmaz).
// Kilit altında işleyici sıfırlanır ve liste yerel kopyaya alınır; MT çağrıları kilit dışında yapılır.
static void stopMice(void) {
    MTDeviceRef mice[MAX_MICE];
    pthread_mutex_lock(&gStreamLock);
    gHandler = NULL;
    int n = gMiceCount;
    for (int i = 0; i < n; i++) mice[i] = gMice[i];
    gMiceCount = 0;
    pthread_mutex_unlock(&gStreamLock);
    bool owned = gOwned;
    for (int i = 0; i < n; i++) {
        if (pUnregister) pUnregister(mice[i], frameCallback);
        if (pStop) pStop(mice[i]);
        if (owned && pRelease) pRelease(mice[i]);
    }
    gOwned = false;
    if (gList) {
        CFRelease(gList);
        gList = NULL;
    }
}

// Yalnız trackpad akışlarını durdurur (fare ile aynı desen).
static void stopPads(void) {
    MTDeviceRef pads[MAX_PADS];
    pthread_mutex_lock(&gStreamLock);
    gPadHandler = NULL;
    int n = gPadCount;
    for (int i = 0; i < n; i++) pads[i] = gPads[i];
    gPadCount = 0;
    pthread_mutex_unlock(&gStreamLock);
    bool owned = gPadsOwned;
    for (int i = 0; i < n; i++) {
        if (pUnregister) pUnregister(pads[i], padFrameCallback);
        if (pStop) pStop(pads[i]);
        if (owned && pRelease) pRelease(pads[i]);
    }
    gPadsOwned = false;
    if (gPadList) {
        CFRelease(gPadList);
        gPadList = NULL;
    }
}

void OTMultitouchStop(void) {
    stopMice();
    stopPads();
}

void OTMultitouchStopTrackpads(void) {
    stopPads();
}

// Açıklamaya ekler ve aygıtı tanım listesine yazar (`started`: fare olarak akışı başlatıldı mı).
static void addDescription(int family, bool builtIn, bool mouse, bool started) {
    size_t len = strlen(gDesc);
    // snprintf sınırı zaten aşmaz; koşul yalnız okunurluk için (dolu tamponda ekleme yok).
    if (len < sizeof gDesc) {
        snprintf(gDesc + len, sizeof gDesc - len, "%saile %d%s%s", len ? ", " : "", family,
                 builtIn ? " (dahili)" : "", mouse ? " (fare)" : "");
    }
    if (gDeviceCount < MAX_DEVICES) {
        gDevices[gDeviceCount].family = family;
        gDevices[gDeviceCount].builtIn = builtIn ? 1 : 0;
        gDevices[gDeviceCount].started = started ? 1 : 0;
        gDeviceCount++;
    }
}

static void startMouse(MTDeviceRef device) {
    pRegister(device, frameCallback);
    pStart(device, 0);
    pthread_mutex_lock(&gStreamLock);
    gMice[gMiceCount++] = device;
    pthread_mutex_unlock(&gStreamLock);
}

static void startPad(MTDeviceRef device) {
    // Yuva, geri çağrı gelmeden önce (kilit altında) yazılır.
    pthread_mutex_lock(&gStreamLock);
    gPads[gPadCount++] = device;
    pthread_mutex_unlock(&gStreamLock);
    pRegister(device, padFrameCallback);
    pStart(device, 0);
}

// IOKit servislerinden: önbellekli MTDeviceCreateList'in aksine her çağrıda güncel aygıtları verir.
static void startFromServices(void) {
    io_iterator_t it = IO_OBJECT_NULL;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleMultitouchDevice"), &it) != KERN_SUCCESS) return;
    gOwned = true;
    io_service_t service;
    while ((service = IOIteratorNext(it)) != IO_OBJECT_NULL) {
        int family = -1;
        CFTypeRef prop = IORegistryEntryCreateCFProperty(service, CFSTR("Family ID"), kCFAllocatorDefault, 0);
        if (prop) {
            if (CFGetTypeID(prop) == CFNumberGetTypeID()) CFNumberGetValue(prop, kCFNumberIntType, &family);
            CFRelease(prop);
        }
        MTDeviceRef device = pCreateFromService(service);
        IOObjectRelease(service);
        if (!device) continue;
        bool builtIn = false;
        bool mouse = isMouse(device, &family, &builtIn);
        bool start = mouse && gMiceCount < MAX_MICE;
        addDescription(family, builtIn, mouse, start);
        if (start) {
            startMouse(device);
        } else if (pRelease) {
            pRelease(device);
        }
    }
    IOObjectRelease(it);
}

// Servisteki aygıtın aile kimliği; okunamadıysa -1.
static int serviceFamily(io_service_t service) {
    int family = -1;
    CFTypeRef prop = IORegistryEntryCreateCFProperty(service, CFSTR("Family ID"), kCFAllocatorDefault, 0);
    if (prop) {
        if (CFGetTypeID(prop) == CFNumberGetTypeID()) CFNumberGetValue(prop, kCFNumberIntType, &family);
        CFRelease(prop);
    }
    return family;
}

// Trackpad'ler (fare olmayan aygıtlar) IOKit servislerinden; fare taramasından bağımsız.
static void padsFromServices(void) {
    io_iterator_t it = IO_OBJECT_NULL;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleMultitouchDevice"), &it) != KERN_SUCCESS) return;
    gPadsOwned = true;
    io_service_t service;
    while ((service = IOIteratorNext(it)) != IO_OBJECT_NULL) {
        int family = serviceFamily(service);
        MTDeviceRef device = pCreateFromService(service);
        IOObjectRelease(service);
        if (!device) continue;
        bool builtIn = false;
        bool mouse = isMouse(device, &family, &builtIn);
        if (!mouse && gPadCount < MAX_PADS) {
            startPad(device);
        } else if (pRelease) {
            pRelease(device);
        }
    }
    IOObjectRelease(it);
}

// Yedek yol: ayrı bir önbellekli liste (fare listesinden bağımsız bırakılır).
static void padsFromList(void) {
    gPadList = pCreateList();
    if (!gPadList) return;
    CFIndex total = CFArrayGetCount(gPadList);
    for (CFIndex i = 0; i < total; i++) {
        MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(gPadList, i);
        int family = -1;
        bool builtIn = false;
        bool mouse = isMouse(device, &family, &builtIn);
        if (!mouse && gPadCount < MAX_PADS) startPad(device);
    }
}

// Yedek yol: eski önbellekli liste.
static void startFromList(void) {
    gList = pCreateList();
    if (!gList) return;
    CFIndex total = CFArrayGetCount(gList);
    for (CFIndex i = 0; i < total; i++) {
        MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(gList, i);
        int family = -1;
        bool builtIn = false;
        bool mouse = isMouse(device, &family, &builtIn);
        bool start = mouse && gMiceCount < MAX_MICE;
        addDescription(family, builtIn, mouse, start);
        if (start) startMouse(device);
    }
}

int OTMultitouchStart(OTFrameHandler handler) {
    if (!load()) {
        snprintf(gDesc, sizeof gDesc, "MultitouchSupport yüklenemedi");
        return -1;
    }
    // Yalnız fareler yeniden başlar; trackpad akışı ayrı yönetilir.
    stopMice();
    pthread_mutex_lock(&gStreamLock);
    gHandler = handler;
    pthread_mutex_unlock(&gStreamLock);
    gDesc[0] = 0;
    gDeviceCount = 0;
    if (pCreateFromService) startFromServices();
    else if (pCreateList) startFromList();
    return gMiceCount;
}

int OTMultitouchStartTrackpads(OTDeviceFrameHandler handler) {
    if (!load()) return -1;
    stopPads();
    pthread_mutex_lock(&gStreamLock);
    gPadHandler = handler;
    pthread_mutex_unlock(&gStreamLock);
    if (!handler) return 0;
    if (pCreateFromService) padsFromServices();
    else if (pCreateList) padsFromList();
    return OTMultitouchTrackpadCount();
}

int OTMultitouchTrackpadCount(void) {
    pthread_mutex_lock(&gStreamLock);
    int n = gPadCount;
    pthread_mutex_unlock(&gStreamLock);
    return n;
}

// --- Aygıt ekleme/çıkarma izleme ---
static void (*gOnChange)(void);
static IONotificationPortRef gNotifyPort;

static void drain(io_iterator_t it) {
    io_object_t obj;
    while ((obj = IOIteratorNext(it)) != IO_OBJECT_NULL) IOObjectRelease(obj);
}

static void deviceChanged(void *refcon, io_iterator_t it) {
    (void)refcon;
    drain(it);
    if (gOnChange) gOnChange();
}

void OTMultitouchWatchDevices(void (*onChange)(void)) {
    if (gNotifyPort) return; // bir kez kurulur
    gOnChange = onChange;
    gNotifyPort = IONotificationPortCreate(kIOMainPortDefault);
    if (!gNotifyPort) return;
    CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(gNotifyPort), kCFRunLoopDefaultMode);
    const io_name_t types[2] = {kIOFirstMatchNotification, kIOTerminatedNotification};
    for (int i = 0; i < 2; i++) {
        io_iterator_t it = IO_OBJECT_NULL;
        if (IOServiceAddMatchingNotification(gNotifyPort, types[i], IOServiceMatching("AppleMultitouchDevice"),
                                             deviceChanged, NULL, &it) == KERN_SUCCESS) {
            drain(it); // ilk boşaltma bildirimi etkinleştirir; yalnız sonraki değişiklikler gelir
        }
    }
}

const char *OTMultitouchDescribe(void) {
    return gDesc;
}

int OTMultitouchDevices(OTDeviceInfo *out, int max) {
    int n = gDeviceCount < max ? gDeviceCount : max;
    for (int i = 0; i < n; i++) out[i] = gDevices[i];
    return n < 0 ? 0 : n;
}
