//Hardware-independent unit tests for selectBestMode() (src/Header.h).
//Builds and runs without any real display and without linking MonitorPanel.m
//or any private framework - see src/Makefile's `test` target.
#include <IOKit/graphics/IOGraphicsLib.h>
#include <ApplicationServices/ApplicationServices.h>
#include <mach/mach.h>
#include <math.h>
#include <stdio.h>
#include "../../src/Header.h"

static int testsRun = 0;
static int testsFailed = 0;

#define CHECK(cond, desc) do { \
    testsRun++; \
    if (cond) { \
        printf("PASS: %s\n", desc); \
    } else { \
        testsFailed++; \
        printf("FAIL: %s (%s:%d)\n", desc, __FILE__, __LINE__); \
    } \
} while (0)

static modes_D4 makeMode(int modeNum, int width, int height, int depth, int freq, float density) {
    modes_D4 m = {0};
    m.derived.mode = modeNum;
    m.derived.width = width;
    m.derived.height = height;
    m.derived.depth = depth;
    m.derived.freq = freq;
    m.derived.density = density;
    return m;
}

static void test_exact_match(void) {
    modes_D4 modes[] = {
        makeMode(0, 1920, 1080, 4, 30, 1.0),
        makeMode(1, 1920, 1080, 8, 30, 1.0),
        makeMode(2, 1920, 1080, 8, 60, 1.0),
        makeMode(3, 1920, 1080, 4, 60, 1.0),
        makeMode(4, 1920, 1080, 8, 60, 2.0),
        makeMode(5, 2560, 1440, 8, 60, 1.0),
    };
    int count = sizeof(modes) / sizeof(modes[0]);

    modes_D4* result = selectBestMode(modes, count, 1920, 1080, 60, 8, false);
    CHECK(result != NULL && result->derived.mode == 2, "exact width/height/hz/depth/scaling match picks mode 2");
}

static void test_hz_omitted_picks_highest_hz(void) {
    modes_D4 modes[] = {
        makeMode(0, 1920, 1080, 4, 30, 1.0),
        makeMode(1, 1920, 1080, 8, 30, 1.0),
        makeMode(2, 1920, 1080, 8, 60, 1.0),
        makeMode(3, 1920, 1080, 4, 60, 1.0),
        makeMode(4, 1920, 1080, 8, 60, 2.0),
        makeMode(5, 2560, 1440, 8, 60, 1.0),
    };
    int count = sizeof(modes) / sizeof(modes[0]);

    modes_D4* result = selectBestMode(modes, count, 1920, 1080, 0, 8, false);
    CHECK(result != NULL && result->derived.mode == 2, "hz omitted picks highest hz among depth/scaling matches");
}

static void test_depth_omitted_picks_highest_depth(void) {
    modes_D4 modes[] = {
        makeMode(0, 1920, 1080, 4, 30, 1.0),
        makeMode(1, 1920, 1080, 8, 30, 1.0),
        makeMode(2, 1920, 1080, 8, 60, 1.0),
        makeMode(3, 1920, 1080, 4, 60, 1.0),
        makeMode(4, 1920, 1080, 8, 60, 2.0),
        makeMode(5, 2560, 1440, 8, 60, 1.0),
    };
    int count = sizeof(modes) / sizeof(modes[0]);

    modes_D4* result = selectBestMode(modes, count, 1920, 1080, 60, 0, false);
    CHECK(result != NULL && result->derived.mode == 2, "hz matched, depth omitted picks highest depth among tied hz");
}

static void test_no_match_returns_null(void) {
    modes_D4 modes[] = {
        makeMode(0, 1920, 1080, 8, 30, 1.0),
        makeMode(1, 1920, 1080, 8, 60, 1.0),
    };
    int count = sizeof(modes) / sizeof(modes[0]);

    modes_D4* result = selectBestMode(modes, count, 1920, 1080, 59, 8, false);
    CHECK(result == NULL, "no mode matches requested hz -> NULL");
}

//Inspired by the `set_problematic_profile` case in tests_manual.py (a v1.2 regression
//involving scaling:off at a specific resolution/hz/depth) - not a literal reproduction
//of that historical bug, but it exercises the same class of risk: correctly
//discriminating a scaled vs. unscaled mode at an otherwise-identical resolution/hz/depth.
static void test_scaling_discriminates_identical_modes(void) {
    modes_D4 modes[] = {
        makeMode(0, 756, 1344, 8, 59, 1.0), //unscaled
        makeMode(1, 756, 1344, 8, 59, 2.0), //scaled
    };
    int count = sizeof(modes) / sizeof(modes[0]);

    modes_D4* unscaled = selectBestMode(modes, count, 756, 1344, 59, 8, false);
    CHECK(unscaled != NULL && unscaled->derived.mode == 0, "scaling:off picks the unscaled mode");

    modes_D4* scaled = selectBestMode(modes, count, 756, 1344, 59, 8, true);
    CHECK(scaled != NULL && scaled->derived.mode == 1, "scaling:on picks the scaled mode");
}

int main(void) {
    test_exact_match();
    test_hz_omitted_picks_highest_hz();
    test_depth_omitted_picks_highest_depth();
    test_no_match_returns_null();
    test_scaling_discriminates_identical_modes();

    printf("\n%d/%d tests passed\n", testsRun - testsFailed, testsRun);
    return testsFailed == 0 ? 0 : 1;
}
