import SwiftUI

struct AdvancedInfoView: View {
    @EnvironmentObject var ble: DunenBLEManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                title("Advanced Info", "Live controller data")

                GlassCard(glow: true) {
                    VStack(spacing: 12) {
                        row("RPM", "\(ble.telemetry.rpm)")
                        row("Voltage", String(format: "%.1f V", ble.telemetry.voltage))
                        row("Current", String(format: "%.1f A", ble.telemetry.currentA))
                        row("WarningCode", "\(ble.telemetry.warningCode)")
                        row("ErrCode", "\(ble.telemetry.errorCode)")
                    }
                }

                GlassCard {
                    VStack(spacing: 12) {
                        row("Phase Voltage", String(format: "%.2f V", ble.telemetry.phaseVoltage))
                        row("Motor Angle", "\(ble.telemetry.motorAngle)")
                        row("Torque", String(format: "%.2f", ble.telemetry.torque))
                        row("Zero Angle", "\(ble.telemetry.zeroAngle)")
                        row("Motor Temperature", String(format: "%.1f °C", ble.telemetry.motorTemp))
                        row("Controller Temp", String(format: "%.1f °C", ble.telemetry.controllerTemp))
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Speed Calculation")
                            .font(.headline)
                        row("Rear sprocket", "48T")
                        row("Rear wheel", "18 inch")
                        row("Front wheel", "19 inch")
                        row("Drive", "Chain")
                        Text("Speed is calculated from controller data when available. Demo mode generates calculated values inside the app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 112)
        }
    }

    private func title(_ a: String, _ b: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(a).font(.largeTitle.weight(.heavy))
                Text(b).font(.caption).foregroundStyle(.cyan)
            }
            Spacer()
            ConnectionPill()
        }
    }

    private func row(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
    }
}
