//
//  ContentView.swift
//  DroidParty
//
//  Bottom-tab shell: one tab per droid slot, plus an "All" tab for
//  broadcast control. Kicks off the auto-connect-all flow on first
//  appearance.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var bleManager: BLEManager
    @EnvironmentObject private var fleet: FleetViewModel
    @State private var selectedTab: TabSelection = .bb8

    enum TabSelection: Hashable {
        case droid(DroidType)
        case all

        static var bb8: TabSelection  { .droid(.bb8) }
        static var bb9e: TabSelection { .droid(.bb9e) }
        static var r2d2: TabSelection { .droid(.r2d2) }
        static var r2q5: TabSelection { .droid(.r2q5) }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(FleetViewModel.slotOrder) { type in
                if let presence = fleet.presences[type] {
                    DroidControlView(presence: presence, bleManager: bleManager, fleet: fleet)
                        .tabItem {
                            Label {
                                Text(shortName(type))
                            } icon: {
                                tabIcon(for: type, presence: presence)
                            }
                        }
                        .tag(TabSelection.droid(type))
                }
            }

            BroadcastControlView()
                .tabItem {
                    Label {
                        Text("All")
                    } icon: {
                        Image("DroidFleet")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                .tag(TabSelection.all)
        }
        .task {
            await fleet.autoConnectAll()
        }
    }

    private func shortName(_ type: DroidType) -> String {
        switch type {
        case .bb8:  return "BB-8"
        case .bb9e: return "BB-9E"
        case .r2d2: return "R2-D2"
        case .r2q5: return "R2-Q5"
        default:    return type.displayName
        }
    }

    @ViewBuilder
    private func tabIcon(for type: DroidType, presence: DroidPresence) -> some View {
        if let imageName = type.imageName {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(presence.isConnected ? 1 : 0.5)
        } else {
            Image(systemName: "questionmark.circle")
        }
    }
}
