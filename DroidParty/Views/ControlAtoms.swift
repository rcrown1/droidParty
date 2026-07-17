//
//  ControlAtoms.swift
//  DroidParty
//
//  Reusable per-droid control widgets extracted from SWSphero's DriveView.
//  All are VM-independent (they take primitives + callbacks) so they can be
//  shared between the per-droid tab and the broadcast tab.
//

import SwiftUI

// MARK: - Sound Icon Button (icon-only)

struct SoundIconButton: View {
    let category: String
    let isActive: Bool
    let droidType: DroidType
    var showLabel: Bool = false
    let action: () -> Void

    private var iconName: String {
        switch category {
        case "BB-8":       return "circle.circle.fill"
        case "Mechanical": return "gearshape.fill"
        case "Alarm":      return "bell.fill"
        case "Alert":      return "exclamationmark.triangle.fill"
        case "Burnout":    return "flame.fill"
        case "Chatty":     return "bubble.left.fill"
        case "Emotion":    return "theatermasks.fill"
        case "Excited":    return "star.fill"
        case "Hey":        return "hand.wave.fill"
        case "Laugh":      return "face.smiling.fill"
        case "Negative":   return "hand.thumbsdown.fill"
        case "Positive":   return "hand.thumbsup.fill"
        case "Sad":        return "cloud.rain.fill"
        default:           return "speaker.wave.2.fill"
        }
    }

    private var isPlayable: Bool {
        SoundBank.hasPlayableSounds(category: category, for: droidType)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: iconName)
                    .font(.system(size: 16))
                if showLabel {
                    Text(category)
                        .font(.system(size: 8))
                        .lineLimit(1)
                }
            }
            .frame(width: showLabel ? 52 : 40, height: showLabel ? 44 : 34)
            .foregroundStyle(isActive ? .white : isPlayable ? Color.accentColor : .secondary)
            .background(isActive ? Color.accentColor : isPlayable ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(!isPlayable)
    }
}

// MARK: - Animation Icon Button (icon-only, horizontal)

struct AnimationIconButton: View {
    let category: String
    let isActive: Bool
    let droidType: DroidType
    var showLabel: Bool = false
    let action: () -> Void

    private var iconName: String {
        switch category {
        case "Happy":   return "face.smiling.fill"
        case "Angry":   return "flame.fill"
        case "Scared":  return "bolt.heart.fill"
        case "Curious": return "eye.fill"
        case "Sass":    return "hand.raised.fill"
        case "Action":  return "figure.walk"
        default:        return "sparkles"
        }
    }

    private var hasContent: Bool {
        // BB-8 has no onboard animation catalog but DroidParty synthesizes
        // per-category recipes for it (see BB8AnimationRecipes), so every
        // category renders as playable.
        if droidType == .bb8 {
            return BB8AnimationRecipes.operateCategories.contains(category)
        }
        return AnimationBank.hasAnimations(category: category, for: droidType)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: iconName)
                    .font(.system(size: 16))
                if showLabel {
                    Text(category)
                        .font(.system(size: 8))
                        .lineLimit(1)
                }
            }
            .frame(width: showLabel ? 52 : 40, height: showLabel ? 44 : 34)
            .foregroundStyle(isActive ? .white : hasContent ? .green : .secondary)
            .background(isActive ? .green : hasContent ? .green.opacity(0.12) : Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(!hasContent)
    }
}

// MARK: - LED Target Button (tap to cycle, long-press for effects)

struct LEDTargetButton: View {
    let target: LEDTarget
    let color: LEDColor
    let hasEffect: Bool
    var showLabel: Bool = false
    let onTap: () -> Void
    let onEffect: (LEDEffect) -> Void
    let onStopEffect: () -> Void

    private var iconColor: Color {
        color.swiftUIColor
    }

    var body: some View {
        Menu {
            ForEach(LEDEffect.allCases) { effect in
                Button {
                    onEffect(effect)
                } label: {
                    Label(effect.displayName, systemImage: effect.iconName)
                }
            }
            if hasEffect {
                Divider()
                Button("Stop Effect", role: .destructive) {
                    onStopEffect()
                }
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: target.iconName)
                    .font(.system(size: 18))
                    .symbolEffect(.pulse, isActive: hasEffect)
                if showLabel {
                    Text(target.shortName)
                        .font(.system(size: 7))
                        .lineLimit(1)
                }
            }
            .frame(width: showLabel ? 48 : 36, height: showLabel ? 44 : 36)
            .foregroundStyle(iconColor)
            .background(iconColor.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: showLabel ? 8 : 18))
        } primaryAction: {
            onTap()
        }
    }
}

// MARK: - Leg Action Button (icon-only)

struct LegActionButton: View {
    let action: R2LegAction
    let isActive: Bool
    var showLabel: Bool = false
    let onTap: () -> Void

    private var iconName: String {
        switch action {
        case .tripod: return "triangle.fill"
        case .bipod:  return "pause.fill"
        case .waddle: return "water.waves"
        case .stop:   return "stop.fill"
        }
    }

    private var shortName: String {
        switch action {
        case .tripod: return "Tripod"
        case .bipod:  return "Bipod"
        case .waddle: return "Waddle"
        case .stop:   return "Stop"
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: iconName)
                    .font(.system(size: 16))
                if showLabel {
                    Text(shortName)
                        .font(.system(size: 8))
                        .lineLimit(1)
                }
            }
            .frame(width: showLabel ? 52 : 48, height: showLabel ? 44 : 40)
            .foregroundStyle(isActive ? .white : .orange)
            .background(isActive ? .orange : .orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Favorite Icon Button

struct FavoriteIconButton: View {
    let item: FavoriteItem
    var showLabel: Bool = false
    let action: () -> Void

    private var tintColor: Color {
        switch item.kind {
        case .sound:     return .accentColor
        case .animation: return .green
        case .sequence:  return .purple
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: item.iconName)
                    .font(.system(size: 14))
                Text(item.name)
                    .font(.system(size: 7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: showLabel ? 44 : 38)
            .foregroundStyle(tintColor)
            .background(tintColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
