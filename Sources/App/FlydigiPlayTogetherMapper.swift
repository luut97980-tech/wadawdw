import SwiftUI
import GameController
import CoreBluetooth
import UIKit

// MARK: - Connection Transport Mode

enum ConnectionTransport: String, Codable, CaseIterable {
    case none = "Chưa kết nối"
    case bluetoothSystem = "Bluetooth iOS (XInput / MFi)"
    case bluetoothBLE = "Bluetooth BLE Trực tiếp (Flashplay / DInput)"
    case wiredUSB = "Cắm dây trực tiếp (USB-C / OTG)"
    case dongle24G = "Đầu thu 2.4GHz USB Dongle"
}

struct DiscoveredBLEDevice: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral
    var name: String
    var rssi: Int
    var isFlydigi: Bool
}

// MARK: - Data Models for Play Together VNG Touch Mapping & Deadzone Studio

struct KeyMappingItem: Identifiable, Codable {
    var id: String
    var label: String
    var actionName: String
    var normalizedX: Double // 0.0 -> 1.0 (Landscape width)
    var normalizedY: Double // 0.0 -> 1.0 (Landscape height)
    var radius: Double
    var isJoystick: Bool
}

struct ControllerProfile: Codable {
    var profileName: String
    var targetGameBundleID: String

    // Left Stick (Di chuyển) Deadzone & Curve Settings
    var leftInnerDeadzone: Double       // 0.00 -> 0.40 (Chống trôi tâm)
    var leftOuterDeadzone: Double       // 0.60 -> 1.00 (Ngưỡng đạt max tốc độ chạy)
    var leftResponseCurve: Double       // 0.50 -> 2.00 (1.0 = Tuyến tính, <1 = Nhạy tâm, >1 = Mượt tâm)
    var leftDragRadius: Double          // 40.0 -> 130.0 pt (Bán kính kéo Joystick ảo)
    var leftCenterOffsetX: Double       // Cân tâm trục X
    var leftCenterOffsetY: Double       // Cân tâm trục Y

    // Right Stick (Xoay Camera) Deadzone & Sensitivity Settings
    var rightInnerDeadzone: Double      // 0.00 -> 0.40
    var rightOuterDeadzone: Double      // 0.60 -> 1.00
    var rightResponseCurve: Double      // 0.50 -> 2.00
    var rightSensitivityX: Double       // 0.30 -> 4.00x (Tốc độ xoay ngang)
    var rightSensitivityY: Double       // 0.30 -> 4.00x (Tốc độ xoay dọc)
    var invertRightY: Bool              // Đảo ngược trục dọc Camera
    var rightCenterOffsetX: Double
    var rightCenterOffsetY: Double

    // Analog Triggers (Cò LT / RT Hall Effect trên Apex 5 & Direwolf) & Turbo
    var triggerDeadzone: Double         // 0.05 -> 0.90 (Điểm nhận cò nhanh Hair-Trigger)
    var enableTurboRT: Bool             // Bật nhấp liên thanh khi giữ cò RT / M1
    var turboCPS: Double                // Tốc độ nhấp liên thanh (5 -> 25 lần/giây)

    var preferredTransport: String
    var mappings: [KeyMappingItem]

    static func defaultPlayTogetherProfile() -> ControllerProfile {
        return ControllerProfile(
            profileName: "Flydigi Apex 5 / Direwolf - Play Together VNG",
            targetGameBundleID: "com.vng.playtogether",
            leftInnerDeadzone: 0.10,
            leftOuterDeadzone: 0.94,
            leftResponseCurve: 1.00,
            leftDragRadius: 78.0,
            leftCenterOffsetX: 0.0,
            leftCenterOffsetY: 0.0,
            rightInnerDeadzone: 0.12,
            rightOuterDeadzone: 0.95,
            rightResponseCurve: 1.15,
            rightSensitivityX: 1.50,
            rightSensitivityY: 1.25,
            invertRightY: false,
            rightCenterOffsetX: 0.0,
            rightCenterOffsetY: 0.0,
            triggerDeadzone: 0.18,
            enableTurboRT: false,
            turboCPS: 12.0,
            preferredTransport: "AUTO",
            mappings: [
                KeyMappingItem(id: "L_STICK", label: "L-Stick", actionName: "Di chuyển 360°", normalizedX: 0.16, normalizedY: 0.72, radius: 78.0, isJoystick: true),
                KeyMappingItem(id: "R_STICK", label: "R-Stick", actionName: "Xoay Camera", normalizedX: 0.62, normalizedY: 0.45, radius: 64.0, isJoystick: true),
                KeyMappingItem(id: "BTN_A", label: "A", actionName: "Nhảy (Jump)", normalizedX: 0.88, normalizedY: 0.78, radius: 30.0, isJoystick: false),
                KeyMappingItem(id: "BTN_B", label: "B", actionName: "Tương tác / Câu cá", normalizedX: 0.78, normalizedY: 0.82, radius: 32.0, isJoystick: false),
                KeyMappingItem(id: "BTN_X", label: "X", actionName: "Dùng công cụ", normalizedX: 0.82, normalizedY: 0.62, radius: 28.0, isJoystick: false),
                KeyMappingItem(id: "BTN_Y", label: "Y", actionName: "Mở Balo", normalizedX: 0.93, normalizedY: 0.48, radius: 26.0, isJoystick: false),
                KeyMappingItem(id: "BTN_RT", label: "RT", actionName: "Giật cần câu nhanh", normalizedX: 0.78, normalizedY: 0.82, radius: 24.0, isJoystick: false),
                KeyMappingItem(id: "BTN_LT", label: "LT", actionName: "Gọi Xe / Ván trượt", normalizedX: 0.72, normalizedY: 0.68, radius: 26.0, isJoystick: false),
                KeyMappingItem(id: "BTN_LB", label: "LB", actionName: "Bản đồ (Map)", normalizedX: 0.10, normalizedY: 0.18, radius: 24.0, isJoystick: false),
                KeyMappingItem(id: "BTN_RB", label: "RB", actionName: "Đổi vật phẩm", normalizedX: 0.86, normalizedY: 0.48, radius: 24.0, isJoystick: false),
                KeyMappingItem(id: "BTN_M1", label: "M1", actionName: "Phím lưng M1 (Câu nhanh)", normalizedX: 0.78, normalizedY: 0.82, radius: 22.0, isJoystick: false),
                KeyMappingItem(id: "BTN_M2", label: "M2", actionName: "Phím lưng M2 (Nhảy đôi)", normalizedX: 0.88, normalizedY: 0.78, radius: 22.0, isJoystick: false),
                KeyMappingItem(id: "DPAD_UP", label: "↑", actionName: "Điện thoại", normalizedX: 0.93, normalizedY: 0.28, radius: 24.0, isJoystick: false),
                KeyMappingItem(id: "DPAD_LEFT", label: "←", actionName: "Biểu cảm (Emote)", normalizedX: 0.25, normalizedY: 0.12, radius: 24.0, isJoystick: false),
                KeyMappingItem(id: "DPAD_RIGHT", label: "→", actionName: "Chat nhanh", normalizedX: 0.33, normalizedY: 0.12, radius: 24.0, isJoystick: false),
                KeyMappingItem(id: "DPAD_DOWN", label: "↓", actionName: "Ngồi / Nằm", normalizedX: 0.70, normalizedY: 0.84, radius: 24.0, isJoystick: false)
            ]
        )
    }
}

// MARK: - Multi-Transport Flydigi Connection & Deadzone Processor

final class FlydigiGamepadManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isConnected: Bool = false
    @Published var controllerName: String = "Chưa kết nối tay cầm"
    @Published var activeTransport: ConnectionTransport = .none
    @Published var batteryLevel: Float = -1.0

    // Raw & Processed Stick / Trigger Values (For Real-Time Deadzone Radar)
    @Published var rawLeftStick: CGPoint = .zero
    @Published var rawRightStick: CGPoint = .zero
    @Published var leftStickVector: CGPoint = .zero
    @Published var rightStickVector: CGPoint = .zero
    @Published var leftTriggerValue: Double = 0.0
    @Published var rightTriggerValue: Double = 0.0
    @Published var activeButtons: Set<String> = []
    @Published var profile: ControllerProfile

    // CoreBluetooth BLE Direct Scanning State
    @Published var bleStateText: String = "Đang khởi tạo Bluetooth..."
    @Published var isScanningBLE: Bool = false
    @Published var showAllBLEDevices: Bool = false
    @Published var discoveredDevices: [DiscoveredBLEDevice] = []
    @Published var connectionLog: [String] = []

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private let storageKey = "Flydigi_PlayTogether_Profile_v3"

    private let hidServiceUUID = CBUUID(string: "1812")
    private let batteryServiceUUID = CBUUID(string: "180F")
    private let flydigiServiceUUID1 = CBUUID(string: "FFE0")
    private let flydigiServiceUUID2 = CBUUID(string: "FFF0")

    override init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(ControllerProfile.self, from: data) {
            self.profile = saved
        } else {
            self.profile = ControllerProfile.defaultPlayTogetherProfile()
        }
        super.init()

        if #available(iOS 14.5, *) {
            GCController.shouldMonitorBackgroundEvents = true
        }
        centralManager = CBCentralManager(delegate: self, queue: .main)
        setupAllHardwareObservers()
        appendLog("Sẵn sàng kết nối tay cầm (Bluetooth / BLE / Cáp USB-C OTG / 2.4GHz Dongle) & Tinh chỉnh Deadzone.")
    }

    // MARK: - Mathematical Deadzone, Outer Threshold & Response Curve Engine

    func applyDeadzoneAndCurve(rawX: Double, rawY: Double, isLeftStick: Bool) -> CGPoint {
        let calX = rawX - (isLeftStick ? profile.leftCenterOffsetX : profile.rightCenterOffsetX)
        let calY = rawY - (isLeftStick ? profile.leftCenterOffsetY : profile.rightCenterOffsetY)

        let innerDZ = isLeftStick ? profile.leftInnerDeadzone : profile.rightInnerDeadzone
        let outerDZ = max(isLeftStick ? profile.leftOuterDeadzone : profile.rightOuterDeadzone, innerDZ + 0.05)
        let curve = isLeftStick ? profile.leftResponseCurve : profile.rightResponseCurve

        let mag = sqrt(calX * calX + calY * calY)
        guard mag > innerDZ else { return .zero }

        let normalizedMag = min((mag - innerDZ) / (outerDZ - innerDZ), 1.0)
        let curvedMag = pow(normalizedMag, curve)
        let dirX = calX / mag
        let dirY = calY / mag

        if isLeftStick {
            return CGPoint(x: dirX * curvedMag, y: dirY * curvedMag)
        } else {
            let finalY = profile.invertRightY ? -dirY : dirY
            return CGPoint(
                x: max(min(dirX * curvedMag * profile.rightSensitivityX, 1.0), -1.0),
                y: max(min(finalY * curvedMag * profile.rightSensitivityY, 1.0), -1.0)
            )
        }
    }

    func calibrateStickCenterNow() {
        profile.leftCenterOffsetX = Double(rawLeftStick.x)
        profile.leftCenterOffsetY = Double(rawLeftStick.y)
        profile.rightCenterOffsetX = Double(rawRightStick.x)
        profile.rightCenterOffsetY = Double(rawRightStick.y)
        leftStickVector = .zero
        rightStickVector = .zero
        saveProfile()
        appendLog("Đã cân tâm (Zero Calibration) cho cần L-Stick & R-Stick thành công.")
    }

    func resetZeroCalibration() {
        profile.leftCenterOffsetX = 0.0
        profile.leftCenterOffsetY = 0.0
        profile.rightCenterOffsetX = 0.0
        profile.rightCenterOffsetY = 0.0
        saveProfile()
        appendLog("Đã đặt lại độ lệch tâm về (0.00, 0.00).")
    }

    func updateLeftDragRadius(_ newRadius: Double) {
        profile.leftDragRadius = newRadius
        if let idx = profile.mappings.firstIndex(where: { $0.id == "L_STICK" }) {
            profile.mappings[idx].radius = newRadius
        }
        saveProfile()
    }

    func appendLog(_ msg: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let line = "[\(formatter.string(from: Date()))] \(msg)"
        DispatchQueue.main.async {
            self.connectionLog.insert(line, at: 0)
            if self.connectionLog.count > 25 {
                self.connectionLog.removeLast()
            }
        }
    }

    func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func copyProfileToClipboard() -> Bool {
        guard let data = try? JSONEncoder().encode(profile),
              let jsonString = String(data: data, encoding: .utf8) else {
            return false
        }
        UIPasteboard.general.string = "FLYDIGI_PT_CFG:" + jsonString
        appendLog("Đã sao chép toàn bộ cấu hình nút & Deadzone sang bộ nhớ tạm để áp dụng vào Play Together VNG.")
        return true
    }

    func resetProfile() {
        profile = ControllerProfile.defaultPlayTogetherProfile()
        saveProfile()
        appendLog("Đã khôi phục toàn bộ nút và Deadzone về mặc định.")
    }

    // MARK: - 1. System GameController, Wired USB-C / OTG & 2.4GHz Dongle Observers

    private func setupAllHardwareObservers() {
        let nc = NotificationCenter.default

        nc.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            if let ctrl = note.object as? GCController {
                self?.appendLog("Phát hiện tay cầm kết nối: \(ctrl.vendorName ?? "Flydigi")")
            }
            self?.refreshSystemControllers()
        }

        nc.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            self?.appendLog("Tay cầm GCController đã ngắt kết nối.")
            self?.refreshSystemControllers()
        }

        nc.addObserver(forName: .GCKeyboardDidConnect, object: nil, queue: .main) { [weak self] _ in
            self?.appendLog("Phát hiện cổng USB HID / 2.4GHz Receiver (Keyboard interface).")
            self?.bindUSBKeyboardOrDongle()
        }

        nc.addObserver(forName: .GCMouseDidConnect, object: nil, queue: .main) { [weak self] _ in
            self?.appendLog("Phát hiện cổng USB HID / 2.4GHz Receiver (Pointer interface).")
            self?.bindUSBMouseOrDongle()
        }

        GCController.startWirelessControllerDiscovery {}
        refreshSystemControllers()
        bindUSBKeyboardOrDongle()
        bindUSBMouseOrDongle()
    }

    func triggerSystemWirelessDiscovery() {
        appendLog("Đang quét tay cầm qua hệ thống iOS (XInput / MFi / Cáp USB)...")
        GCController.startWirelessControllerDiscovery { [weak self] in
            self?.appendLog("Hoàn tất phiên quét GCController.")
        }
        refreshSystemControllers()
    }

    func refreshSystemControllers() {
        if let controller = GCController.controllers().first {
            isConnected = true
            let rawName = controller.vendorName ?? "Flydigi Gamepad"
            let category = controller.productCategory.lowercased()

            if rawName.lowercased().contains("2.4") || rawName.lowercased().contains("dongle") || rawName.lowercased().contains("receiver") {
                activeTransport = .dongle24G
            } else if controller.isAttachedToDevice || category.contains("wired") || rawName.lowercased().contains("usb") {
                activeTransport = .wiredUSB
            } else {
                activeTransport = .bluetoothSystem
            }

            controllerName = "\(rawName)"
            if let battery = controller.battery {
                batteryLevel = battery.batteryLevel
            }
            bindGCControllerInput(controller)
            return
        }

        if let ble = connectedPeripheral, ble.state == .connected {
            isConnected = true
            activeTransport = .bluetoothBLE
            controllerName = ble.name ?? "Flydigi BLE Controller"
            return
        }

        isConnected = false
        activeTransport = .none
        controllerName = "Chưa kết nối (Hỗ trợ Bluetooth, BLE, Cáp USB-C/OTG, 2.4G)"
        batteryLevel = -1.0
        rawLeftStick = .zero
        rawRightStick = .zero
        leftStickVector = .zero
        rightStickVector = .zero
        leftTriggerValue = 0.0
        rightTriggerValue = 0.0
        activeButtons.removeAll()
    }

    private func bindGCControllerInput(_ controller: GCController) {
        if let gamepad = controller.extendedGamepad {
            gamepad.valueChangedHandler = { [weak self] pad, _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    let lx = Double(pad.leftThumbstick.xAxis.value)
                    let ly = Double(-pad.leftThumbstick.yAxis.value)
                    self.rawLeftStick = CGPoint(x: lx, y: ly)
                    self.leftStickVector = self.applyDeadzoneAndCurve(rawX: lx, rawY: ly, isLeftStick: true)

                    let rx = Double(pad.rightThumbstick.xAxis.value)
                    let ry = Double(-pad.rightThumbstick.yAxis.value)
                    self.rawRightStick = CGPoint(x: rx, y: ry)
                    self.rightStickVector = self.applyDeadzoneAndCurve(rawX: rx, rawY: ry, isLeftStick: false)

                    let ltVal = Double(pad.leftTrigger.value)
                    let rtVal = Double(pad.rightTrigger.value)
                    self.leftTriggerValue = ltVal
                    self.rightTriggerValue = rtVal

                    var pressed = Set<String>()
                    if pad.buttonA.isPressed { pressed.insert("BTN_A") }
                    if pad.buttonB.isPressed { pressed.insert("BTN_B") }
                    if pad.buttonX.isPressed { pressed.insert("BTN_X") }
                    if pad.buttonY.isPressed { pressed.insert("BTN_Y") }
                    if rtVal >= self.profile.triggerDeadzone || pad.rightTrigger.isPressed { pressed.insert("BTN_RT") }
                    if ltVal >= self.profile.triggerDeadzone || pad.leftTrigger.isPressed { pressed.insert("BTN_LT") }
                    if pad.leftShoulder.isPressed { pressed.insert("BTN_LB") }
                    if pad.rightShoulder.isPressed { pressed.insert("BTN_RB") }
                    if pad.dpad.up.isPressed { pressed.insert("DPAD_UP") }
                    if pad.dpad.left.isPressed { pressed.insert("DPAD_LEFT") }
                    if pad.dpad.right.isPressed { pressed.insert("DPAD_RIGHT") }
                    if pad.dpad.down.isPressed { pressed.insert("DPAD_DOWN") }
                    self.activeButtons = pressed
                }
            }
        } else if let micro = controller.microGamepad {
            micro.valueChangedHandler = { [weak self] pad, _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    let lx = Double(pad.dpad.xAxis.value)
                    let ly = Double(-pad.dpad.yAxis.value)
                    self.rawLeftStick = CGPoint(x: lx, y: ly)
                    self.leftStickVector = self.applyDeadzoneAndCurve(rawX: lx, rawY: ly, isLeftStick: true)
                    var pressed = Set<String>()
                    if pad.buttonA.isPressed { pressed.insert("BTN_A") }
                    if pad.buttonX.isPressed { pressed.insert("BTN_X") }
                    self.activeButtons = pressed
                }
            }
        }
    }

    private func bindUSBKeyboardOrDongle() {
        guard let keyboard = GCKeyboard.coalesced?.keyboardInput else { return }
        if !isConnected {
            isConnected = true
            activeTransport = .dongle24G
            controllerName = "Flydigi USB / 2.4GHz HID Interface"
        }
        keyboard.keyChangedHandler = { [weak self] _, _, keyCode, pressed in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch keyCode {
                case .keyW:
                    self.rawLeftStick.y = pressed ? -1.0 : 0.0
                    self.leftStickVector = self.applyDeadzoneAndCurve(rawX: self.rawLeftStick.x, rawY: self.rawLeftStick.y, isLeftStick: true)
                case .keyS:
                    self.rawLeftStick.y = pressed ? 1.0 : 0.0
                    self.leftStickVector = self.applyDeadzoneAndCurve(rawX: self.rawLeftStick.x, rawY: self.rawLeftStick.y, isLeftStick: true)
                case .keyA:
                    self.rawLeftStick.x = pressed ? -1.0 : 0.0
                    self.leftStickVector = self.applyDeadzoneAndCurve(rawX: self.rawLeftStick.x, rawY: self.rawLeftStick.y, isLeftStick: true)
                case .keyD:
                    self.rawLeftStick.x = pressed ? 1.0 : 0.0
                    self.leftStickVector = self.applyDeadzoneAndCurve(rawX: self.rawLeftStick.x, rawY: self.rawLeftStick.y, isLeftStick: true)
                case .spacebar:
                    if pressed { self.activeButtons.insert("BTN_A") } else { self.activeButtons.remove("BTN_A") }
                case .keyE, .returnOrEnter:
                    if pressed { self.activeButtons.insert("BTN_B") } else { self.activeButtons.remove("BTN_B") }
                case .keyQ:
                    if pressed { self.activeButtons.insert("BTN_X") } else { self.activeButtons.remove("BTN_X") }
                case .tab, .keyI:
                    if pressed { self.activeButtons.insert("BTN_Y") } else { self.activeButtons.remove("BTN_Y") }
                default: break
                }
            }
        }
    }

    private func bindUSBMouseOrDongle() {
        guard let mouse = GCMouse.current?.mouseInput else { return }
        mouse.mouseMovedHandler = { [weak self] _, deltaX, deltaY in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let clampedX = max(min(Double(deltaX) / 15.0, 1.0), -1.0)
                let clampedY = max(min(Double(-deltaY) / 15.0, 1.0), -1.0)
                self.rawRightStick = CGPoint(x: clampedX, y: clampedY)
                self.rightStickVector = self.applyDeadzoneAndCurve(rawX: clampedX, rawY: clampedY, isLeftStick: false)
            }
        }
        mouse.leftButton.pressedChangedHandler = { [weak self] _, _, pressed in
            DispatchQueue.main.async {
                self?.rightTriggerValue = pressed ? 1.0 : 0.0
                if pressed { self?.activeButtons.insert("BTN_RT") } else { self?.activeButtons.remove("BTN_RT") }
            }
        }
    }

    // MARK: - 2. CoreBluetooth BLE Direct Scanner & Connector

    func startBLEScan() {
        guard centralManager.state == .poweredOn else {
            appendLog("Bluetooth chưa bật hoặc chưa cấp quyền Bluetooth cho ứng dụng.")
            return
        }
        discoveredDevices.removeAll()
        isScanningBLE = true
        appendLog("Đang quét trực tiếp thiết bị Bluetooth BLE (Apex 5 / Direwolf)...")

        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        let connectedHIDs = centralManager.retrieveConnectedPeripherals(withServices: [hidServiceUUID, flydigiServiceUUID1, flydigiServiceUUID2])
        for p in connectedHIDs {
            addOrUpdateDiscoveredPeripheral(p, rssi: -45)
        }
    }

    func stopBLEScan() {
        centralManager.stopScan()
        isScanningBLE = false
        appendLog("Đã dừng quét Bluetooth BLE.")
    }

    func connectToBLEDevice(_ device: DiscoveredBLEDevice) {
        stopBLEScan()
        appendLog("Đang kết nối BLE tới: \(device.name)...")
        connectedPeripheral = device.peripheral
        connectedPeripheral?.delegate = self
        centralManager.connect(device.peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
    }

    func disconnectBLE() {
        if let p = connectedPeripheral {
            centralManager.cancelPeripheralConnection(p)
            connectedPeripheral = nil
            refreshSystemControllers()
        }
    }

    private func addOrUpdateDiscoveredPeripheral(_ peripheral: CBPeripheral, rssi: Int) {
        let rawName = peripheral.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lower = rawName.lowercased()
        let isFlydigiMatch = lower.contains("flydigi") || lower.contains("apex") || lower.contains("direwolf") || lower.contains("feizhi") || lower.contains("vader") || lower.contains("xbox") || lower.contains("gamepad") || lower.contains("controller")

        if !showAllBLEDevices && rawName.isEmpty {
            return
        }

        let displayName = rawName.isEmpty ? "Thiết bị BLE (\(peripheral.identifier.uuidString.prefix(6)))" : rawName
        if let idx = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredDevices[idx].name = displayName
            discoveredDevices[idx].rssi = rssi
            discoveredDevices[idx].isFlydigi = isFlydigiMatch
        } else {
            discoveredDevices.append(
                DiscoveredBLEDevice(
                    id: peripheral.identifier,
                    peripheral: peripheral,
                    name: displayName,
                    rssi: rssi,
                    isFlydigi: isFlydigiMatch
                )
            )
            discoveredDevices.sort { ($0.isFlydigi ? 0 : 1) < ($1.isFlydigi ? 0 : 1) }
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            bleStateText = "Bluetooth Sẵn sàng"
            startBLEScan()
        case .poweredOff:
            bleStateText = "Bluetooth đang TẮT"
        case .unauthorized:
            bleStateText = "Chưa cấp quyền Bluetooth"
        case .unsupported:
            bleStateText = "Thiết bị không hỗ trợ BLE"
        default:
            bleStateText = "Đang kiểm tra Bluetooth..."
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        addOrUpdateDiscoveredPeripheral(peripheral, rssi: RSSI.intValue)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        activeTransport = .bluetoothBLE
        controllerName = peripheral.name ?? "Flydigi BLE Controller"
        appendLog("Kết nối Bluetooth BLE thành công: \(controllerName)")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        appendLog("Lỗi kết nối BLE: \(error?.localizedDescription ?? "Không xác định")")
        refreshSystemControllers()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        appendLog("Đã ngắt kết nối BLE: \(peripheral.name ?? "Thiết bị")")
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
        }
        refreshSystemControllers()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }
        for ch in chars {
            if ch.properties.contains(.notify) || ch.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: ch)
            }
            if ch.properties.contains(.read) {
                peripheral.readValue(for: ch)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, !data.isEmpty else { return }
        let bytes = [UInt8](data)

        if characteristic.uuid == CBUUID(string: "2A19"), let first = bytes.first {
            batteryLevel = Float(min(Int(first), 100)) / 100.0
            return
        }

        parseFlydigiRawHIDReport(bytes)
    }

    private func parseFlydigiRawHIDReport(_ bytes: [UInt8]) {
        guard bytes.count >= 6 else { return }

        let offset = (bytes[0] == 0x01 || bytes[0] == 0xA1 || bytes[0] == 0xFE) && bytes.count >= 8 ? 1 : 0
        let rawLX = max(min((Double(bytes[offset]) - 128.0) / 127.0, 1.0), -1.0)
        let rawLY = max(min((Double(bytes[offset + 1]) - 128.0) / 127.0, 1.0), -1.0)
        let rawRX = max(min((Double(bytes[offset + 2]) - 128.0) / 127.0, 1.0), -1.0)
        let rawRY = max(min((Double(bytes[offset + 3]) - 128.0) / 127.0, 1.0), -1.0)

        rawLeftStick = CGPoint(x: rawLX, y: rawLY)
        rawRightStick = CGPoint(x: rawRX, y: rawRY)
        leftStickVector = applyDeadzoneAndCurve(rawX: rawLX, rawY: rawLY, isLeftStick: true)
        rightStickVector = applyDeadzoneAndCurve(rawX: rawRX, rawY: rawRY, isLeftStick: false)

        let btnByte1 = bytes[offset + 4]
        let btnByte2 = bytes.count > (offset + 5) ? bytes[offset + 5] : 0
        let extraByte = bytes.count > (offset + 6) ? bytes[offset + 6] : 0

        // Đọc cò Analog LT/RT nếu có ở byte tiếp theo
        if bytes.count > (offset + 7) {
            leftTriggerValue = Double(bytes[offset + 6]) / 255.0
            rightTriggerValue = Double(bytes[offset + 7]) / 255.0
        } else {
            leftTriggerValue = (btnByte2 & 0x01) != 0 ? 1.0 : 0.0
            rightTriggerValue = (btnByte2 & 0x02) != 0 ? 1.0 : 0.0
        }

        var pressed = Set<String>()
        if (btnByte1 & 0x01) != 0 { pressed.insert("BTN_A") }
        if (btnByte1 & 0x02) != 0 { pressed.insert("BTN_B") }
        if (btnByte1 & 0x04) != 0 || (btnByte1 & 0x08) != 0 { pressed.insert("BTN_X") }
        if (btnByte1 & 0x10) != 0 { pressed.insert("BTN_Y") }
        if (btnByte1 & 0x40) != 0 { pressed.insert("BTN_LB") }
        if (btnByte1 & 0x80) != 0 { pressed.insert("BTN_RB") }

        if leftTriggerValue >= profile.triggerDeadzone || (btnByte2 & 0x01) != 0 { pressed.insert("BTN_LT") }
        if rightTriggerValue >= profile.triggerDeadzone || (btnByte2 & 0x02) != 0 { pressed.insert("BTN_RT") }
        if (btnByte2 & 0x10) != 0 || (extraByte & 0x01) != 0 { pressed.insert("BTN_M1") }
        if (btnByte2 & 0x20) != 0 || (extraByte & 0x02) != 0 { pressed.insert("BTN_M2") }

        let hat = btnByte2 & 0x0F
        if hat == 0 || hat == 1 || hat == 7 { pressed.insert("DPAD_UP") }
        if hat == 1 || hat == 2 || hat == 3 { pressed.insert("DPAD_RIGHT") }
        if hat == 3 || hat == 4 || hat == 5 { pressed.insert("DPAD_DOWN") }
        if hat == 5 || hat == 6 || hat == 7 { pressed.insert("DPAD_LEFT") }

        activeButtons = pressed
    }
}

// MARK: - Main User Interface

@main
struct FlydigiPlayTogetherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var manager = FlydigiGamepadManager()
    @State private var showConnectionHub = false
    @State private var showDeadzoneStudio = false
    @State private var showCopyToast = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.13, blue: 0.22), Color(red: 0.04, green: 0.07, blue: 0.13)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack {
                    HStack {
                        statusHeaderButton
                        Spacer()
                        controlToolbar
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    Spacer()
                }
                .zIndex(10)

                ForEach($manager.profile.mappings) { $item in
                    DraggableMappingNode(
                        item: $item,
                        canvasSize: geo.size,
                        isPressed: manager.activeButtons.contains(item.id),
                        stickVector: item.id == "L_STICK" ? manager.leftStickVector : (item.id == "R_STICK" ? manager.rightStickVector : .zero),
                        innerDeadzoneRatio: item.id == "L_STICK" ? manager.profile.leftInnerDeadzone : manager.profile.rightInnerDeadzone
                    ) {
                        manager.saveProfile()
                    }
                }

                if showCopyToast {
                    VStack {
                        Spacer()
                        Text("Đã sao chép vị trí nút & cấu hình Deadzone! Mở Play Together VNG để tự động áp dụng.")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color.green.opacity(0.92))
                            .cornerRadius(12)
                            .padding(.bottom, 24)
                    }
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
        }
        .sheet(isPresented: $showConnectionHub) {
            ConnectionHubSheetView(manager: manager)
        }
        .sheet(isPresented: $showDeadzoneStudio) {
            DeadzoneStudioSheetView(manager: manager)
        }
    }

    private var statusHeaderButton: some View {
        Button {
            showConnectionHub = true
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(manager.isConnected ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(manager.controllerName)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Text(manager.activeTransport.rawValue)
                        .font(.system(size: 10))
                        .foregroundColor(.cyan)
                }
                if manager.batteryLevel >= 0 {
                    Text("\(Int(manager.batteryLevel * 100))%")
                        .font(.caption2.bold())
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.68))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(manager.isConnected ? Color.green.opacity(0.7) : Color.orange.opacity(0.8), lineWidth: 1.2)
            )
        }
    }

    private var controlToolbar: some View {
        HStack(spacing: 8) {
            Button {
                showConnectionHub = true
            } label: {
                Label("Kết nối Tay cầm", systemImage: "gamecontroller.fill")
                    .font(.caption.bold())
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.orange)
                    .foregroundColor(.black)
                    .cornerRadius(16)
            }

            Button {
                showDeadzoneStudio = true
            } label: {
                Label("Chỉnh Deadzone & Độ nhạy", systemImage: "dial.high.fill")
                    .font(.caption.bold())
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }

            Button {
                if manager.copyProfileToClipboard() {
                    withAnimation { showCopyToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { showCopyToast = false }
                    }
                }
            } label: {
                Label("Đồng bộ sang Game", systemImage: "doc.on.doc.fill")
                    .font(.caption.bold())
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
        }
    }
}

// MARK: - Live Deadzone, Analog Curve & Trigger Tuning Studio Sheet

struct DeadzoneStudioSheetView: View {
    @ObservedObject var manager: FlydigiGamepadManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                // 1. Bảng Radar Trực Quan 2 Cần Analog & Cò LT/RT theo thời gian thực
                Section(header: Text("1. Kiểm tra trực tiếp Cần Analog & Cò bấm (Live Radar)")) {
                    VStack(spacing: 12) {
                        HStack {
                            Circle()
                                .fill(manager.isConnected ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(manager.isConnected ? "Đang nhận tín hiệu trực tiếp từ \(manager.controllerName)" : "Hãy kết nối tay cầm để xem chấm tâm di chuyển khi gạt cần")
                                .font(.caption.bold())
                                .foregroundColor(manager.isConnected ? .green : .orange)
                            Spacer()
                        }

                        HStack(spacing: 24) {
                            // Radar L-Stick
                            AnalogStickRadarView(
                                title: "Cần Trái (L-Stick)",
                                rawPoint: manager.rawLeftStick,
                                processedPoint: manager.leftStickVector,
                                innerDeadzone: manager.profile.leftInnerDeadzone,
                                outerDeadzone: manager.profile.leftOuterDeadzone
                            )

                            // Radar R-Stick
                            AnalogStickRadarView(
                                title: "Cần Phải (R-Stick)",
                                rawPoint: manager.rawRightStick,
                                processedPoint: manager.rightStickVector,
                                innerDeadzone: manager.profile.rightInnerDeadzone,
                                outerDeadzone: manager.profile.rightOuterDeadzone
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)

                        // Thanh đo hành trình cò LT & RT
                        HStack(spacing: 16) {
                            TriggerBarView(label: "Cò Trái (LT)", value: manager.leftTriggerValue, deadzone: manager.profile.triggerDeadzone)
                            TriggerBarView(label: "Cò Phải (RT)", value: manager.rightTriggerValue, deadzone: manager.profile.triggerDeadzone)
                        }

                        // Nút Cân Tâm (Zero Calibration)
                        HStack(spacing: 12) {
                            Button {
                                manager.calibrateStickCenterNow()
                            } label: {
                                Label("⚖️ Cân tâm chống trôi (Khi thả tay)", systemImage: "scope")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.teal)

                            Button("Xóa lệch tâm") {
                                manager.resetZeroCalibration()
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }
                }

                // 2. Chỉnh Deadzone & Đường cong Cần Trái (L-Stick - Di chuyển Play Together)
                Section(header: Text("2. Cần gạt Trái (L-Stick - Di chuyển nhân vật 360°)")) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Vùng chết tâm (Inner Deadzone)")
                            Spacer()
                            Text("\(Int(manager.profile.leftInnerDeadzone * 100))% (\(String(format: "%.2f", manager.profile.leftInnerDeadzone)))")
                                .font(.caption.bold())
                                .foregroundColor(.red)
                        }
                        Slider(value: $manager.profile.leftInnerDeadzone, in: 0.00...0.40, step: 0.01) { _ in
                            manager.saveProfile()
                        }
                        Text("Tăng nếu buông tay mà nhân vật vẫn tự trôi; giảm nếu muốn gạt nhẹ là đi ngay.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Ngưỡng tốc độ tối đa (Outer Deadzone)")
                            Spacer()
                            Text("\(Int(manager.profile.leftOuterDeadzone * 100))%")
                                .font(.caption.bold())
                                .foregroundColor(.green)
                        }
                        Slider(value: $manager.profile.leftOuterDeadzone, in: 0.60...1.00, step: 0.01) { _ in
                            manager.saveProfile()
                        }
                        Text("Giảm xuống ~80–90% giúp nhân vật chạy tốc độ tối đa sớm hơn mà không cần đẩy kịch cần.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Độ nhạy đường cong (Response Curve)")
                            Spacer()
                            Text(curveDescription(manager.profile.leftResponseCurve))
                                .font(.caption.bold())
                                .foregroundColor(.cyan)
                        }
                        Slider(value: $manager.profile.leftResponseCurve, in: 0.50...2.00, step: 0.05) { _ in
                            manager.saveProfile()
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Bán kính kéo Joystick ảo trong Game")
                            Spacer()
                            Text("\(Int(manager.profile.leftDragRadius)) pt")
                                .font(.caption.bold())
                        }
                        Slider(
                            value: Binding(
                                get: { manager.profile.leftDragRadius },
                                set: { manager.updateLeftDragRadius($0) }
                            ),
                            in: 40.0...130.0,
                            step: 2.0
                        )
                    }
                }

                // 3. Chỉnh Deadzone & Tốc độ Xoay Camera Cần Phải (R-Stick)
                Section(header: Text("3. Cần gạt Phải (R-Stick - Xoay góc nhìn Camera)")) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Vùng chết tâm Camera (Right Deadzone)")
                            Spacer()
                            Text("\(Int(manager.profile.rightInnerDeadzone * 100))%")
                                .font(.caption.bold())
                                .foregroundColor(.red)
                        }
                        Slider(value: $manager.profile.rightInnerDeadzone, in: 0.00...0.40, step: 0.01) { _ in
                            manager.saveProfile()
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Tốc độ xoay Ngang (Trục X)")
                            Spacer()
                            Text("\(String(format: "%.2f", manager.profile.rightSensitivityX))x")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                        }
                        Slider(value: $manager.profile.rightSensitivityX, in: 0.30...4.00, step: 0.05) { _ in
                            manager.saveProfile()
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Tốc độ xoay Dọc (Trục Y)")
                            Spacer()
                            Text("\(String(format: "%.2f", manager.profile.rightSensitivityY))x")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                        }
                        Slider(value: $manager.profile.rightSensitivityY, in: 0.30...4.00, step: 0.05) { _ in
                            manager.saveProfile()
                        }
                    }

                    Toggle("Đảo ngược trục dọc Camera (Invert Y-Axis)", isOn: $manager.profile.invertRightY)
                        .onChange(of: manager.profile.invertRightY) { _ in
                            manager.saveProfile()
                        }
                }

                // 4. Chỉnh Cò bấm Hall Effect (LT / RT) & Liên thanh (Turbo)
                Section(header: Text("4. Cò bấm LT / RT (Hall Effect) & Nhấp Liên Thanh (Turbo)")) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Điểm nhận cò nhanh (Trigger Deadzone)")
                            Spacer()
                            Text("\(Int(manager.profile.triggerDeadzone * 100))%")
                                .font(.caption.bold())
                                .foregroundColor(.yellow)
                        }
                        Slider(value: $manager.profile.triggerDeadzone, in: 0.05...0.90, step: 0.01) { _ in
                            manager.saveProfile()
                        }
                        Text("Đặt ở 10–20% để biến cò RT thành cò nhạy (Hair-Trigger) giúp giật cần câu tức thì.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Toggle("Bật Liên thanh (Turbo) khi giữ cò RT / M1", isOn: $manager.profile.enableTurboRT)
                        .onChange(of: manager.profile.enableTurboRT) { _ in
                            manager.saveProfile()
                        }

                    if manager.profile.enableTurboRT {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Tốc độ nhấp liên thanh (Turbo Speed)")
                                Spacer()
                                Text("\(Int(manager.profile.turboCPS)) lần/giây")
                                    .font(.caption.bold())
                                    .foregroundColor(.green)
                            }
                            Slider(value: $manager.profile.turboCPS, in: 5.0...25.0, step: 1.0) { _ in
                                manager.saveProfile()
                            }
                        }
                    }
                }

                // 5. Khôi phục mặc định
                Section {
                    Button("Khôi phục toàn bộ Deadzone & Vị trí nút về mặc định", role: .destructive) {
                        manager.resetProfile()
                    }
                }
            }
            .navigationTitle("Chỉnh Deadzone & Độ nhạy")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu & Đóng") {
                        manager.saveProfile()
                        dismiss()
                    }
                }
            }
        }
    }

    private func curveDescription(_ val: Double) -> String {
        if abs(val - 1.0) < 0.06 { return "1.00 (Tuyến tính chuẩn)" }
        if val < 1.0 { return "\(String(format: "%.2f", val)) (Nhạy tâm / Phản xạ nhanh)" }
        return "\(String(format: "%.2f", val)) (Mượt tâm / Đi bộ chính xác)"
    }
}

// MARK: - Visual Radar Component for Deadzone Inspection

struct AnalogStickRadarView: View {
    let title: String
    let rawPoint: CGPoint
    let processedPoint: CGPoint
    let innerDeadzone: Double
    let outerDeadzone: Double

    private let radarSize: CGFloat = 116.0

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.bold())

            ZStack {
                // Background circle
                Circle()
                    .fill(Color.black.opacity(0.75))
                    .frame(width: radarSize, height: radarSize)

                // Outer Deadzone Ring (Green)
                Circle()
                    .strokeBorder(Color.green.opacity(0.65), lineWidth: 1.5)
                    .frame(
                        width: radarSize * CGFloat(outerDeadzone),
                        height: radarSize * CGFloat(outerDeadzone)
                    )

                // Inner Deadzone Ring (Red Dashed)
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .foregroundColor(.red)
                    .background(Circle().fill(Color.red.opacity(0.18)))
                    .frame(
                        width: radarSize * CGFloat(innerDeadzone),
                        height: radarSize * CGFloat(innerDeadzone)
                    )

                // Crosshair axes
                Path { path in
                    path.move(to: CGPoint(x: radarSize / 2, y: 0))
                    path.addLine(to: CGPoint(x: radarSize / 2, y: radarSize))
                    path.move(to: CGPoint(x: 0, y: radarSize / 2))
                    path.addLine(to: CGPoint(x: radarSize, y: radarSize / 2))
                }
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .frame(width: radarSize, height: radarSize)

                // Raw hardware stick position (Gray dot)
                Circle()
                    .fill(Color.gray.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .offset(
                        x: rawPoint.x * (radarSize / 2 - 6),
                        y: rawPoint.y * (radarSize / 2 - 6)
                    )

                // Processed output position after Deadzone & Curve (Cyan dot)
                Circle()
                    .fill(processedPoint == .zero ? Color.red : Color.cyan)
                    .frame(width: 12, height: 12)
                    .offset(
                        x: processedPoint.x * (radarSize / 2 - 6),
                        y: processedPoint.y * (radarSize / 2 - 6)
                    )
            }

            Text(String(format: "Raw: %.2f, %.2f", rawPoint.x, rawPoint.y))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
            Text(String(format: "Out: %.2f, %.2f", processedPoint.x, processedPoint.y))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
        }
    }
}

struct TriggerBarView: View {
    let label: String
    let value: Double
    let deadzone: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.caption2.bold())
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(value >= deadzone ? .green : .secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.25))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(value >= deadzone ? Color.green : Color.orange)
                        .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)))
                    // Vạch ngưỡng Deadzone của cò
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2, height: geo.size.height)
                        .offset(x: geo.size.width * CGFloat(deadzone))
                }
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Multi-Transport Connection Hub Sheet

struct ConnectionHubSheetView: View {
    @ObservedObject var manager: FlydigiGamepadManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Trạng thái kết nối hiện tại")) {
                    HStack {
                        Image(systemName: manager.isConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(manager.isConnected ? .green : .orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(manager.controllerName)
                                .font(.headline)
                            Text("Cổng đang dùng: \(manager.activeTransport.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if manager.activeTransport == .bluetoothBLE {
                            Button("Ngắt BLE") {
                                manager.disconnectBLE()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }
                }

                Section(header: Text("1. Quét Bluetooth trực tiếp (BLE / Flashplay / DInput)")) {
                    HStack {
                        Text(manager.bleStateText)
                            .font(.subheadline)
                        Spacer()
                        Button(manager.isScanningBLE ? "Đang quét..." : "Quét lại BLE") {
                            manager.startBLEScan()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Toggle("Hiện tất cả thiết bị Bluetooth xung quanh", isOn: $manager.showAllBLEDevices)
                        .font(.caption)
                        .onChange(of: manager.showAllBLEDevices) { _ in
                            manager.startBLEScan()
                        }

                    if manager.discoveredDevices.isEmpty {
                        Text("Bật nguồn Flydigi Apex 5 hoặc Direwolf. Nếu chưa thấy, hãy bấm 'Quét lại BLE' hoặc bật 'Hiện tất cả thiết bị Bluetooth'.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(manager.discoveredDevices) { dev in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(dev.name)
                                            .font(.subheadline.bold())
                                        if dev.isFlydigi {
                                            Text("Flydigi")
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.cyan.opacity(0.25))
                                                .cornerRadius(6)
                                        }
                                    }
                                    Text("Tín hiệu RSSI: \(dev.rssi) dBm")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Kết nối") {
                                    manager.connectToBLEDevice(dev)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                            }
                        }
                    }
                }

                Section(header: Text("2. Cắm dây (USB-C / OTG) & Đầu thu 2.4GHz Dongle")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• Cắm dây trực tiếp: Dùng cáp USB-C sang USB-C (hoặc cáp OTG Lightning) nối từ tay cầm Flydigi vào điện thoại. Chuyển tay cầm sang chế độ USB / XInput.")
                            .font(.caption)
                        Text("• Đầu thu 2.4GHz (USB Dongle): Cắm đầu thu 2.4GHz của Apex 5 / Direwolf vào cổng chuyển OTG/Hub USB-C trên máy, gạt công tắc tay cầm sang nấc 2.4G.")
                            .font(.caption)
                    }
                    Button {
                        manager.triggerSystemWirelessDiscovery()
                    } label: {
                        Label("Kiểm tra & Nhận diện cổng USB / OTG / 2.4G ngay", systemImage: "cable.connector.horizontal")
                    }
                }

                Section(header: Text("3. Bluetooth hệ thống iOS (Chế độ XInput / iOS MFi)")) {
                    Text("Trên Flydigi Direwolf: giữ Fn + B (đèn xanh dương) hoặc gạt sang chế độ iOS. Trên Flydigi Apex 5: chọn chế độ iOS / XInput trên màn hình tay cầm, sau đó ghép đôi trong Cài đặt Bluetooth.")
                        .font(.caption)
                    HStack {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Mở Cài đặt Bluetooth", systemImage: "gear")
                        }
                        Spacer()
                        Button("Làm mới kết nối") {
                            manager.triggerSystemWirelessDiscovery()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Section(header: Text("Nhật ký cổng kết nối")) {
                    ForEach(manager.connectionLog, id: \.self) { logLine in
                        Text(logLine)
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
            }
            .navigationTitle("Trung tâm Kết nối Tay cầm")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }
                }
            }
        }
    }
}

struct DraggableMappingNode: View {
    @Binding var item: KeyMappingItem
    let canvasSize: CGSize
    let isPressed: Bool
    let stickVector: CGPoint
    let innerDeadzoneRatio: Double
    let onDragEnded: () -> Void

    var body: some View {
        let posX = item.normalizedX * max(canvasSize.width, 1)
        let posY = item.normalizedY * max(canvasSize.height, 1)

        ZStack {
            if item.isJoystick {
                Circle()
                    .strokeBorder(Color.cyan.opacity(0.85), lineWidth: 2.5)
                    .background(Circle().fill(Color.cyan.opacity(0.14)))
                    .frame(width: item.radius * 2, height: item.radius * 2)

                // Vòng tròn hiển thị trực tiếp vùng chết (Inner Deadzone) ngay trên tâm Joystick
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
                    .foregroundColor(.red.opacity(0.85))
                    .frame(
                        width: item.radius * 2 * CGFloat(innerDeadzoneRatio),
                        height: item.radius * 2 * CGFloat(innerDeadzoneRatio)
                    )

                Circle()
                    .fill(Color.cyan)
                    .frame(width: 28, height: 28)
                    .offset(
                        x: stickVector.x * (item.radius - 14),
                        y: stickVector.y * (item.radius - 14)
                    )

                VStack(spacing: 2) {
                    Text(item.label)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Text(item.actionName)
                        .font(.system(size: 9))
                        .foregroundColor(.cyan)
                }
            } else {
                VStack(spacing: 2) {
                    ZStack {
                        Circle()
                            .fill(isPressed ? Color.green : Color.black.opacity(0.65))
                            .frame(width: item.radius * 2, height: item.radius * 2)
                            .overlay(
                                Circle()
                                    .stroke(isPressed ? Color.white : Color.yellow.opacity(0.85), lineWidth: 2)
                            )
                        Text(item.label)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.white)
                    }
                    Text(item.actionName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 4)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                }
            }
        }
        .position(x: posX, y: posY)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let clampedX = min(max(value.location.x / max(canvasSize.width, 1), 0.04), 0.96)
                    let clampedY = min(max(value.location.y / max(canvasSize.height, 1), 0.06), 0.94)
                    item.normalizedX = clampedX
                    item.normalizedY = clampedY
                }
                .onEnded { _ in
                    onDragEnded()
                }
        )
    }
}
