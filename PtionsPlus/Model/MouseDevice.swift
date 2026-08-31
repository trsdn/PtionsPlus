import Foundation

/// Stable identity of a physical mouse.
///
/// A serial number makes the identity unique even when two identical mice are
/// connected. Devices that do not report one fall back to vendor plus product,
/// which stays stable across reconnects but is shared by identical hardware.
struct MouseDeviceIdentity: Codable, Hashable, Identifiable {
    var vendorID: Int
    var productID: Int
    var serialNumber: String?

    enum CodingKeys: String, CodingKey {
        case vendorID
        case productID
        case serialNumber
    }

    init(vendorID: Int, productID: Int, serialNumber: String? = nil) {
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = Self.normalizedSerial(serialNumber)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vendorID = try container.decode(Int.self, forKey: .vendorID)
        productID = try container.decode(Int.self, forKey: .productID)
        serialNumber = Self.normalizedSerial(
            try container.decodeIfPresent(String.self, forKey: .serialNumber)
        )
    }

    var id: String {
        let base = String(format: "%04x:%04x", vendorID, productID)
        guard let serialNumber else {
            return base
        }
        return "\(base):\(serialNumber)"
    }

    /// False when identical hardware without a serial number shares this identity.
    var isUniquePerDevice: Bool {
        serialNumber != nil
    }

    private static func normalizedSerial(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

/// A mouse that is currently attached to the system.
struct ConnectedMouseDevice: Identifiable, Equatable {
    let identity: MouseDeviceIdentity
    let name: String

    var id: String { identity.id }
}

/// Mappings that belong to one physical mouse instead of the shared configuration.
struct MouseDeviceConfiguration: Codable, Identifiable {
    var identity: MouseDeviceIdentity
    var name: String
    var model: MouseModel
    var profiles: [AppProfile]
    var globalButtons: [MouseButton]

    enum CodingKeys: String, CodingKey {
        case identity
        case name
        case model
        case profiles
        case globalButtons
    }

    init(
        identity: MouseDeviceIdentity,
        name: String,
        model: MouseModel,
        profiles: [AppProfile],
        globalButtons: [MouseButton] = []
    ) {
        self.identity = identity
        self.name = name
        self.model = model
        self.profiles = profiles
        self.globalButtons = globalButtons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identity = try container.decode(MouseDeviceIdentity.self, forKey: .identity)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Mouse"
        model = try container.decodeIfPresent(MouseModel.self, forKey: .model) ?? .generic5
        profiles = try container.decodeIfPresent([AppProfile].self, forKey: .profiles) ?? []
        globalButtons = try container.decodeIfPresent([MouseButton].self, forKey: .globalButtons) ?? []
    }

    var id: String { identity.id }
}

/// The configuration that applies to one mouse, either its own or the shared one.
struct ResolvedMouseConfiguration {
    let deviceID: String?
    let model: MouseModel
    let profiles: [AppProfile]
    let globalButtons: [MouseButton]

    var isShared: Bool { deviceID == nil }
}
