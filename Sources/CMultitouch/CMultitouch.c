#include "CMultitouch.h"

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <dlfcn.h>
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

static int frameCallback(MTDeviceRef device, MTFinger *fingers, int count, double timestamp, int frame) {
    (void)device;
    (void)frame;
    OTTouch touches[16];
    int n = count < 16 ? count : 16;
    for (int i = 0; i < n; i++) {
        touches[i].identifier = fingers[i].identifier;
        touches[i].state = fingers[i].state;
        touches[i].x = fingers[i].normalized.pos.x;
        touches[i].y = fingers[i].normalized.pos.y;
        touches[i].size = fingers[i].size;
    }
    if (gHandler) gHandler(touches, n, timestamp);
    return 0;
}

// Magic Mouse aile kimlikleri 112–127 aralığında; trackpad'ler 128 ve üstü,
// dahili trackpad'ler ise "built-in" olarak işaretli.
static bool isMouse(MTDeviceRef device, int *familyOut) {
    int family = *familyOut; // IOKit'ten okunmuş olabilir; yoksa -1
    if (family < 0 && pGetFamilyID) pGetFamilyID(device, &family);
    *familyOut = family;
    bool builtIn = pIsBuiltIn ? pIsBuiltIn(device) : false;
    if (builtIn) return false;
    if (family >= 112 && family <= 127) return true;
    return family < 0; // aile okunamadıysa: dahili olmayan aygıtı fare say
}

void OTMultitouchStop(void) {
    for (int i = 0; i < gMiceCount; i++) {
        if (pUnregister) pUnregister(gMice[i], frameCallback);
        if (pStop) pStop(gMice[i]);
        if (gOwned && pRelease) pRelease(gMice[i]);
    }
    gMiceCount = 0;
    gOwned = false;
    if (gList) {
        CFRelease(gList);
        gList = NULL;
    }
}

static void addDescription(int family, bool mouse) {
    size_t len = strlen(gDesc);
    snprintf(gDesc + len, sizeof gDesc - len, "%saile %d%s", len ? ", " : "", family, mouse ? " (fare)" : "");
}

static void startMouse(MTDeviceRef device) {
    pRegister(device, frameCallback);
    pStart(device, 0);
    gMice[gMiceCount++] = device;
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
        bool mouse = isMouse(device, &family);
        addDescription(family, mouse);
        if (mouse && gMiceCount < MAX_MICE) {
            startMouse(device);
        } else if (pRelease) {
            pRelease(device);
        }
    }
    IOObjectRelease(it);
}

// Yedek yol: eski önbellekli liste.
static void startFromList(void) {
    gList = pCreateList();
    if (!gList) return;
    CFIndex total = CFArrayGetCount(gList);
    for (CFIndex i = 0; i < total; i++) {
        MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(gList, i);
        int family = -1;
        bool mouse = isMouse(device, &family);
        addDescription(family, mouse);
        if (mouse && gMiceCount < MAX_MICE) startMouse(device);
    }
}

int OTMultitouchStart(OTFrameHandler handler) {
    if (!load()) {
        snprintf(gDesc, sizeof gDesc, "MultitouchSupport yüklenemedi");
        return -1;
    }
    OTMultitouchStop();
    gHandler = handler;
    gDesc[0] = 0;
    if (pCreateFromService) startFromServices();
    else if (pCreateList) startFromList();
    return gMiceCount;
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
