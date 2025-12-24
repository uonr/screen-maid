import Foundation
import CoreGraphics

// Get the list of online displays
var displayCount: UInt32 = 0;
var activeDisplays = [CGDirectDisplayID](repeating: 0, count: 10)
CGGetOnlineDisplayList(10, &activeDisplays, &displayCount)

let mainDisplayId = CGMainDisplayID()
var isMirrored = false

for i in 0..<Int(displayCount) {
    let displayId = activeDisplays[i]
    if displayId != mainDisplayId {
        // Check if this display is mirroring the main display
        if CGDisplayMirrorsDisplay(displayId) == mainDisplayId {
            isMirrored = true
            break
        }
    }
}

var configRef: CGDisplayConfigRef?
CGBeginDisplayConfiguration(&configRef)

if isMirrored {
    // Currently mirroring, switch to extended (cancel mirroring)
    print("Current mode: Mirror -> Switching to Extended")
    for i in 0..<Int(displayCount) {
        let displayId = activeDisplays[i]
        if displayId != mainDisplayId {
            CGConfigureDisplayMirrorOfDisplay(configRef, displayId, kCGNullDirectDisplay)
        }
    }
} else {
    // Currently extended, switch to mirroring (mirror all to main display)
    print("Current mode: Extended -> Switching to Mirror")
    for i in 0..<Int(displayCount) {
        let displayId = activeDisplays[i]
        if displayId != mainDisplayId {
            CGConfigureDisplayMirrorOfDisplay(configRef, displayId, mainDisplayId)
        }
    }
}

CGCompleteDisplayConfiguration(configRef, .permanently)
