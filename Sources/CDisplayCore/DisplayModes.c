// Thanks to Phoenix Dev for modes_D4 type and CopyAllDisplayModes for use with
// Apple's private core graphics APIs https://github.com/NUIKit/CGSInternal
//
// This is the only C code in the private-API boundary beyond MonitorPanel.m -
// it exposes a plain DisplayMode struct so Swift never has to do raw
// unaligned-union pointer math on modes_D4 itself. It does not change any CGS
// call or its behavior.
#include "include/CDisplayCore.h"
#include <stdint.h>

typedef union
{
    uint8_t rawData[0xDC];
    struct
    {
        uint32_t mode;
        uint32_t flags;  // 0x4
        uint32_t width;  // 0x8
        uint32_t height; // 0xC
        uint32_t depth;  // 0x10
        uint32_t dc2[42];
        uint16_t dc3;
        uint16_t freq; // 0xBC
        uint32_t dc4[4];
        float density; // 0xD0
    } derived;
} modes_D4;

void CGSGetCurrentDisplayMode(CGDirectDisplayID display, int *modeNum);
void CGSGetNumberOfDisplayModes(CGDirectDisplayID display, int *nModes);
void CGSGetDisplayModeDescriptionOfLength(CGDirectDisplayID display, int idx, modes_D4 *mode, int length);
void CGSConfigureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int modeNum);
CGError CGSConfigureDisplayEnabled(CGDisplayConfigRef config, CGDirectDisplayID display, bool enabled);

int getDisplayModeCount(CGDirectDisplayID display)
{
    int nModes = 0;
    CGSGetNumberOfDisplayModes(display, &nModes);
    return nModes;
}

DisplayMode getDisplayMode(CGDirectDisplayID display, int index)
{
    modes_D4 mode;
    CGSGetDisplayModeDescriptionOfLength(display, index, &mode, 0xD4);

    DisplayMode result = {
        .mode = (int)mode.derived.mode,
        .width = (int)mode.derived.width,
        .height = (int)mode.derived.height,
        .depth = (int)mode.derived.depth,
        .freq = (int)mode.derived.freq,
        .density = mode.derived.density,
    };
    return result;
}

int getCurrentDisplayModeIndex(CGDirectDisplayID display)
{
    int modeNum = 0;
    CGSGetCurrentDisplayMode(display, &modeNum);
    return modeNum;
}

bool configureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int modeNum)
{
    CGSConfigureDisplayMode(config, display, modeNum);
    return true;
}

bool configureDisplayEnabled(CGDisplayConfigRef config, CGDirectDisplayID display, bool enabled)
{
    return CGSConfigureDisplayEnabled(config, display, enabled) == kCGErrorSuccess;
}
