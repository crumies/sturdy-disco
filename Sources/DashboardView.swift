import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var ble: DunenBLEManager
    @EnvironmentObject var settings: AppSettings
    @State private var fullscreen = false

    var speed: Double {
        settings.speedUnit == .kmh ? ble.telemetry.speedKmh : ble.telemetry.speedKmh * 0.621371
    }

    var odo: String {
        settings.speedUnit == .kmh ? String(format: "%.1f km", ble.telemetry.odometerKm) : String(format: "%.1f mi", ble.telemetry.odometerKm * 0.621371)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                SpeedometerView(speed: speed, unit: settings.speedUnit.rawValue, rpm: ble.telemetry.rpm)
                    .frame(height: 356)

                GlassCard {
                    VStack(spacing: 14) {
                        HStack {
                            metric("Voltage", String(format: "%.1f V", ble.telemetry.voltage))
                            metric("Odometer", odo)
                        }
                        HStack {
                            metric("Current", String(format: "%.1f A", ble.telemetry.currentA))
                            metric("Controller", String(format: "%.0f °C", ble.telemetry.controllerTemp))
                        }
                    }
                }

                GraphPanel(fullscreenButton: {
                    fullscreen = true
                })
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 112)
        }
        .fullScreenCover(isPresented: $fullscreen) {
            FullscreenDashboard()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            AptumLogoImage()
                .frame(width: 150, height: 46)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                ConnectionPill()
                Text(Date.now.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let name = ble.connectedName {
                    Text("Connected to \(name)")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GraphPanel: View {
    @EnvironmentObject var ble: DunenBLEManager
    @EnvironmentObject var settings: AppSettings
    var fullscreenButton: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Live Graphs")
                        .font(.headline)
                    Spacer()
                    Button {
                        fullscreenButton()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .buttonStyle(.bordered)
                    .tint(.cyan)
                }

                graphRow("Speed", value: String(format: "%.0f %@", settings.speedUnit == .kmh ? ble.telemetry.speedKmh : ble.telemetry.speedKmh * 0.621371, settings.speedUnit.rawValue), values: ble.history.speed, max: 120)
                graphRow("RPM", value: "\(ble.telemetry.rpm) rpm", values: ble.history.rpm, max: 9000)
                graphRow("Voltage", value: String(format: "%.1f V", ble.telemetry.voltage), values: ble.history.voltage, max: 90)
                graphRow("Current", value: String(format: "%.1f A", ble.telemetry.currentA), values: ble.history.current, max: 120)
            }
        }
    }

    private func graphRow(_ title: String, value: String, values: [Double], max: Double) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(title == "Speed" ? .cyan : .primary)
            }
            MiniLineGraph(values: values, maxValue: max)
                .frame(height: 46)
        }
    }
}

struct FullscreenDashboard: View {
    @EnvironmentObject var ble: DunenBLEManager
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    var speed: Double {
        settings.speedUnit == .kmh ? ble.telemetry.speedKmh : ble.telemetry.speedKmh * 0.621371
    }

    var odo: String {
        settings.speedUnit == .kmh ? String(format: "%.1f km", ble.telemetry.odometerKm) : String(format: "%.1f mi", ble.telemetry.odometerKm * 0.621371)
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        AptumLogoImage().frame(width: 165, height: 50)
                        Spacer()
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                            .tint(.cyan)
                    }

                    SpeedometerView(speed: speed, unit: settings.speedUnit.rawValue, rpm: ble.telemetry.rpm)
                        .frame(height: 360)

                    GlassCard {
                        HStack {
                            fullMetric("Voltage", String(format: "%.1f V", ble.telemetry.voltage))
                            fullMetric("Odometer", odo)
                            fullMetric("Current", String(format: "%.1f A", ble.telemetry.currentA))
                        }
                    }

                    GraphPanel(fullscreenButton: {})
                }
                .padding(18)
            }
        }
    }

    private func fullMetric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.weight(.bold))
        }
        .frame(maxWidth: .infinity)
    }
}

struct SpeedometerView: View {
    let speed: Double
    let unit: String
    let rpm: Int

    var clamped: Double { min(max(speed, 0), 180) }

    var body: some View {
        GlassCard(glow: true) {
            ZStack {
                ForEach(0..<37) { i in
                    let angle = -135.0 + Double(i) * 270.0 / 36.0
                    Rectangle()
                        .fill(i % 3 == 0 ? .white.opacity(0.75) : .white.opacity(0.25))
                        .frame(width: i % 3 == 0 ? 3 : 1.4, height: i % 3 == 0 ? 22 : 12)
                        .offset(y: -135)
                        .rotationEffect(.degrees(angle))
                }

                Circle().stroke(.cyan.opacity(0.14), lineWidth: 22).frame(width: 260)
                Circle()
                    .trim(from: 0, to: clamped / 180 * 0.75)
                    .stroke(AngularGradient(colors: [.cyan, .blue, .cyan], center: .center), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    .frame(width: 260)
                    .rotationEffect(.degrees(135))

                VStack(spacing: 2) {
                    Text("\(Int(speed.rounded()))").font(.system(size: 78, weight: .heavy, design: .rounded))
                    Text(unit).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }

                VStack(alignment: .trailing, spacing: 0) {
                    Text("RPM").font(.caption2.weight(.bold)).foregroundStyle(.cyan)
                    Text("\(rpm)").font(.title2.weight(.bold)).foregroundStyle(.cyan)
                }
                .offset(x: 123, y: 139)
            }
            .frame(maxWidth: .infinity, minHeight: 316)
        }
    }
}
