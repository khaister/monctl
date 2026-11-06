import ApplicationServices

/// One of `set`'s relative-placement flags, computed from another screen's current bounds
/// rather than a raw pixel origin (§4.2).
enum RelativePlacement {
    case rightOf(String)
    case leftOf(String)
    case above(String)
    case below(String)

    var referenceID: String {
        switch self {
        case let .rightOf(id), let .leftOf(id), let .above(id), let .below(id):
            id
        }
    }
}

/// Resolves a relative-placement flag into a raw `(x,y)` origin, using the referenced screen's
/// *current* live bounds - not any pending change in the same invocation - the same model
/// xrandr's `--left-of`/`--right-of`/etc. use. `targetWidth`/`targetHeight` are the screen being
/// placed's own (possibly about-to-change) dimensions, needed to compute `--left-of`/`--above`.
/// Returns `nil` if the referenced screen isn't currently online.
func resolveRelativeOrigin(
    _ placement: RelativePlacement,
    onlineList: [CGDirectDisplayID],
    targetWidth: Int,
    targetHeight: Int
) -> (x: Int, y: Int)? {
    let refID = convertUUIDtoID(placement.referenceID)
    guard onlineList.contains(refID) else { return nil }

    let bounds = CGDisplayBounds(refID)
    let refX = Int(bounds.origin.x)
    let refY = Int(bounds.origin.y)
    let refWidth = Int(CGDisplayPixelsWide(refID))
    let refHeight = Int(CGDisplayPixelsHigh(refID))

    switch placement {
    case .rightOf:
        return (refX + refWidth, refY)
    case .leftOf:
        return (refX - targetWidth, refY)
    case .above:
        return (refX, refY - targetHeight)
    case .below:
        return (refX, refY + refHeight)
    }
}
