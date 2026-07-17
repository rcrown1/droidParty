//
//  BroadcastControlView.swift
//  DroidParty
//
//  The "All" tab. Sends the same command to every ready droid in the
//  fleet, optionally filtered by droid family (BB-series / R-series).
//  Uses SoundBank / AnimationBank per droid so each one picks a category
//  member appropriate to its own hardware — e.g. broadcasting "Happy"
//  makes BB-9E play an animation from its Happy catalog while R2-D2
//  plays from its own.
//

import SwiftUI

struct BroadcastControlView: View {
    @EnvironmentObject private var fleet: FleetViewModel
    @AppStorage("showLabels") private var showLabels: Bool = false
    @State private var familyFilter: FamilyFilter = .all
    @State private var partyLightsOn: Bool = false
    @State private var partyLightsTasks: [DroidType: Task<Void, Never>] = [:]
    @State private var showSettings = false

    enum FamilyFilter: String, CaseIterable, Identifiable {
        case all = "All droids"
        case rSeries = "R-Series only"
        case bbSeries = "BB-Series only"
        var id: String { rawValue }
        var droidFamily: DroidFamily? {
            switch self {
            case .all:      return nil
            case .rSeries:  return .rSeries
            case .bbSeries: return .bbSeries
            }
        }
    }

    // MARK: Broadcast helpers

    private func broadcast(_ action: (DroidPresence) -> Void) {
        fleet.broadcast(family: familyFilter.droidFamily, action)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    fleetStrip
                    familyPicker
                    partyControls
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Party Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                FleetSettingsView()
                    .environmentObject(fleet)
            }
        }
    }

    // MARK: - Fleet strip

    private var fleetStrip: some View {
        HStack(spacing: 10) {
            ForEach(FleetViewModel.slotOrder) { type in
                if let presence = fleet.presences[type] {
                    fleetTile(for: presence)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func fleetTile(for presence: DroidPresence) -> some View {
        VStack(spacing: 4) {
            if let imageName = presence.droidType.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 44)
                    .opacity(presence.isConnected ? 1 : 0.35)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            HStack(spacing: 4) {
                Circle().fill(tileColor(presence)).frame(width: 6, height: 6)
                if presence.isConnected && presence.sensors.batteryState.voltageMillivolts > 0 {
                    Text("\(presence.sensors.batteryState.percentage)%")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .monospaced()
                } else {
                    Text(shortStatus(presence))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
    }

    private func tileColor(_ p: DroidPresence) -> Color {
        switch p.connectionState {
        case .ready: return .green
        case .connecting, .discovering, .handshaking, .scanning: return .yellow
        case .error: return .red
        default: return .gray
        }
    }

    private func shortStatus(_ p: DroidPresence) -> String {
        if fleet.knownDroids[p.droidType] == nil { return "unpaired" }
        return p.connectionState.displayName.lowercased()
    }

    // MARK: - Family picker

    private var familyPicker: some View {
        Picker("Target", selection: $familyFilter) {
            ForEach(FamilyFilter.allCases) { f in
                Text(f.rawValue).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
    }

    // MARK: - Party controls

    private var partyControls: some View {
        VStack(spacing: 14) {
            partySequenceRow
            partySoundsRow
            partyAnimationsRow
            partyLightsRow
            emergencyStop
        }
    }

    // MARK: Party sequence

    private var partySequenceRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Party Sequences")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(StarterSequences.all) { seq in
                        Button {
                            // In party mode every connected droid runs the
                            // sequence. Steps the droid can't perform become
                            // safe no-ops in its controllers, and audio steps
                            // are proxied through the BB→R mapping wired in
                            // FleetViewModel.
                            broadcast { presence in
                                presence.sequences.run(seq)
                            }
                        } label: {
                            Text(shortSequenceName(seq.name))
                                .font(.caption)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.purple.opacity(0.18))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }

    /// Compact per-sequence label so the horizontal row of capsules stays
    /// readable — the full names (e.g. "BB-9E Dramatic Entrance") are
    /// awkward at row width.
    private func shortSequenceName(_ name: String) -> String {
        switch name {
        case "BB-9E Dramatic Entrance": return "BB-9E Drama"
        case "R2 Waddle Dance":          return "R2 Waddle"
        case "Happy Greeting":           return "Greeting"
        case "BB-8 Color Spin":          return "BB-8 Spin"
        default:                         return name
        }
    }

    // MARK: Party sounds

    private var partySoundsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Party Sounds")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(broadcastSoundCategories, id: \.self) { category in
                        Button {
                            broadcast { presence in
                                let type = presence.droidType
                                guard SoundBank.hasPlayableSounds(category: category, for: type),
                                      let sound = SoundBank.randomSound(category: category, for: type) else { return }
                                presence.capability.playSound(id: sound.id)
                            }
                        } label: {
                            Text(category)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.accentColor.opacity(0.18))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                    Button {
                        broadcast { $0.capability.stopSound() }
                    } label: {
                        Image(systemName: "speaker.slash.fill")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.red.opacity(0.18))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }

    /// Categories worth broadcasting across the whole fleet — must exist in
    /// at least one droid's catalog. We stick to the union so a user tap
    /// can pick a sound for at least one droid regardless of filter.
    private var broadcastSoundCategories: [String] {
        ["Happy", "Excited", "Positive", "Emotion", "Alert", "Alarm", "Chatty", "Sad", "Negative"]
    }

    // MARK: Party animations

    private var partyAnimationsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Party Animations")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(broadcastAnimationCategories, id: \.self) { category in
                        Button {
                            broadcast { presence in
                                if AnimationBank.hasAnimations(category: category, for: presence.droidType),
                                   let anim = AnimationBank.randomAnimation(category: category, for: presence.droidType) {
                                    presence.capability.playAnimation(id: anim.id)
                                } else {
                                    // BB-8 has no animation hardware — fall
                                    // back to a category-tinted LED flash so
                                    // it participates visibly in the party.
                                    fallbackLEDPulse(category: category, on: presence)
                                }
                            }
                        } label: {
                            Text(category)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.18))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }
                    Button {
                        broadcast { $0.capability.stopAnimation() }
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.red.opacity(0.18))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }

    private var broadcastAnimationCategories: [String] {
        ["Happy", "Excited", "Curious", "Sass", "Angry", "Scared", "Action"]
    }

    /// Color that stands in for an emotion category when a droid lacks
    /// onboard animations (currently only BB-8).
    private func categoryColor(_ category: String) -> LEDColor {
        switch category {
        case "Happy", "Excited": return LEDColor(r: 0,   g: 255, b: 0)     // green
        case "Angry":            return LEDColor(r: 255, g: 0,   b: 0)     // red
        case "Scared":           return LEDColor(r: 255, g: 255, b: 0)     // yellow
        case "Curious":          return LEDColor(r: 0,   g: 128, b: 255)   // blue
        case "Sass":             return LEDColor(r: 200, g: 0,   b: 200)   // magenta
        case "Action":           return LEDColor(r: 255, g: 255, b: 255)   // white
        default:                 return LEDColor(r: 255, g: 128, b: 0)     // orange
        }
    }

    /// Two-blink LED pulse in the category color, then black. Runs on the
    /// droid's own LEDs so BB-8 participates in party animations visibly
    /// even though it has no animation catalog.
    private func fallbackLEDPulse(category: String, on presence: DroidPresence) {
        let targets = CapabilityRegistry.ledTargets(for: presence.droidType)
        guard !targets.isEmpty else { return }
        let color = categoryColor(category)
        Task { @MainActor in
            for _ in 0..<2 {
                for t in targets {
                    presence.capability.setRGBLED(target: t, color: color)
                }
                try? await Task.sleep(for: .milliseconds(220))
                for t in targets {
                    presence.capability.setRGBLED(target: t, color: .off)
                }
                try? await Task.sleep(for: .milliseconds(160))
            }
        }
    }

    // MARK: Party lights

    private var partyLightsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Party Lights")
            HStack(spacing: 10) {
                Button {
                    togglePartyLights()
                } label: {
                    Label(partyLightsOn ? "Stop Lights" : "Start Lights",
                          systemImage: partyLightsOn ? "lightbulb.slash" : "lightbulb.fill")
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(partyLightsOn ? Color.red.opacity(0.18) : Color.yellow.opacity(0.22))
                        .foregroundStyle(partyLightsOn ? .red : .yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private func togglePartyLights() {
        if partyLightsOn {
            stopPartyLights()
        } else {
            startPartyLights()
        }
    }

    private func startPartyLights() {
        partyLightsOn = true
        broadcast { presence in
            let targets = CapabilityRegistry.ledTargets(for: presence.droidType)
            guard !targets.isEmpty else { return }
            let task = Task { @MainActor in
                let colors = LEDColor.rainbowColors
                var idx = 0
                while !Task.isCancelled {
                    for target in targets {
                        let c = target.isRGB ? colors[idx % colors.count] : LEDColor(r: 255, g: 255, b: 255)
                        presence.capability.setRGBLED(target: target, color: c)
                        idx += 1
                    }
                    try? await Task.sleep(for: .milliseconds(350))
                }
            }
            partyLightsTasks[presence.droidType] = task
        }
    }

    private func stopPartyLights() {
        partyLightsOn = false
        for (_, task) in partyLightsTasks { task.cancel() }
        partyLightsTasks.removeAll()
        broadcast { presence in
            for target in CapabilityRegistry.ledTargets(for: presence.droidType) {
                presence.capability.setRGBLED(target: target, color: .off)
            }
        }
    }

    // MARK: Emergency stop

    private var emergencyStop: some View {
        Button(role: .destructive) {
            stopPartyLights()
            fleet.broadcast(family: nil) { presence in
                presence.drive.emergencyStop()
                presence.capability.stopAll()
                presence.sequences.cancel()
            }
        } label: {
            Label("EMERGENCY STOP", systemImage: "stop.circle.fill")
                .font(.callout.weight(.bold))
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.20))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    // MARK: - Section header helper

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.leading, 12)
    }
}
