//
//  JoystickView.swift
//  SWSphero
//
//  Virtual joystick with drag gesture producing normalized x/y output.
//

import SwiftUI

struct JoystickView: View {
    /// Called continuously as the joystick moves.
    let onMoved: (JoystickVector) -> Void
    /// Called when the joystick is released.
    let onReleased: () -> Void
    /// Current dead zone for visual indicator.
    let deadZone: Double
    /// Droid's current yaw heading from IMU (0–360 degrees).
    var yawAngle: Double = 0
    /// Whether to show the compass ring overlay.
    var showCompass: Bool = false
    
    /// Joystick outer ring diameter.
    private let outerSize: CGFloat = 240
    /// Joystick knob diameter.
    private let knobSize: CGFloat = 70
    /// Compass ring diameter (slightly inside outer ring).
    private let compassSize: CGFloat = 232
    
    @State private var knobOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    
    private var maxRadius: CGFloat {
        (outerSize - knobSize) / 2
    }
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                .frame(width: outerSize, height: outerSize)
            
            // Dead zone indicator
            Circle()
                .fill(Color.red.opacity(0.08))
                .frame(width: outerSize * deadZone, height: outerSize * deadZone)
            
            // Heading indicator lines (N/S/E/W)
            ForEach([0, 90, 180, 270], id: \.self) { angle in
                Rectangle()
                    .fill(Color.secondary.opacity(angle == 0 ? 0.5 : 0.15))
                    .frame(width: angle == 0 ? 2 : 1, height: outerSize / 2 - knobSize / 2)
                    .offset(y: -(outerSize / 4))
                    .rotationEffect(.degrees(Double(angle)))
            }
            
            // Compass ring — shows droid yaw heading
            Group {
                if showCompass {
                    ZStack {
                        // Compass ring stroke
                        Circle()
                            .stroke(Color.accentColor.opacity(0.35), lineWidth: 2)
                            .frame(width: compassSize, height: compassSize)
                        
                        // User position pointer — rotates opposite to droid yaw
                        // When yaw=0 the pointer is at top (user is in front).
                        // As droid turns right, pointer rotates left.
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.accentColor)
                            .offset(y: -(compassSize / 2 + 2))
                            .rotationEffect(.degrees(-yawAngle))
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showCompass)
            
            // Forward arrow indicator
            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.secondary.opacity(0.4))
                .offset(y: -(outerSize / 2 + 10))
            
            // Knob
            Circle()
                .fill(isDragging ? Color.accentColor : Color.accentColor.opacity(0.7))
                .frame(width: knobSize, height: knobSize)
                .shadow(color: .black.opacity(0.2), radius: isDragging ? 8 : 4)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .offset(knobOffset)
                .gesture(dragGesture)
        }
        .frame(width: outerSize + 30, height: outerSize + 30)
    }
    
    // MARK: - Gesture
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                
                let dx = value.translation.width
                let dy = value.translation.height
                let distance = sqrt(dx * dx + dy * dy)
                
                // Clamp to outer ring
                if distance <= maxRadius {
                    knobOffset = value.translation
                } else {
                    let scale = maxRadius / distance
                    knobOffset = CGSize(width: dx * scale, height: dy * scale)
                }
                
                // Convert to normalized vector
                // Screen coords: right = +x, down = +y
                // Joystick coords: right = +x, up = +y (invert Y)
                let normalizedX = Double(knobOffset.width) / Double(maxRadius)
                let normalizedY = -Double(knobOffset.height) / Double(maxRadius) // Invert Y
                
                let vector = JoystickVector(
                    x: min(1, max(-1, normalizedX)),
                    y: min(1, max(-1, normalizedY))
                )
                onMoved(vector)
            }
            .onEnded { _ in
                isDragging = false
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    knobOffset = .zero
                }
                onReleased()
            }
    }
}
