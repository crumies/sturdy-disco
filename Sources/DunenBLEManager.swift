import Foundation
import CoreBluetooth
import Combine

struct DiscoveredBLEDevice: Identifiable, Equatable {
    let id: UUID
    let peripheral: CBPeripheral
    let name: String
    let rssi: Int
}

final class DunenBLEManager: NSObject, ObservableObject {
    @Published var connectionStatus = "Bluetooth not ready"
    @Published var discoveredDevices: [DiscoveredBLEDevice] = []
    @Published var savedDevices: [SavedDevice] = []
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var isDemoMode = false
    @Published var connectedName: String?
    @Published var telemetry = Telemetry()
    @Published var history = TelemetryHistory()
    @Published var packetLog: [String] = []
    @Published var developerStatus = "Idle"

    private var central: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var notifyCharacteristic: CBCharacteristic?
    private var writeCharacteristic: CBCharacteristic?
    private weak var tuningStore: TuningStore?
    private weak var settings: AppSettings?
    private var demoTimer: Timer?
    private var demoTick: Double = 0
    private var pollTimer: Timer?

    private let serviceFFE0 = CBUUID(string: "FFE0")
    private let characteristicFFE1 = CBUUID(string: "FFE1")

    override init() {
        super.init()
        loadSavedDevices()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func attachTuningStore(_ store: TuningStore) {
        tuningStore = store
    }

    func attachSettings(_ settings: AppSettings) {
        self.settings = settings
    }

    func setDemoMode(_ enabled: Bool) {
        isDemoMode = enabled
        if enabled {
            isConnected = false
            connectedName = "Demo AP8F"
            connectionStatus = "Demo Mode"
            startDemoTimer()
        } else {
            stopDemoTimer()
            telemetry = Telemetry()
            history = TelemetryHistory()
            connectedName = nil
            connectionStatus = central.state == .poweredOn ? "Bluetooth ready" : connectionStatus
        }
    }

    func startScan() {
        setDemoMode(false)
        guard central.state == .poweredOn else {
            connectionStatus = "Bluetooth is not powered on"
            return
        }
        discoveredDevices.removeAll()
        isScanning = true
        connectionStatus = "Scanning for DUNEN / FFE0..."
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            if self.isScanning {
                self.central.stopScan()
                self.isScanning = false
                self.connectionStatus = self.discoveredDevices.isEmpty ? "No DUNEN devices found" : "Scan finished"
            }
        }
    }

    func connect(to device: DiscoveredBLEDevice) {
        setDemoMode(false)
        central.stopScan()
        isScanning = false
        connectionStatus = "Connecting to \(device.name)..."
        connectedPeripheral = device.peripheral
        connectedPeripheral?.delegate = self
        central.connect(device.peripheral, options: nil)
        rememberDevice(id: device.id, name: device.name, rssi: device.rssi)
    }

    func disconnect() {
        stopPollTimer()
        if let p = connectedPeripheral {
            central.cancelPeripheralConnection(p)
        }
    }

    func readCurrentSettings() {
        guard let p = connectedPeripheral, let c = writeCharacteristic else {
            tuningStore?.statusText = "Not connected to writable FFE1 characteristic"
            return
        }
        tuningStore?.markReading()
        p.writeValue(DunenProtocol.readAllParametersFrame(), for: c, type: .withResponse)

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if self.tuningStore?.didLoadFromController == false {
                self.tuningStore?.isReading = false
                self.tuningStore?.statusText = "Read request sent. Waiting for controller parameter response."
            }
        }
    }

    func writeChangedSettings(_ params: [TuningParameter]) {
        guard let p = connectedPeripheral, let c = writeCharacteristic else {
            tuningStore?.statusText = "Not connected to writable FFE1 characteristic"
            return
        }
        guard tuningStore?.didLoadFromController == true else {
            tuningStore?.statusText = "Read current settings first"
            return
        }

        tuningStore?.isWriting = true
        tuningStore?.saveBackup(reason: "before-write")
        var ids: [Int] = []

        for param in params {
            guard let value = param.pendingValue else { continue }
            p.writeValue(DunenProtocol.writeParameterFrame(id: param.id, value: value), for: c, type: .withResponse)
            ids.append(param.id)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.tuningStore?.confirmWritten(ids: ids)
        }
    }

    func applyDeveloperUpdateInterval() {
        startDemoTimer()
        if isConnected { startPollTimer() }
    }

    private func startPollTimer() {
        stopPollTimer()
        let interval = settings?.updateInterval.rawValue ?? 1.0
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.developerStatus = "Update interval: \(interval)s"
            // keep this conservative: no automatic writes, only read telemetry/known settings request
        }
    }

    private func stopPollTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func startDemoTimer() {
        stopDemoTimer()
        let interval = settings?.updateInterval.rawValue ?? 1.0
        demoTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateDemo()
        }
        demoTimer?.fire()
    }

    private func stopDemoTimer() {
        demoTimer?.invalidate()
        demoTimer = nil
    }

    private func updateDemo() {
        demoTick += settings?.updateInterval.rawValue ?? 1.0
        let wave = sin(demoTick / 4.0)
        let speed = max(0, 42 + 18 * wave + 5 * sin(demoTick / 1.7))
        let rpm = Int(speed * 78 + 700 + 250 * sin(demoTick / 1.3))
        let voltage = 78.4 - min(demoTick / 900.0, 3.0) + 0.25 * sin(demoTick / 2.0)
        let fakeCurrent = max(0, speed / 2.2 + 8 * sin(demoTick / 3.0))

        telemetry.speedKmh = speed
        telemetry.rpm = rpm
        telemetry.voltage = voltage
        telemetry.odometerKm += speed / 3600.0 * (settings?.updateInterval.rawValue ?? 1.0)
        telemetry.warningCode = 0
        telemetry.errorCode = 0
        telemetry.phaseVoltage = voltage / 2.6
        telemetry.motorAngle = Int((demoTick * 180).truncatingRemainder(dividingBy: 3600))
        telemetry.currentA = fakeCurrent
        telemetry.torque = fakeCurrent / 3.2
        telemetry.zeroAngle = 2330
        telemetry.motorTemp = 32 + speed / 7
        telemetry.controllerTemp = 28 + fakeCurrent / 4
        telemetry.packetCount += 1
        telemetry.rawHex = "DE MO \(String(format: "%02X", Int(speed))) \(String(format: "%02X", rpm & 0xff))"
        history.append(telemetry)
    }

    private func addPacket(_ data: Data) {
        let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        telemetry.rawHex = hex
        telemetry.packetCount += 1
        packetLog.insert(hex, at: 0)
        if packetLog.count > 80 { packetLog.removeLast() }

        decodeTelemetry(data)
        telemetry.currentA = max(0, telemetry.torque * 3.0)
        history.append(telemetry)

        let parsed = DunenProtocol.parseParameterValues(from: data)
        if !parsed.isEmpty { tuningStore?.applyReadValues(parsed) }
    }

    private func decodeTelemetry(_ data: Data) {
        let b = [UInt8](data)
        guard b.count >= 8 else { return }

        if b.count >= 12 {
            let vRaw = UInt16(b[2]) | (UInt16(b[3]) << 8)
            let rpmRaw = UInt16(b[4]) | (UInt16(b[5]) << 8)
            let speedRaw = UInt16(b[6]) | (UInt16(b[7]) << 8)
            let voltage = Double(vRaw) / 10.0
            if voltage > 20 && voltage < 120 { telemetry.voltage = voltage }
            let rpm = Int(rpmRaw)
            if rpm >= 0 && rpm < 22000 { telemetry.rpm = rpm }
            let speed = Double(speedRaw) / 10.0
            if speed >= 0 && speed < 190 { telemetry.speedKmh = speed }
        }

        if b.count > 15 {
            telemetry.warningCode = Int(b[8])
            telemetry.errorCode = Int(b[9])
            telemetry.phaseVoltage = Double(UInt16(b[10]) | (UInt16(b[11]) << 8)) / 100.0
            telemetry.motorAngle = Int(UInt16(b[12]) | (UInt16(b[13]) << 8))
            telemetry.motorTemp = Double(Int8(bitPattern: b[14]))
            telemetry.controllerTemp = Double(Int8(bitPattern: b[15]))
        }
    }

    private func shouldShowDevice(name: String, advertisementData: [String: Any]) -> Bool {
        if name.uppercased().contains("DUNEN") { return true }
        if let uuids = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            return uuids.contains(serviceFFE0)
        }
        return false
    }

    private func rememberDevice(id: UUID, name: String, rssi: Int) {
        let saved = SavedDevice(id: id, name: name, lastRSSI: rssi, lastSeen: Date())
        savedDevices.removeAll { $0.id == id }
        savedDevices.insert(saved, at: 0)
        if savedDevices.count > 8 { savedDevices.removeLast() }
        saveSavedDevices()
    }

    private func loadSavedDevices() {
        guard let data = UserDefaults.standard.data(forKey: "savedDevices"),
              let decoded = try? JSONDecoder().decode([SavedDevice].self, from: data) else { return }
        savedDevices = decoded
    }

    private func saveSavedDevices() {
        guard let data = try? JSONEncoder().encode(savedDevices) else { return }
        UserDefaults.standard.set(data, forKey: "savedDevices")
    }
}

extension DunenBLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: connectionStatus = "Bluetooth ready"
        case .poweredOff: connectionStatus = "Bluetooth off"
        case .unauthorized: connectionStatus = "Bluetooth permission denied"
        case .unsupported: connectionStatus = "Bluetooth not supported"
        default: connectionStatus = "Bluetooth state: \(central.state.rawValue)"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        guard shouldShowDevice(name: name, advertisementData: advertisementData) else { return }

        let device = DiscoveredBLEDevice(id: peripheral.identifier, peripheral: peripheral, name: name, rssi: RSSI.intValue)
        if !discoveredDevices.contains(where: { $0.id == device.id }) {
            discoveredDevices.append(device)
        }
        rememberDevice(id: device.id, name: device.name, rssi: device.rssi)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        isDemoMode = false
        connectedName = peripheral.name ?? "DUNEN"
        connectionStatus = "Connected. Discovering services..."
        peripheral.discoverServices([serviceFFE0])
        startPollTimer()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectionStatus = "Failed to connect: \(error?.localizedDescription ?? "unknown error")"
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectedName = nil
        connectedPeripheral = nil
        notifyCharacteristic = nil
        writeCharacteristic = nil
        stopPollTimer()
        connectionStatus = "Disconnected"
    }
}

extension DunenBLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            connectionStatus = "Service discovery failed: \(error.localizedDescription)"
            return
        }
        guard let services = peripheral.services, !services.isEmpty else {
            connectionStatus = "No services found"
            return
        }
        for service in services { peripheral.discoverCharacteristics(nil, for: service) }
        connectionStatus = "Discovering characteristics..."
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            connectionStatus = "Characteristic discovery failed: \(error.localizedDescription)"
            return
        }
        guard let chars = service.characteristics else { return }

        for ch in chars {
            if ch.uuid == characteristicFFE1 || ch.properties.contains(.notify) {
                notifyCharacteristic = ch
                peripheral.setNotifyValue(true, for: ch)
            }
            if ch.properties.contains(.write) || ch.properties.contains(.writeWithoutResponse) {
                writeCharacteristic = ch
            }
            if ch.properties.contains(.read) { peripheral.readValue(for: ch) }
        }

        if writeCharacteristic == nil { writeCharacteristic = notifyCharacteristic }
        connectionStatus = "Ready. Press Read Current Settings before tuning."
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            connectionStatus = "Read/notify error: \(error.localizedDescription)"
            return
        }
        guard let data = characteristic.value else { return }
        addPacket(data)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            tuningStore?.statusText = "Write error: \(error.localizedDescription)"
        } else {
            tuningStore?.statusText = "Controller acknowledged write"
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            connectionStatus = "Notify failed: \(error.localizedDescription)"
            return
        }
        if characteristic.isNotifying { connectionStatus = "Receiving live packets" }
    }
}
