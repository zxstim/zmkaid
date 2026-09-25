import CoreBluetooth

/// What the Mac's Bluetooth connection to the keyboard reports.
struct BatteryReport: Equatable {
    /// The Mac has a Bluetooth connection to the keyboard (the left half).
    var connected = false
    var left: Int?
    var right: Int?
}

/// Reads the keyboard's battery levels over Bluetooth, on the connection macOS already has to it.
///
/// ZMK reports the left (central) half in the standard Battery service. With
/// `CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_PROXY` it adds a second Battery service whose level is described
/// as "Peripheral 0": that's the right half. Both notify when they change.
final class BatteryMonitor: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private static let batteryService = CBUUID(string: "180F")
    private static let batteryLevel = CBUUID(string: "2A19")
    private static let userDescription = CBUUID(string: CBUUIDCharacteristicUserDescriptionString)

    private let keyboardName: String
    private let onChange: @MainActor (BatteryReport) -> Void
    private var central: CBCentralManager!
    private var keyboard: CBPeripheral?
    private var retryTimer: Timer?

    /// Which half each Battery Level characteristic belongs to (right = described as "Peripheral …").
    private var isRight: [ObjectIdentifier: Bool] = [:]
    private var rawLevels: [ObjectIdentifier: Int] = [:]

    /// `keyboardName` is ZMK's `CONFIG_ZMK_KEYBOARD_NAME`, which is what the Mac shows in Bluetooth settings.
    init(keyboardName: String, onChange: @escaping @MainActor (BatteryReport) -> Void) {
        self.keyboardName = keyboardName
        self.onChange = onChange
        super.init()
        // Main queue: delegate callbacks arrive on the main thread.
        central = CBCentralManager(delegate: self, queue: nil)
    }

    private func findKeyboard() {
        guard central.state == .poweredOn, keyboard?.state != .connected else { return }
        let match = central.retrieveConnectedPeripherals(withServices: [Self.batteryService]).first {
            $0.name?.localizedCaseInsensitiveContains(keyboardName) == true
        }
        guard let match else { return }
        keyboard = match
        match.delegate = self
        central.connect(match)
    }

    private func publish() {
        var report = BatteryReport(connected: keyboard?.state == .connected)
        // Skip a level until its half is known, so the right half's value never flashes up as the left's.
        for (id, level) in rawLevels {
            guard let right = isRight[id] else { continue }
            if right { report.right = level } else { report.left = level }
        }
        let onChange = onChange
        MainActor.assumeIsolated { onChange(report) }
    }

    // MARK: CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        findKeyboard()
        // The keyboard may connect later (or reconnect after sleep), so keep looking.
        if retryTimer == nil {
            retryTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
                self?.findKeyboard()
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        publish()
        peripheral.discoverServices([Self.batteryService])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isRight.removeAll()
        rawLevels.removeAll()
        publish()
    }

    // MARK: CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] where service.uuid == Self.batteryService {
            peripheral.discoverCharacteristics([Self.batteryLevel], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] where characteristic.uuid == Self.batteryLevel {
            peripheral.discoverDescriptors(for: characteristic)
            peripheral.readValue(for: characteristic)
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        guard let description = characteristic.descriptors?.first(where: { $0.uuid == Self.userDescription }) else {
            isRight[ObjectIdentifier(characteristic)] = false  // no description: the standard (left half) level
            publish()
            return
        }
        peripheral.readValue(for: description)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        guard descriptor.uuid == Self.userDescription, let characteristic = descriptor.characteristic else { return }
        let text = (descriptor.value as? String) ?? (descriptor.value as? Data).flatMap { String(data: $0, encoding: .utf8) }
        isRight[ObjectIdentifier(characteristic)] = text?.hasPrefix("Peripheral") == true
        publish()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.batteryLevel, let byte = characteristic.value?.first else { return }
        rawLevels[ObjectIdentifier(characteristic)] = Int(byte)
        publish()
    }
}
