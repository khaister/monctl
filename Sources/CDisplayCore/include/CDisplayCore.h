#ifndef CDisplayCore_h
#define CDisplayCore_h

#include <ApplicationServices/ApplicationServices.h>
#include <stdbool.h>

typedef struct {
    int mode;
    int width;
    int height;
    int depth;
    int freq;
    float density;
} DisplayMode;

int getDisplayModeCount(CGDirectDisplayID display);
DisplayMode getDisplayMode(CGDirectDisplayID display, int index);
int getCurrentDisplayModeIndex(CGDirectDisplayID display);
bool configureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int modeNum);
bool configureDisplayEnabled(CGDisplayConfigRef config, CGDirectDisplayID display, bool enabled);

bool setRotation(CGDirectDisplayID screenId, const char* screenUUID, int degree);

#endif /* CDisplayCore_h */
