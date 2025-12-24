import Foundation
import CoreGraphics
import IOKit
import IOKit.usb

// Configuration
// Vendor: 2109, Product: 2817
let targetVendorID = 0x2109
let targetProductID = 0x2817

// MARK: - Display Management

func setMirroring(enabled: Bool) {
    var displayCount: UInt32 = 0
    var activeDisplays = [CGDirectDisplayID](repeating: 0, count: 10)
    CGGetOnlineDisplayList(10, &activeDisplays, &displayCount)

    let mainDisplayId = CGMainDisplayID()
    
    var configRef: CGDisplayConfigRef?
    let error = CGBeginDisplayConfiguration(&configRef)
    
    if error != .success {
        print("Error beginning display configuration: \(error)")
        return
    }

    if enabled {
        print("Switching to Mirror Mode")
        for i in 0..<Int(displayCount) {
            let displayId = activeDisplays[i]
            if displayId != mainDisplayId {
                CGConfigureDisplayMirrorOfDisplay(configRef, displayId, mainDisplayId)
            }
        }
    } else {
        print("Switching to Extended Mode (Mirroring Disabled)")
        for i in 0..<Int(displayCount) {
            let displayId = activeDisplays[i]
            if displayId != mainDisplayId {
                CGConfigureDisplayMirrorOfDisplay(configRef, displayId, kCGNullDirectDisplay)
            }
        }
    }
    
    CGCompleteDisplayConfiguration(configRef, .permanently)
}

// MARK: - USB Event Handling

var pendingWorkItem: DispatchWorkItem?

let deviceAddedCallback: @convention(c) (UnsafeMutableRawPointer?, io_iterator_t) -> Void = { (refCon, iterator) in
    var device: io_object_t = 0
    var found = false
    while true {
        device = IOIteratorNext(iterator)
        if device == 0 { break }
        IOObjectRelease(device)
        found = true
    }
    
    if found {
        print("Target USB Device Connected (or present at launch)")
        print("Waiting 15 seconds before switching to Extended Mode...")
        
        pendingWorkItem?.cancel()
        let item = DispatchWorkItem {
            setMirroring(enabled: false)
            pendingWorkItem = nil
        }
        pendingWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: item)
    }
}

let deviceRemovedCallback: @convention(c) (UnsafeMutableRawPointer?, io_iterator_t) -> Void = { (refCon, iterator) in
    var device: io_object_t = 0
    var found = false
    while true {
        device = IOIteratorNext(iterator)
        if device == 0 { break }
        IOObjectRelease(device)
        found = true
    }
    
    if found {
        print("Target USB Device Disconnected")
        
        if let item = pendingWorkItem {
            print("Cancelling pending action")
            item.cancel()
            pendingWorkItem = nil
        }
        
        print("Waiting 15 seconds before switching to Mirror Mode...")
        let item = DispatchWorkItem {
            setMirroring(enabled: true)
            pendingWorkItem = nil
        }
        pendingWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: item)
    }
}

// MARK: - Main Execution

print("Starting Screen Maid (Swift)...")
print("Target: VendorID=0x\(String(format: "%04x", targetVendorID)), ProductID=0x\(String(format: "%04x", targetProductID))")

// Use 0 for kIOMasterPortDefault/kIOMainPortDefault
let masterPort: mach_port_t = 0 

let notifyPort = IONotificationPortCreate(masterPort)
guard let runLoopSource = IONotificationPortGetRunLoopSource(notifyPort)?.takeRetainedValue() else {
    print("Failed to get run loop source")
    exit(1)
}

CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)

func createMatchingDict() -> NSMutableDictionary? {
    // kIOUSBDeviceClassName is "IOUSBDevice"
    guard let matchingDict = IOServiceMatching("IOUSBDevice") as? NSMutableDictionary else {
        return nil
    }
    // Use string keys for dictionary
    matchingDict["idVendor"] = targetVendorID
    matchingDict["idProduct"] = targetProductID
    return matchingDict
}

// Register for device addition
guard let addedDict = createMatchingDict() else {
    print("Failed to create matching dictionary")
    exit(1)
}

var addedIterator: io_iterator_t = 0
let addedResult = IOServiceAddMatchingNotification(
    notifyPort,
    kIOMatchedNotification,
    addedDict,
    deviceAddedCallback,
    nil,
    &addedIterator
)

if addedResult != kIOReturnSuccess {
    print("Failed to register for device addition")
    exit(1)
}
// Arm the callback & check initial state
deviceAddedCallback(nil, addedIterator)

// Register for device removal
guard let removedDict = createMatchingDict() else {
    print("Failed to create matching dictionary")
    exit(1)
}

var removedIterator: io_iterator_t = 0
let removedResult = IOServiceAddMatchingNotification(
    notifyPort,
    kIOTerminatedNotification,
    removedDict,
    deviceRemovedCallback,
    nil,
    &removedIterator
)

if removedResult != kIOReturnSuccess {
    print("Failed to register for device removal")
    exit(1)
}
// Arm the callback
deviceRemovedCallback(nil, removedIterator)

print("Listening for events... Press Ctrl+C to exit.")
CFRunLoopRun()
