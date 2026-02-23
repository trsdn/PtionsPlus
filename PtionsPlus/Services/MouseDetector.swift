import Foundation
import IOKit
import IOKit.hid

struct ConnectedMouse: Identifiable, Hashable {
    let id: String
    let name: String
    let vendorID: Int
    let productID: Int
    let buttonCount: Int
    let transport: String

    var isLogitech: Bool { vendorID == 0x046D }

    var modelName: String {
        if isLogitech {
            switch productID {
            case 0x4082: return "MX Master 3 (USB)"
            case 0xB023: return "MX Master 3 (Bolt)"
            case 0x4069: return "MX Master 2S (USB)"
            case 0xB019: return "MX Master 2S (Bolt)"
            case 0x4041: return "MX Master (USB)"
            case 0xB012: return "MX Master (Unifying)"
            case 0xC52B: return "Unifying Receiver"
            case 0xC548: return "Bolt Receiver"
            case 0xC53F: return "Bolt Receiver (USB)"
            default: return name.isEmpty ? "Logitech Device" : name
            }
        }
        return name.isEmpty ? "Unknown Mouse" : name
    }
}

final class MouseDetector: ObservableObject {
    @Published var connectedMice: [ConnectedMouse] = []

    func detect() {
        var mice: [ConnectedMouse] = []
        var seen = Set<String>()

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        // Match all pointing devices, mice, and pointers
        let criteria: [[String: Any]] = [
            [kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
             kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Mouse],
            [kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
             kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Pointer],
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, criteria as CFArray)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            NSLog("[Ptions+] No HID devices found")
            return
        }

        NSLog("[Ptions+] Found \(devices.count) HID pointing devices")

        for device in devices {
            let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? ""
            let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
            let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
            let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? "?"

            let buttonCriteria = [kIOHIDElementUsagePageKey: kHIDPage_Button] as CFDictionary
            let elements = IOHIDDeviceCopyMatchingElements(device, buttonCriteria, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] ?? []

            let id = "\(vendorID):\(productID):\(transport)"
            NSLog("[Ptions+] Device: '\(name)' VID:0x\(String(vendorID, radix: 16)) PID:0x\(String(productID, radix: 16)) transport:\(transport) buttons:\(elements.count)")

            guard !seen.contains(id) else { continue }
            seen.insert(id)

            // Skip Apple internal trackpad/mouse (vendor 0x05AC) unless it has many buttons
            if vendorID == 0x05AC && elements.count <= 3 { continue }

            mice.append(ConnectedMouse(
                id: id,
                name: name,
                vendorID: vendorID,
                productID: productID,
                buttonCount: elements.count,
                transport: transport
            ))
        }

        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        connectedMice = mice.sorted { $0.isLogitech && !$1.isLogitech }
    }
}
