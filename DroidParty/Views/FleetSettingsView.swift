//
//  FleetSettingsView.swift
//  DroidParty
//
//  Settings sheet: shows the 4 fleet slots, lets the user pair new
//  droids, forget existing ones, and force a rescan.
//

import SwiftUI
import CoreBluetooth

struct FleetSettingsView: View {
    @EnvironmentObject private var fleet: FleetViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Fleet Slots") {
                    ForEach(FleetViewModel.slotOrder) { type in
                        if let presence = fleet.presences[type] {
                            fleetRow(for: presence)
                        }
                    }
                }

                Section("Pair Droids") {
                    Toggle(isOn: Binding(
                        get: { fleet.isDiscoveryMode },
                        set: { newValue in
                            if newValue { fleet.startDiscoveryScan() } else { fleet.endDiscoveryScan() }
                        }
                    )) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Discovery Mode")
                                Text("Auto-adds any nearby droid to an empty slot")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "magnifyingglass")
                        }
                    }

                    if fleet.isScanning {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text(fleet.statusMessage.isEmpty ? "Scanning…" : fleet.statusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Actions") {
                    Button {
                        fleet.reconnectAll()
                    } label: {
                        Label("Reconnect All", systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive) {
                        for type in FleetViewModel.slotOrder {
                            fleet.disconnect(type)
                        }
                    } label: {
                        Label("Disconnect All", systemImage: "power")
                    }
                }

                Section("Status") {
                    LabeledContent("Bluetooth") {
                        Text(bluetoothStatusLabel).foregroundStyle(bluetoothStatusColor)
                    }
                    LabeledContent("Paired droids") {
                        Text("\(fleet.knownDroids.count) / 4").monospaced()
                    }
                }
            }
            .navigationTitle("Fleet Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func fleetRow(for presence: DroidPresence) -> some View {
        HStack(spacing: 12) {
            if let imageName = presence.droidType.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .opacity(presence.isConnected ? 1 : 0.35)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(presence.droidType.displayName).font(.callout.weight(.semibold))
                HStack(spacing: 6) {
                    Circle().fill(dotColor(presence)).frame(width: 6, height: 6)
                    Text(rowStatus(presence)).font(.caption).foregroundStyle(.secondary)
                }
                if let uuid = fleet.knownDroids[presence.droidType] {
                    Text(uuid.uuidString.prefix(8).lowercased())
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if fleet.knownDroids[presence.droidType] != nil {
                Menu {
                    if presence.isConnected {
                        Button {
                            fleet.disconnect(presence.droidType)
                        } label: {
                            Label("Disconnect", systemImage: "power")
                        }
                    } else {
                        Button {
                            fleet.reconnectAll()
                        } label: {
                            Label("Reconnect", systemImage: "arrow.clockwise")
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        fleet.forgetDroid(presence.droidType)
                    } label: {
                        Label("Forget", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            } else {
                Text("Not paired")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func dotColor(_ p: DroidPresence) -> Color {
        switch p.connectionState {
        case .ready: return .green
        case .connecting, .discovering, .handshaking, .scanning: return .yellow
        case .error: return .red
        default: return .gray
        }
    }

    private func rowStatus(_ p: DroidPresence) -> String {
        if fleet.knownDroids[p.droidType] == nil { return "Unpaired" }
        return p.connectionState.displayName
    }

    private var bluetoothStatusLabel: String {
        switch fleet.bleManager.centralState {
        case .poweredOn:  return "On"
        case .poweredOff: return "Off"
        case .unauthorized: return "Not authorized"
        case .resetting: return "Resetting"
        case .unsupported: return "Unsupported"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }

    private var bluetoothStatusColor: Color {
        fleet.bleManager.centralState == .poweredOn ? .green : .red
    }
}
