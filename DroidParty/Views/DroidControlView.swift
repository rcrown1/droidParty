//
//  DroidControlView.swift
//  DroidParty
//
//  Full-screen control panel for a single droid — one instance per
//  bottom-tab slot. Adapted from SWSphero's OperateView but bound to a
//  fixed DroidPresence rather than auto-attaching to whatever droid
//  connected first.
//

import SwiftUI

struct DroidControlView: View {
    @StateObject private var viewModel: DroidControlViewModel
    @ObservedObject private var favoritesStore = FavoritesStore.shared
    @EnvironmentObject private var fleet: FleetViewModel
    @AppStorage("showLabels") private var showLabels: Bool = false
    @State private var showSettings = false

    init(presence: DroidPresence, bleManager: BLEManager) {
        _viewModel = StateObject(wrappedValue: DroidControlViewModel(presence: presence, bleManager: bleManager))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    if viewModel.isConnected {
                        connectedBody
                    } else {
                        notConnectedPlaceholder
                    }
                }

                if viewModel.isCalibrating {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { }
                    CalibrationView(viewModel: viewModel, droidType: viewModel.droidType)
                }
            }
            .navigationTitle(viewModel.droidType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { titleBar }
                ToolbarItem(placement: .topBarTrailing) { overflowMenu }
            }
            .onDisappear { viewModel.onDisappear() }
            .sheet(isPresented: $showSettings) {
                FleetSettingsView()
                    .environmentObject(fleet)
            }
        }
    }

    // MARK: - Connected body

    @ViewBuilder
    private var connectedBody: some View {
        if !favoritesStore.favorites(for: viewModel.droidType).isEmpty {
            favoritesRowView
        }
        if viewModel.hasSoundControl {
            soundRowView
        }
        mainControlArea
        if viewModel.hasAnimationControl {
            animationRowView
        }
        if viewModel.hasHeadControl {
            headPositionSection
        }
    }

    // MARK: - Title bar

    private var titleBar: some View {
        HStack(spacing: 8) {
            if let imageName = viewModel.droidType.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            Text(viewModel.droidDisplayName.isEmpty ? viewModel.droidType.displayName : viewModel.droidDisplayName)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)

            if viewModel.isConnected && viewModel.batteryState.voltageMillivolts > 0 {
                Image(systemName: viewModel.batteryState.iconName)
                    .font(.system(size: 12))
                    .foregroundStyle(batteryColor)
                Text("\(viewModel.batteryState.percentage)%")
                    .font(.system(size: 10))
                    .foregroundStyle(batteryColor)
            }
        }
    }

    // MARK: - Overflow menu

    private var overflowMenu: some View {
        Menu {
            if viewModel.isConnected {
                Button {
                    viewModel.toggleCalibration()
                } label: {
                    Label("Calibrate Heading", systemImage: "location.north.circle")
                }
                Button {
                    viewModel.emergencyStop()
                } label: {
                    Label("Stop", systemImage: "stop.circle")
                }
                Divider()
                Button(role: .destructive) {
                    viewModel.powerOff()
                } label: {
                    Label("Power Off", systemImage: "power")
                }
            } else if fleet.knownDroids[viewModel.droidType] != nil {
                Button {
                    fleet.reconnectAll()
                } label: {
                    Label("Reconnect", systemImage: "arrow.clockwise")
                }
                Button(role: .destructive) {
                    fleet.forgetDroid(viewModel.droidType)
                } label: {
                    Label("Forget This Droid", systemImage: "trash")
                }
            }

            Divider()

            Toggle(isOn: $showLabels) {
                Label("Show Labels", systemImage: "textformat")
            }

            Button {
                showSettings = true
            } label: {
                Label("Fleet Settings", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: - Head position

    private var isHeadCentered: Bool {
        abs(viewModel.headAngle) < 1
    }

    private var headPositionSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Head")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 12)
            HStack(spacing: 6) {
                Image(systemName: "rotate.3d")
                    .foregroundStyle(.secondary)
                    .font(.caption2)
                Slider(value: $viewModel.headAngle, in: -160...180, step: 5) { editing in
                    if editing {
                        viewModel.headMoveStarted()
                    } else {
                        if abs(viewModel.headAngle) <= 10 {
                            viewModel.headAngle = 0
                        }
                        viewModel.setHeadPosition(viewModel.headAngle)
                        viewModel.headMoveEnded()
                    }
                }
                .onChange(of: viewModel.headAngle) { _, newValue in
                    viewModel.setHeadPosition(newValue)
                }
                Text(isHeadCentered ? "Center" : "\(Int(viewModel.headAngle))°")
                    .font(.caption2)
                    .monospaced()
                    .foregroundStyle(isHeadCentered ? .green : .primary)
                    .frame(width: 44, alignment: .trailing)
                Button {
                    viewModel.headAngle = 0
                    viewModel.setHeadPosition(0)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Main control area

    private var mainControlArea: some View {
        HStack(spacing: 0) {
            if viewModel.hasLEDControl {
                ledColumnView
            } else {
                Spacer().frame(width: 56)
            }

            JoystickView(
                onMoved: { viewModel.joystickMoved(to: $0) },
                onReleased: { viewModel.joystickReleased() },
                deadZone: viewModel.deadZone,
                yawAngle: viewModel.sensorData.yaw,
                showCompass: viewModel.isStreamingSensors
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if viewModel.hasLegControl {
                legColumnView
            } else {
                Spacer().frame(width: 56)
            }
        }
        .frame(maxHeight: 260)
    }

    // MARK: - Sound row

    private var soundRowView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sounds")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 12)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(viewModel.soundCategories, id: \.self) { category in
                        SoundIconButton(
                            category: category,
                            isActive: viewModel.lastPlayedCategory == category,
                            droidType: viewModel.droidType,
                            showLabel: showLabels
                        ) {
                            viewModel.playSoundCategory(category)
                        }
                    }
                    Button {
                        viewModel.stopSound()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .frame(width: 40, height: 34)
                            .background(.red.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Leg column

    private var legColumnView: some View {
        VStack(spacing: 4) {
            Text("Legs")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ForEach(R2LegAction.allCases.filter { $0 != .stop }) { action in
                LegActionButton(
                    action: action,
                    isActive: viewModel.currentLegAction == action,
                    showLabel: showLabels
                ) {
                    viewModel.performLegAction(action)
                }
            }
            Button {
                viewModel.performLegAction(.stop)
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                    .frame(width: 48, height: 34)
                    .background(.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Spacer()
        }
        .frame(width: showLabels ? 72 : 56)
    }

    // MARK: - LED column

    private var ledColumnView: some View {
        VStack(spacing: 4) {
            Text("Lights")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ForEach(viewModel.ledTargets) { target in
                LEDTargetButton(
                    target: target,
                    color: viewModel.ledColors[target] ?? .off,
                    hasEffect: viewModel.activeEffect[target] != nil,
                    showLabel: showLabels,
                    onTap: { viewModel.cycleLEDColor(for: target) },
                    onEffect: { effect in viewModel.startEffect(effect, on: target) },
                    onStopEffect: { viewModel.stopEffect(on: target) }
                )
            }
            Spacer()
        }
        .frame(width: showLabels ? 72 : 56)
    }

    // MARK: - Animation row

    private var animationRowView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sequences")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 12)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(viewModel.animationCategories, id: \.self) { category in
                        AnimationIconButton(
                            category: category,
                            isActive: viewModel.lastPlayedAnimationCategory == category,
                            droidType: viewModel.droidType,
                            showLabel: showLabels
                        ) {
                            viewModel.playAnimationCategory(category)
                        }
                    }
                    Button {
                        viewModel.stopAnimation()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .frame(width: 40, height: 34)
                            .background(.red.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Favorites

    private var favoritesRowView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Favorites")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 12)
            HStack(spacing: 6) {
                ForEach(favoritesStore.favorites(for: viewModel.droidType)) { item in
                    FavoriteIconButton(item: item, showLabel: showLabels) {
                        playFavorite(item)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
        }
    }

    private func playFavorite(_ item: FavoriteItem) {
        switch item.kind {
        case .sound:
            viewModel.playSound(id: item.numericID)
        case .animation:
            viewModel.playAnimation(id: UInt8(item.numericID))
        case .sequence:
            if let seqID = item.sequenceID,
               let seq = StarterSequences.all.first(where: { $0.id == seqID }) {
                viewModel.sequenceRunner.run(seq)
            }
        }
    }

    // MARK: - Not-connected placeholder

    private var notConnectedPlaceholder: some View {
        VStack(spacing: 16) {
            Spacer()
            if let imageName = viewModel.droidType.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .opacity(0.3)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }
            Text(viewModel.droidType.displayName)
                .font(.title2.bold())
            Text(placeholderMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            HStack(spacing: 12) {
                if fleet.knownDroids[viewModel.droidType] != nil {
                    Button {
                        fleet.reconnectAll()
                    } label: {
                        Label("Reconnect", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(fleet.isScanning)
                } else {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Pair Droid", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            if fleet.isScanning {
                ProgressView(fleet.statusMessage.isEmpty ? "Scanning…" : fleet.statusMessage)
                    .font(.caption)
            }
            Spacer()
        }
    }

    private var placeholderMessage: String {
        if fleet.knownDroids[viewModel.droidType] == nil {
            return "Not paired. Open Fleet Settings to add this droid to your party."
        }
        switch viewModel.presence.connectionState {
        case .connecting, .discovering, .handshaking, .scanning:
            return viewModel.presence.connectionState.displayName
        case .error(let msg):
            return "Error: \(msg)"
        default:
            return "Waiting for droid…"
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch viewModel.presence.connectionState {
        case .ready: return .green
        case .connecting, .discovering, .handshaking, .scanning: return .yellow
        case .error: return .red
        default: return .gray
        }
    }

    private var batteryColor: Color {
        let pct = viewModel.batteryState.percentage
        if pct < 20 { return .red }
        if pct <= 50 { return .yellow }
        return .green
    }

}
