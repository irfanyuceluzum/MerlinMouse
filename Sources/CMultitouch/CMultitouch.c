#include "CMultitouch.h"

#include <CoreFoundation/CoreFoundation.h>
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

#define MAX_MICE 8
static CFMutableArrayRef gList;
static MTDeviceRef gMice[MAX_MICE];
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
    return pCreateList && pRegister && pStart;
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
    int family = -1;
    if (pGetFamilyID) pGetFamilyID(device, &family);
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
    }
    gMiceCount = 0;
    if (gList) {
        CFRelease(gList);
        gList = NULL;
    }
}

int OTMultitouchStart(OTFrameHandler handler) {
    if (!load()) {
        snprintf(gDesc, sizeof gDesc, "MultitouchSupport yüklenemedi");
        return -1;
    }
    OTMultitouchStop();
    gHandler = handler;
    gList = pCreateList();
    gDesc[0] = 0;
    if (!gList) return 0;

    CFIndex total = CFArrayGetCount(gList);
    for (CFIndex i = 0; i < total; i++) {
        MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(gList, i);
        int family = -1;
        bool mouse = isMouse(device, &family);
        size_t len = strlen(gDesc);
        snprintf(gDesc + len, sizeof gDesc - len, "%saile %d%s", len ? ", " : "", family, mouse ? " (fare)" : "");
        if (mouse && gMiceCount < MAX_MICE) {
            pRegister(device, frameCallback);
            pStart(device, 0);
            gMice[gMiceCount++] = device;
        }
    }
    return gMiceCount;
}

const char *OTMultitouchDescribe(void) {
    return gDesc;
}
