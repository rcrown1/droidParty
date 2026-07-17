//
//  DroidPartyApp.swift
//  DroidParty
//

import SwiftUI

@main
struct DroidPartyApp: App {
    @StateObject private var bleManager: BLEManager
    @StateObject private var fleet: FleetViewModel

    init() {
        let mgr = BLEManager()
        _bleManager = StateObject(wrappedValue: mgr)
        _fleet = StateObject(wrappedValue: FleetViewModel(bleManager: mgr))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleManager)
                .environmentObject(fleet)
                .preferredColorScheme(.dark)
        }
    }
}
