@testable import CDisplayCore
@testable import monctl
import Testing

/// Ports Tests/Unit/test_mode_selection.c's cases against the Swift `selectBestMode`
/// (moved out of C's src/Header.h during the Swift port - see .claude/plans/swift-port).
private func makeMode(_ mode: Int32, _ width: Int32, _ height: Int32, _ depth: Int32, _ freq: Int32,
                      _ density: Float) -> DisplayMode {
    DisplayMode(mode: mode, width: width, height: height, depth: depth, freq: freq, density: density)
}

@Test func exactMatchPicksMode2() {
    let modes = [
        makeMode(0, 1920, 1080, 4, 30, 1.0),
        makeMode(1, 1920, 1080, 8, 30, 1.0),
        makeMode(2, 1920, 1080, 8, 60, 1.0),
        makeMode(3, 1920, 1080, 4, 60, 1.0),
        makeMode(4, 1920, 1080, 8, 60, 2.0),
        makeMode(5, 2560, 1440, 8, 60, 1.0),
    ]

    let result = selectBestMode(modes, width: 1920, height: 1080, hz: 60, depth: 8, scaled: false)
    #expect(result?.mode == 2)
}

@Test func hzOmittedPicksHighestHz() {
    let modes = [
        makeMode(0, 1920, 1080, 4, 30, 1.0),
        makeMode(1, 1920, 1080, 8, 30, 1.0),
        makeMode(2, 1920, 1080, 8, 60, 1.0),
        makeMode(3, 1920, 1080, 4, 60, 1.0),
        makeMode(4, 1920, 1080, 8, 60, 2.0),
        makeMode(5, 2560, 1440, 8, 60, 1.0),
    ]

    let result = selectBestMode(modes, width: 1920, height: 1080, hz: 0, depth: 8, scaled: false)
    #expect(result?.mode == 2)
}

@Test func depthOmittedPicksHighestDepth() {
    let modes = [
        makeMode(0, 1920, 1080, 4, 30, 1.0),
        makeMode(1, 1920, 1080, 8, 30, 1.0),
        makeMode(2, 1920, 1080, 8, 60, 1.0),
        makeMode(3, 1920, 1080, 4, 60, 1.0),
        makeMode(4, 1920, 1080, 8, 60, 2.0),
        makeMode(5, 2560, 1440, 8, 60, 1.0),
    ]

    let result = selectBestMode(modes, width: 1920, height: 1080, hz: 60, depth: 0, scaled: false)
    #expect(result?.mode == 2)
}

@Test func noMatchReturnsNil() {
    let modes = [
        makeMode(0, 1920, 1080, 8, 30, 1.0),
        makeMode(1, 1920, 1080, 8, 60, 1.0),
    ]

    let result = selectBestMode(modes, width: 1920, height: 1080, hz: 59, depth: 8, scaled: false)
    #expect(result == nil)
}

@Test func scalingDiscriminatesIdenticalModes() {
    let modes = [
        makeMode(0, 756, 1344, 8, 59, 1.0), // unscaled
        makeMode(1, 756, 1344, 8, 59, 2.0), // scaled
    ]

    let unscaled = selectBestMode(modes, width: 756, height: 1344, hz: 59, depth: 8, scaled: false)
    #expect(unscaled?.mode == 0)

    let scaled = selectBestMode(modes, width: 756, height: 1344, hz: 59, depth: 8, scaled: true)
    #expect(scaled?.mode == 1)
}
