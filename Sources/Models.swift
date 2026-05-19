import Foundation
import SwiftUI

enum AppTab: String, CaseIterable {
    case dashboard = "Dash"
    case advanced = "Info"
    case tuning = "Tuning"
    case diagnostics = "Diag"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.bottom.50percent"
        case .advanced: return "list.bullet.rectangle"
        case .tuning: return "slider.horizontal.3"
        case .diagnostics: return "waveform.path.ecg.rectangle"
        case .settings: return "gearshape.fill"
        }
    }
}

enum SpeedUnit: String, CaseIterable, Identifiable {
    case kmh = "KM/H"
    case mph = "MPH"
    var id: String { rawValue }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case dark = "Dark"
    case light = "Light"
    var id: String { rawValue }
}

enum UpdateInterval: Double, CaseIterable, Identifiable {
    case tenth = 0.1
    case quarter = 0.25
    case half = 0.5
    case one = 1.0

    var id: Double { rawValue }
    var label: String {
        switch self {
        case .tenth: return "0.1s"
        case .quarter: return "0.25s"
        case .half: return "0.5s"
        case .one: return "1s"
        }
    }
}

final class AppSettings: ObservableObject {
    @AppStorage("speedUnit") var speedUnitRaw: String = SpeedUnit.kmh.rawValue
    @AppStorage("appearanceMode") var appearanceRaw: String = AppearanceMode.dark.rawValue
    @AppStorage("startupAnimation") var startupAnimation: Bool = true
    @AppStorage("showRawPackets") var showRawPackets: Bool = true
    @AppStorage("expertTuningUnlocked") var expertTuningUnlocked: Bool = false
    @AppStorage("developerUnlocked") var developerUnlocked: Bool = false
    @AppStorage("updateInterval") var updateIntervalRaw: Double = 0.1

    var speedUnit: SpeedUnit {
        get { SpeedUnit(rawValue: speedUnitRaw) ?? .kmh }
        set { speedUnitRaw = newValue.rawValue }
    }

    var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceRaw) ?? .dark }
        set { appearanceRaw = newValue.rawValue }
    }

    var colorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }

    var updateInterval: UpdateInterval {
        get { UpdateInterval(rawValue: updateIntervalRaw) ?? .tenth }
        set { updateIntervalRaw = newValue.rawValue }
    }
}

struct Telemetry: Equatable {
    var speedKmh: Double = 0
    var rpm: Int = 0
    var voltage: Double = 0
    var currentA: Double = 0
    var odometerKm: Double = 0
    var warningCode: Int = 0
    var errorCode: Int = 0
    var phaseVoltage: Double = 0
    var motorAngle: Int = 0
    var torque: Double = 0
    var zeroAngle: Int = 0
    var motorTemp: Double = 0
    var controllerTemp: Double = 0
    var rawHex: String = ""
    var packetCount: Int = 0
    var productModel: String = "DEMCC2416QS035ZFS01"
    var controllerName: String = "DUNEN312"
}

struct TelemetryHistory {
    var speed: [Double] = []
    var rpm: [Double] = []
    var voltage: [Double] = []
    var current: [Double] = []

    mutating func append(_ t: Telemetry) {
        speed.append(t.speedKmh)
        rpm.append(Double(t.rpm))
        voltage.append(t.voltage)
        current.append(t.currentA)
        trim()
    }

    mutating func trim() {
        let maxCount = 70
        if speed.count > maxCount { speed.removeFirst(speed.count - maxCount) }
        if rpm.count > maxCount { rpm.removeFirst(rpm.count - maxCount) }
        if voltage.count > maxCount { voltage.removeFirst(voltage.count - maxCount) }
        if current.count > maxCount { current.removeFirst(current.count - maxCount) }
    }
}

struct SavedDevice: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var lastRSSI: Int
    var lastSeen: Date
}

struct AppToast: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var message: String
    var systemImage: String = "checkmark.circle.fill"
}
