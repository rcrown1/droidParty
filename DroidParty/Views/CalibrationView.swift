//
//  CalibrationView.swift
//  DroidParty
//
//  Heading calibration overlay. The user physically orients the droid
//  so it faces away, then confirms to set forward direction.
//

import SwiftUI

struct CalibrationView: View {
    @ObservedObject var viewModel: DroidControlViewModel
    let droidType: DroidType
    
    private var isRSeries: Bool {
        droidType == .r2d2 || droidType == .r2q5
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: isRSeries ? "rotate.3d" : "light.min")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            
            Text("Set Forward Direction")
                .font(.headline)
            
            // Droid-specific instruction
            instructionText
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // Visual guide
            droidGuide
            
            // Confirm
            Button {
                viewModel.confirmCalibration()
            } label: {
                Label("Set Forward", systemImage: "checkmark.circle.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            
            // Cancel
            Button {
                viewModel.cancelCalibration()
            } label: {
                Text("Cancel")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(24)
    }
    
    @ViewBuilder
    private var instructionText: some View {
        if isRSeries {
            Text("Rotate your droid so it faces\ndirectly away from you.\n\nThe front of the droid should\npoint forward.")
        } else {
            Text("Rotate the droid until the\nblue aiming light faces toward you.\n\nThe opposite side becomes\nthe forward direction.")
        }
    }
    
    private var droidGuide: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                .frame(width: 100, height: 100)
            
            // Forward arrow (away from user)
            VStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 20, weight: .bold))
                Text("Away")
                    .font(.system(size: 9))
            }
            .foregroundStyle(.orange)
            .offset(y: -30)
            
            // User position indicator
            VStack(spacing: 2) {
                Text("You")
                    .font(.system(size: 9))
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
            }
            .foregroundStyle(.secondary)
            .offset(y: 32)
        }
    }
}
