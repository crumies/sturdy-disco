import SwiftUI

struct TuningView: View {
    @EnvironmentObject var ble: DunenBLEManager
    @EnvironmentObject var tuning: TuningStore
    @EnvironmentObject var settings: AppSettings

    @State private var selectedGroup: TuningGroup = .common
    @State private var showUnlock = false
    @State private var pendingToggle: TuningParameter?
    @State private var showWriteConfirm = false

    var filtered: [TuningParameter] {
        tuning.parameters.filter { $0.group == selectedGroup }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                GlassCard(glow: tuning.didLoadFromController) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tuning.statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Button(tuning.isReading ? "Reading..." : "Read Current Settings") {
                                ble.readCurrentSettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.cyan)
                            .disabled((!ble.isConnected && !ble.isDemoMode) || tuning.isReading)

                            Button("Backup") {
                                tuning.saveBackup(reason: "manual")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Picker("Group", selection: $selectedGroup) {
                    ForEach(TuningGroup.allCases, id: \.self) { group in
                        Text(group.rawValue).tag(group)
                    }
                }
                .pickerStyle(.segmented)

                if !settings.expertTuningUnlocked {
                    lockedCard
                } else {
                    ForEach(filtered) { param in
                        ParameterRow(param: param, disabled: !tuning.didLoadFromController) { newValue in
                            var edited = param
                            edited.pendingValue = newValue
                            pendingToggle = edited
                        }
                    }

                    if !tuning.changedParameters.isEmpty {
                        Button("Write \(tuning.changedParameters.count) Changed Setting(s)") {
                            showWriteConfirm = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(!tuning.didLoadFromController || tuning.isWriting)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 112)
        }
        .alert("Unlock tuning?", isPresented: $showUnlock) {
            Button("Cancel", role: .cancel) {}
            Button("I Understand") { settings.expertTuningUnlocked = true }
        } message: {
            Text("Changing controller parameters is your own responsibility. The app will read current settings first, backup originals, and ask before writing.")
        }
        .alert(item: $pendingToggle) { param in
            let enable = (param.pendingValue ?? 0) >= 0.5
            return Alert(
                title: Text("Are you sure?"),
                message: Text("Do you want to \(enable ? "enable" : "disable") \(param.displayName)?\n\nBackend: \(param.internalName)\nID: \(param.id)"),
                primaryButton: .destructive(Text(enable ? "Enable" : "Disable")) {
                    tuning.updatePending(id: param.id, value: enable ? 1 : 0)
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Write changed settings?", isPresented: $showWriteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Backup & Write", role: .destructive) {
                ble.writeChangedSettings(tuning.changedParameters)
            }
        } message: {
            Text("Original settings will be backed up first. Only changed parameters will be written.")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Tuning").font(.largeTitle.weight(.heavy))
                Text("Read first. Backup before write.").font(.caption).foregroundStyle(.cyan)
            }
            Spacer()
            ConnectionPill()
        }
    }

    private var lockedCard: some View {
        GlassCard(glow: true) {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Tuning Locked")
                    .font(.title2.weight(.bold))
                Text("Press unlock to access safer toggle controls.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Unlock Tuning") { showUnlock = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct ParameterRow: View {
    let param: TuningParameter
    let disabled: Bool
    let onChange: (Double) -> Void

    var body: some View {
        GlassCard(glow: param.hasChange) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(param.displayName).font(.headline)
                        Text("\(param.internalName)  •  ID \(param.id)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if param.isRisky {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Text(param.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(isOn: Binding(
                    get: { (param.pendingValue ?? param.currentValue ?? 0) >= 0.5 },
                    set: { onChange($0 ? 1 : 0) }
                )) {
                    Text(((param.pendingValue ?? param.currentValue ?? 0) >= 0.5) ? "Enabled" : "Disabled")
                        .fontWeight(.semibold)
                }
                .tint(.cyan)
                .disabled(disabled || !param.loaded)

                if !param.loaded {
                    Text("Not loaded yet — press Read Current Settings first.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                if param.hasChange {
                    Text("Changed: original \(String(format: "%.0f", param.currentValue ?? 0)) → new \(String(format: "%.0f", param.pendingValue ?? 0))")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                }
            }
        }
    }
}
