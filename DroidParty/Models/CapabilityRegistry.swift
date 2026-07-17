//
//  CapabilityRegistry.swift
//  SWSphero
//
//  Static catalogs of known animations, sounds, and LED targets
//  for each Sphero Star Wars droid type.
//
//  REVERSE ENGINEERING NOTES:
//  All IDs sourced from the spherov2.py reference implementation:
//  - R2-D2/R2-Q5 animations: spherov2/toy/r2d2.py Animations enum (56 entries, IDs 0-55)
//  - BB-9E animations: spherov2/toy/bb9e.py Animations enum (49 entries, IDs 0-48)
//  - R2-D2 sounds: spherov2/toy/r2d2.py Audio enum (230+ entries, IDs 1-5513)
//  - BB-9E sounds: subset of R2-D2 Audio enum (BB9E range: ~1329-1600)
//  - R2-D2 LEDs: spherov2/toy/r2d2.py LEDs enum (8 indices)
//  - BB-9E LEDs: spherov2/toy/bb9e.py LEDs enum (5 indices)
//  - BB-8: no onboard animations or speaker (inherits from Ollie, not R2D2)
//
//  SOUND QUALITY RATINGS (from hardware testing):
//  Each sound has per-droid quality ratings:
//    0 = silent (no audible output on that droid)
//    1 = very short blip (barely audible)
//    2 = short sound (recognizable but brief)
//    3 = rich sequence (full expressive sound)
//    9 = test-only (sine wave / diagnostic tone)
//

import Foundation

// MARK: - Capability Registry

enum CapabilityRegistry {
    
    // MARK: - Animations
    
    static func animations(for droidType: DroidType) -> [AnimationDescriptor] {
        switch droidType {
        case .r2d2, .r2q5: return r2Animations
        case .bb9e:        return bb9eAnimations
        case .bb8:         return []
        case .unknownSphero: return []
        }
    }
    
    // MARK: - Sounds
    
    static func sounds(for droidType: DroidType) -> [SoundDescriptor] {
        switch droidType {
        case .r2d2:  return r2d2Sounds
        case .r2q5:  return r2q5Sounds
        case .bb9e:  return bb9eSounds
        case .bb8:   return bb8Sounds
        case .unknownSphero: return []
        }
    }
    
    // MARK: - LED Targets
    
    static func ledTargets(for droidType: DroidType) -> [LEDTarget] {
        switch droidType {
        case .r2d2, .r2q5: return [.frontRGB, .logicDisplays, .backRGB, .holoProjector]
        case .bb9e:        return [.bodyRGB, .aimingLED, .headLED]
        case .bb8:         return [.bodyRGB, .backLED]
        case .unknownSphero: return []
        }
    }
    
    // MARK: - R2-D2 / R2-Q5 Animations (56 total)
    // Categories: Happy, Angry, Scared, Curious, Sass, Action, Idle, System
    
    private static let r2Animations: [AnimationDescriptor] = [
        // System — charger sequences, motor test (0-6, 55)
        AnimationDescriptor(id: 0, name: "Charger 1", category: "System"),
        AnimationDescriptor(id: 1, name: "Charger 2", category: "System"),
        AnimationDescriptor(id: 2, name: "Charger 3", category: "System"),
        AnimationDescriptor(id: 3, name: "Charger 4", category: "System"),
        AnimationDescriptor(id: 4, name: "Charger 5", category: "System"),
        AnimationDescriptor(id: 5, name: "Charger 6", category: "System"),
        AnimationDescriptor(id: 6, name: "Charger 7", category: "System"),
        AnimationDescriptor(id: 55, name: "Motor", category: "System"),
        // Happy — positive emotions
        AnimationDescriptor(id: 12, name: "Excited", category: "Happy"),
        AnimationDescriptor(id: 15, name: "Laugh", category: "Happy"),
        AnimationDescriptor(id: 19, name: "Understood", category: "Happy"),
        AnimationDescriptor(id: 21, name: "Yes", category: "Happy"),
        AnimationDescriptor(id: 37, name: "Excited", category: "Happy"),
        AnimationDescriptor(id: 40, name: "Happy", category: "Happy"),
        AnimationDescriptor(id: 42, name: "Laugh", category: "Happy"),
        AnimationDescriptor(id: 46, name: "Relieved", category: "Happy"),
        AnimationDescriptor(id: 54, name: "Yoohoo", category: "Happy"),
        // Angry — aggressive/negative
        AnimationDescriptor(id: 7, name: "Alarm", category: "Angry"),
        AnimationDescriptor(id: 8, name: "Angry", category: "Angry"),
        AnimationDescriptor(id: 18, name: "Fiery", category: "Angry"),
        AnimationDescriptor(id: 31, name: "Angry", category: "Angry"),
        AnimationDescriptor(id: 38, name: "Fiery", category: "Angry"),
        AnimationDescriptor(id: 51, name: "Taunting", category: "Angry"),
        AnimationDescriptor(id: 53, name: "Yelling", category: "Angry"),
        // Scared — fear/distress
        AnimationDescriptor(id: 17, name: "Retreat", category: "Scared"),
        AnimationDescriptor(id: 32, name: "Anxious", category: "Scared"),
        AnimationDescriptor(id: 34, name: "Concern", category: "Scared"),
        AnimationDescriptor(id: 41, name: "Jittery", category: "Scared"),
        AnimationDescriptor(id: 47, name: "Sad", category: "Scared"),
        AnimationDescriptor(id: 48, name: "Scared", category: "Scared"),
        // Curious — investigation/surprise
        AnimationDescriptor(id: 9, name: "Attention", category: "Curious"),
        AnimationDescriptor(id: 13, name: "Search", category: "Curious"),
        AnimationDescriptor(id: 22, name: "Scan", category: "Curious"),
        AnimationDescriptor(id: 24, name: "Surprised", category: "Curious"),
        AnimationDescriptor(id: 35, name: "Curious", category: "Curious"),
        AnimationDescriptor(id: 36, name: "Double Take", category: "Curious"),
        AnimationDescriptor(id: 50, name: "Surprised", category: "Curious"),
        AnimationDescriptor(id: 52, name: "Whisper", category: "Curious"),
        // Sass — disagreement/attitude
        AnimationDescriptor(id: 10, name: "Frustrated", category: "Sass"),
        AnimationDescriptor(id: 14, name: "Short Circuit", category: "Sass"),
        AnimationDescriptor(id: 16, name: "No", category: "Sass"),
        AnimationDescriptor(id: 39, name: "Frustrated", category: "Sass"),
        AnimationDescriptor(id: 43, name: "Long Shake", category: "Sass"),
        AnimationDescriptor(id: 44, name: "No", category: "Sass"),
        AnimationDescriptor(id: 45, name: "Ominous", category: "Sass"),
        AnimationDescriptor(id: 49, name: "Shake", category: "Sass"),
        // Action — physical movement
        AnimationDescriptor(id: 11, name: "Drive", category: "Action"),
        AnimationDescriptor(id: 28, name: "Patrol Alarm", category: "Action"),
        AnimationDescriptor(id: 29, name: "Hit", category: "Action"),
        AnimationDescriptor(id: 30, name: "Patrolling", category: "Action"),
        AnimationDescriptor(id: 33, name: "Bow", category: "Action"),
        // Idle — resting states
        AnimationDescriptor(id: 25, name: "Idle 1", category: "Idle"),
        AnimationDescriptor(id: 26, name: "Idle 2", category: "Idle"),
        AnimationDescriptor(id: 27, name: "Idle 3", category: "Idle"),
    ]
    
    // MARK: - BB-9E Animations (49 total)
    // Categories: Happy, Angry, Scared, Curious, Sass, Action, Idle, Eye
    
    private static let bb9eAnimations: [AnimationDescriptor] = [
        // Happy — positive emotions
        AnimationDescriptor(id: 4, name: "Yes", category: "Happy"),
        AnimationDescriptor(id: 5, name: "Affirmative", category: "Happy"),
        AnimationDescriptor(id: 8, name: "Content", category: "Happy"),
        AnimationDescriptor(id: 9, name: "Excited", category: "Happy"),
        AnimationDescriptor(id: 11, name: "Greetings", category: "Happy"),
        AnimationDescriptor(id: 16, name: "Understood", category: "Happy"),
        AnimationDescriptor(id: 24, name: "Excited", category: "Happy"),
        AnimationDescriptor(id: 26, name: "Happy", category: "Happy"),
        AnimationDescriptor(id: 28, name: "Laugh", category: "Happy"),
        AnimationDescriptor(id: 32, name: "Relieved", category: "Happy"),
        AnimationDescriptor(id: 40, name: "Yoohoo", category: "Happy"),
        // Angry — aggressive/negative
        AnimationDescriptor(id: 0, name: "Alarm", category: "Angry"),
        AnimationDescriptor(id: 6, name: "Agitated", category: "Angry"),
        AnimationDescriptor(id: 7, name: "Angry", category: "Angry"),
        AnimationDescriptor(id: 10, name: "Fiery", category: "Angry"),
        AnimationDescriptor(id: 18, name: "Angry", category: "Angry"),
        AnimationDescriptor(id: 25, name: "Fiery", category: "Angry"),
        AnimationDescriptor(id: 37, name: "Taunting", category: "Angry"),
        AnimationDescriptor(id: 39, name: "Yelling", category: "Angry"),
        // Scared — fear/distress
        AnimationDescriptor(id: 3, name: "Scared", category: "Scared"),
        AnimationDescriptor(id: 12, name: "Nervous", category: "Scared"),
        AnimationDescriptor(id: 19, name: "Anxious", category: "Scared"),
        AnimationDescriptor(id: 27, name: "Jittery", category: "Scared"),
        AnimationDescriptor(id: 33, name: "Sad", category: "Scared"),
        AnimationDescriptor(id: 34, name: "Scared", category: "Scared"),
        // Curious — investigation/surprise
        AnimationDescriptor(id: 2, name: "Scan Sweep", category: "Curious"),
        AnimationDescriptor(id: 15, name: "Surprised", category: "Curious"),
        AnimationDescriptor(id: 22, name: "Curious", category: "Curious"),
        AnimationDescriptor(id: 23, name: "Double Take", category: "Curious"),
        AnimationDescriptor(id: 36, name: "Surprised", category: "Curious"),
        AnimationDescriptor(id: 38, name: "Whisper", category: "Curious"),
        // Sass — disagreement/attitude
        AnimationDescriptor(id: 1, name: "No", category: "Sass"),
        AnimationDescriptor(id: 29, name: "Long Shake", category: "Sass"),
        AnimationDescriptor(id: 30, name: "No", category: "Sass"),
        AnimationDescriptor(id: 31, name: "Ominous", category: "Sass"),
        AnimationDescriptor(id: 35, name: "Shake", category: "Sass"),
        AnimationDescriptor(id: 41, name: "Frustrated", category: "Sass"),
        // Action — physical movement
        AnimationDescriptor(id: 17, name: "Hit", category: "Action"),
        AnimationDescriptor(id: 20, name: "Bow", category: "Action"),
        // Idle — resting states
        AnimationDescriptor(id: 14, name: "Sleep", category: "Idle"),
        AnimationDescriptor(id: 42, name: "Idle 1", category: "Idle"),
        AnimationDescriptor(id: 43, name: "Idle 2", category: "Idle"),
        AnimationDescriptor(id: 44, name: "Idle 3", category: "Idle"),
        // Eye — BB-9E eye animations
        AnimationDescriptor(id: 45, name: "Eye 1", category: "Eye"),
        AnimationDescriptor(id: 46, name: "Eye 2", category: "Eye"),
        AnimationDescriptor(id: 47, name: "Eye 3", category: "Eye"),
        AnimationDescriptor(id: 48, name: "Eye 4", category: "Eye"),
    ]
    
    // MARK: - R2 Shared Sounds (219 entries — all R2_ prefixed sounds from spherov2.py Audio enum)
    
    /// Complete R2-series sound library with hardware-tested quality ratings.
    /// Both R2-D2 and R2-Q5 share this full set; per-droid ratings indicate
    /// how each sound actually plays on each hardware variant.
    private static let r2SharedSounds: [SoundDescriptor] = [
        // Test tones (7)
        SoundDescriptor(id: 1, name: "TEST_1497HZ", category: "Test", d2Rating: 9, q5Rating: 9),
        SoundDescriptor(id: 32, name: "TEST_200HZ", category: "Test", d2Rating: 0, q5Rating: 9),
        SoundDescriptor(id: 63, name: "TEST_2517HZ", category: "Test", d2Rating: 9, q5Rating: 9),
        SoundDescriptor(id: 94, name: "TEST_3581HZ", category: "Test", d2Rating: 9, q5Rating: 9),
        SoundDescriptor(id: 125, name: "TEST_431HZ", category: "Test", d2Rating: 9, q5Rating: 9),
        SoundDescriptor(id: 156, name: "TEST_6011HZ", category: "Test", d2Rating: 9, q5Rating: 9),
        SoundDescriptor(id: 187, name: "TEST_853HZ", category: "Test", d2Rating: 9, q5Rating: 9),
        // Mechanical — Fall / Hit / Step / Access Panels (19)
        SoundDescriptor(id: 1609, name: "R2_FALL", category: "Mechanical", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1623, name: "R2_HIT_1", category: "Mechanical", d2Rating: 1, q5Rating: 1),
        SoundDescriptor(id: 1628, name: "R2_HIT_10", category: "Mechanical", d2Rating: 1, q5Rating: 1),
        SoundDescriptor(id: 1635, name: "R2_HIT_11", category: "Mechanical", d2Rating: 1, q5Rating: 1),
        SoundDescriptor(id: 1642, name: "R2_HIT_2", category: "Mechanical", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1647, name: "R2_HIT_3", category: "Mechanical", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1653, name: "R2_HIT_4", category: "Mechanical", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1659, name: "R2_HIT_5", category: "Mechanical", d2Rating: 1, q5Rating: 1),
        SoundDescriptor(id: 1664, name: "R2_HIT_6", category: "Mechanical", d2Rating: 1, q5Rating: 1),
        SoundDescriptor(id: 1669, name: "R2_HIT_7", category: "Mechanical", d2Rating: 1, q5Rating: 1),
        SoundDescriptor(id: 1676, name: "R2_HIT_8", category: "Mechanical", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1684, name: "R2_HIT_9", category: "Mechanical", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1690, name: "R2_STEP_1", category: "Mechanical", d2Rating: 1, q5Rating: 1),
        SoundDescriptor(id: 1693, name: "R2_STEP_2", category: "Mechanical", d2Rating: 1, q5Rating: 1),
        SoundDescriptor(id: 1696, name: "R2_STEP_3", category: "Mechanical", d2Rating: 1, q5Rating: 1),
        SoundDescriptor(id: 1698, name: "R2_STEP_4", category: "Mechanical", d2Rating: 1, q5Rating: 1),
        SoundDescriptor(id: 1700, name: "R2_STEP_5", category: "Mechanical", d2Rating: 1, q5Rating: 1),
        SoundDescriptor(id: 1702, name: "R2_STEP_6", category: "Mechanical", d2Rating: 1, q5Rating: 1),
        SoundDescriptor(id: 1704, name: "R2_ACCESS_PANELS", category: "Mechanical", d2Rating: 3, q5Rating: 3),
        // Alarm (15)
        SoundDescriptor(id: 1737, name: "R2_ALARM_1", category: "Alarm", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1747, name: "R2_ALARM_10", category: "Alarm", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 1756, name: "R2_ALARM_12", category: "Alarm", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 1763, name: "R2_ALARM_13", category: "Alarm", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 1771, name: "R2_ALARM_14", category: "Alarm", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 1784, name: "R2_ALARM_15", category: "Alarm", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 1791, name: "R2_ALARM_16", category: "Alarm", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 1809, name: "R2_ALARM_2", category: "Alarm", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 1821, name: "R2_ALARM_3", category: "Alarm", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 1831, name: "R2_ALARM_4", category: "Alarm", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 1835, name: "R2_ALARM_5", category: "Alarm", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 1843, name: "R2_ALARM_6", category: "Alarm", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 1858, name: "R2_ALARM_7", category: "Alarm", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 1867, name: "R2_ALARM_8", category: "Alarm", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 1893, name: "R2_ALARM_9", category: "Alarm", d2Rating: 3, q5Rating: 1),
        // Emotion (5)
        SoundDescriptor(id: 1910, name: "R2_ANNOYED", category: "Emotion", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 1915, name: "R2_BURNOUT", category: "Emotion", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3797, name: "R2_SCREAM", category: "Emotion", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3810, name: "R2_SCREAM_2", category: "Emotion", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3825, name: "R2_SHORT_OUT", category: "Emotion", d2Rating: 3, q5Rating: 1),
        // Chatty (62)
        SoundDescriptor(id: 1950, name: "R2_CHATTY_1", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 1959, name: "R2_CHATTY_10", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 1966, name: "R2_CHATTY_11", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 1977, name: "R2_CHATTY_12", category: "Chatty", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1987, name: "R2_CHATTY_13", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2002, name: "R2_CHATTY_14", category: "Chatty", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 2007, name: "R2_CHATTY_15", category: "Chatty", d2Rating: 2, q5Rating: 3),
        SoundDescriptor(id: 2010, name: "R2_CHATTY_16", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2019, name: "R2_CHATTY_17", category: "Chatty", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 2028, name: "R2_CHATTY_18", category: "Chatty", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 2039, name: "R2_CHATTY_19", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2061, name: "R2_CHATTY_2", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2072, name: "R2_CHATTY_20", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2080, name: "R2_CHATTY_21", category: "Chatty", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 2085, name: "R2_CHATTY_22", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2095, name: "R2_CHATTY_23", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2105, name: "R2_CHATTY_24", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2121, name: "R2_CHATTY_25", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2132, name: "R2_CHATTY_26", category: "Chatty", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 2143, name: "R2_CHATTY_27", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2157, name: "R2_CHATTY_28", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2170, name: "R2_CHATTY_29", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2174, name: "R2_CHATTY_3", category: "Chatty", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 2184, name: "R2_CHATTY_30", category: "Chatty", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 2188, name: "R2_CHATTY_31", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2198, name: "R2_CHATTY_32", category: "Chatty", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 2202, name: "R2_CHATTY_33", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2211, name: "R2_CHATTY_34", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2221, name: "R2_CHATTY_35", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2232, name: "R2_CHATTY_36", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2241, name: "R2_CHATTY_37", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2253, name: "R2_CHATTY_38", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2264, name: "R2_CHATTY_39", category: "Chatty", d2Rating: 0, q5Rating: 0),
        SoundDescriptor(id: 2276, name: "R2_CHATTY_4", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2285, name: "R2_CHATTY_40", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2292, name: "R2_CHATTY_41", category: "Chatty", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 2307, name: "R2_CHATTY_42", category: "Chatty", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 2322, name: "R2_CHATTY_43", category: "Chatty", d2Rating: 3, q5Rating: 0),
        SoundDescriptor(id: 2332, name: "R2_CHATTY_44", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2344, name: "R2_CHATTY_45", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2357, name: "R2_CHATTY_46", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2368, name: "R2_CHATTY_47", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2377, name: "R2_CHATTY_48", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2387, name: "R2_CHATTY_49", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2399, name: "R2_CHATTY_5", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2413, name: "R2_CHATTY_50", category: "Chatty", d2Rating: 3, q5Rating: 0),
        SoundDescriptor(id: 2424, name: "R2_CHATTY_51", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2439, name: "R2_CHATTY_52", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2452, name: "R2_CHATTY_53", category: "Chatty", d2Rating: 3, q5Rating: 0),
        SoundDescriptor(id: 2457, name: "R2_CHATTY_54", category: "Chatty", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 2463, name: "R2_CHATTY_55", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2474, name: "R2_CHATTY_56", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2492, name: "R2_CHATTY_57", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2509, name: "R2_CHATTY_58", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2519, name: "R2_CHATTY_59", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2524, name: "R2_CHATTY_6", category: "Chatty", d2Rating: 3, q5Rating: 0),
        SoundDescriptor(id: 2535, name: "R2_CHATTY_60", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2543, name: "R2_CHATTY_61", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2554, name: "R2_CHATTY_62", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2562, name: "R2_CHATTY_7", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2572, name: "R2_CHATTY_8", category: "Chatty", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2579, name: "R2_CHATTY_9", category: "Chatty", d2Rating: 3, q5Rating: 1),
        // Special (3)
        SoundDescriptor(id: 2586, name: "R2_ENGAGE_HYPER_DRIVE", category: "Special", d2Rating: 3, q5Rating: 0),
        SoundDescriptor(id: 2797, name: "R2_HEAD_SPIN", category: "Special", d2Rating: 3, q5Rating: 3, isContextual: true),
        SoundDescriptor(id: 2970, name: "R2_MOTOR", category: "Special", d2Rating: 3, q5Rating: 1, isContextual: true),
        // Excited (16)
        SoundDescriptor(id: 2600, name: "R2_EXCITED_1", category: "Excited", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2615, name: "R2_EXCITED_10", category: "Excited", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2633, name: "R2_EXCITED_11", category: "Excited", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2644, name: "R2_EXCITED_12", category: "Excited", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2654, name: "R2_EXCITED_13", category: "Excited", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2662, name: "R2_EXCITED_14", category: "Excited", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2680, name: "R2_EXCITED_15", category: "Excited", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2691, name: "R2_EXCITED_16", category: "Excited", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2708, name: "R2_EXCITED_2", category: "Excited", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2726, name: "R2_EXCITED_3", category: "Excited", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 2730, name: "R2_EXCITED_4", category: "Excited", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2736, name: "R2_EXCITED_5", category: "Excited", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2753, name: "R2_EXCITED_6", category: "Excited", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2767, name: "R2_EXCITED_7", category: "Excited", d2Rating: 3, q5Rating: 0),
        SoundDescriptor(id: 2777, name: "R2_EXCITED_8", category: "Excited", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2787, name: "R2_EXCITED_9", category: "Excited", d2Rating: 3, q5Rating: 1),
        // Hey (12)
        SoundDescriptor(id: 2813, name: "R2_HEY_1", category: "Hey", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2824, name: "R2_HEY_10", category: "Hey", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2828, name: "R2_HEY_11", category: "Hey", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 2833, name: "R2_HEY_12", category: "Hey", d2Rating: 0, q5Rating: 1),
        SoundDescriptor(id: 2841, name: "R2_HEY_2", category: "Hey", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2856, name: "R2_HEY_3", category: "Hey", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2861, name: "R2_HEY_4", category: "Hey", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2882, name: "R2_HEY_5", category: "Hey", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 2893, name: "R2_HEY_6", category: "Hey", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2898, name: "R2_HEY_7", category: "Hey", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2904, name: "R2_HEY_8", category: "Hey", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2912, name: "R2_HEY_9", category: "Hey", d2Rating: 3, q5Rating: 1),
        // Laugh (4)
        SoundDescriptor(id: 2919, name: "R2_LAUGH_1", category: "Laugh", d2Rating: 3, q5Rating: 0),
        SoundDescriptor(id: 2935, name: "R2_LAUGH_2", category: "Laugh", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 2950, name: "R2_LAUGH_3", category: "Laugh", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 2955, name: "R2_LAUGH_4", category: "Laugh", d2Rating: 3, q5Rating: 1),
        // Negative (28)
        SoundDescriptor(id: 3101, name: "R2_NEGATIVE_1", category: "Negative", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3111, name: "R2_NEGATIVE_10", category: "Negative", d2Rating: 2, q5Rating: 0),
        SoundDescriptor(id: 3115, name: "R2_NEGATIVE_11", category: "Negative", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3121, name: "R2_NEGATIVE_12", category: "Negative", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3132, name: "R2_NEGATIVE_13", category: "Negative", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3136, name: "R2_NEGATIVE_14", category: "Negative", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3148, name: "R2_NEGATIVE_15", category: "Negative", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3152, name: "R2_NEGATIVE_16", category: "Negative", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3157, name: "R2_NEGATIVE_17", category: "Negative", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3164, name: "R2_NEGATIVE_18", category: "Negative", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3167, name: "R2_NEGATIVE_19", category: "Negative", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3172, name: "R2_NEGATIVE_2", category: "Negative", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 3178, name: "R2_NEGATIVE_20", category: "Negative", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3191, name: "R2_NEGATIVE_21", category: "Negative", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3200, name: "R2_NEGATIVE_22", category: "Negative", d2Rating: 3, q5Rating: 0),
        SoundDescriptor(id: 3213, name: "R2_NEGATIVE_23", category: "Negative", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3219, name: "R2_NEGATIVE_24", category: "Negative", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3226, name: "R2_NEGATIVE_25", category: "Negative", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3230, name: "R2_NEGATIVE_26", category: "Negative", d2Rating: 2, q5Rating: 3),
        SoundDescriptor(id: 3233, name: "R2_NEGATIVE_27", category: "Negative", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3241, name: "R2_NEGATIVE_28", category: "Negative", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3251, name: "R2_NEGATIVE_3", category: "Negative", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3258, name: "R2_NEGATIVE_4", category: "Negative", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3263, name: "R2_NEGATIVE_5", category: "Negative", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3268, name: "R2_NEGATIVE_6", category: "Negative", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3274, name: "R2_NEGATIVE_7", category: "Negative", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 3282, name: "R2_NEGATIVE_8", category: "Negative", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3291, name: "R2_NEGATIVE_9", category: "Negative", d2Rating: 3, q5Rating: 1),
        // Positive (23)
        SoundDescriptor(id: 3302, name: "R2_POSITIVE_1", category: "Positive", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3309, name: "R2_POSITIVE_10", category: "Positive", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3318, name: "R2_POSITIVE_11", category: "Positive", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3326, name: "R2_POSITIVE_12", category: "Positive", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3340, name: "R2_POSITIVE_13", category: "Positive", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3353, name: "R2_POSITIVE_14", category: "Positive", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3358, name: "R2_POSITIVE_15", category: "Positive", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3364, name: "R2_POSITIVE_16", category: "Positive", d2Rating: 2, q5Rating: 0),
        SoundDescriptor(id: 3369, name: "R2_POSITIVE_17", category: "Positive", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3375, name: "R2_POSITIVE_18", category: "Positive", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3388, name: "R2_POSITIVE_19", category: "Positive", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3394, name: "R2_POSITIVE_2", category: "Positive", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3403, name: "R2_POSITIVE_20", category: "Positive", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3410, name: "R2_POSITIVE_21", category: "Positive", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3422, name: "R2_POSITIVE_22", category: "Positive", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3434, name: "R2_POSITIVE_23", category: "Positive", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3439, name: "R2_POSITIVE_3", category: "Positive", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3446, name: "R2_POSITIVE_4", category: "Positive", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3449, name: "R2_POSITIVE_5", category: "Positive", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3454, name: "R2_POSITIVE_6", category: "Positive", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3460, name: "R2_POSITIVE_7", category: "Positive", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3471, name: "R2_POSITIVE_8", category: "Positive", d2Rating: 2, q5Rating: 1),
        SoundDescriptor(id: 3478, name: "R2_POSITIVE_9", category: "Positive", d2Rating: 2, q5Rating: 1),
        // Sad (25)
        SoundDescriptor(id: 3484, name: "R2_SAD_1", category: "Sad", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 3495, name: "R2_SAD_10", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3518, name: "R2_SAD_11", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3526, name: "R2_SAD_12", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3536, name: "R2_SAD_13", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3543, name: "R2_SAD_14", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3553, name: "R2_SAD_15", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3561, name: "R2_SAD_16", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3570, name: "R2_SAD_17", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3593, name: "R2_SAD_18", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3600, name: "R2_SAD_19", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3608, name: "R2_SAD_2", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3612, name: "R2_SAD_20", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3619, name: "R2_SAD_21", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3632, name: "R2_SAD_22", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3639, name: "R2_SAD_23", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3649, name: "R2_SAD_24", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3661, name: "R2_SAD_25", category: "Sad", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 3686, name: "R2_SAD_3", category: "Sad", d2Rating: 3, q5Rating: 0),
        SoundDescriptor(id: 3693, name: "R2_SAD_4", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3703, name: "R2_SAD_5", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3739, name: "R2_SAD_6", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3755, name: "R2_SAD_7", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3782, name: "R2_SAD_8", category: "Sad", d2Rating: 3, q5Rating: 1),
        SoundDescriptor(id: 3790, name: "R2_SAD_9", category: "Sad", d2Rating: 2, q5Rating: 1),
    ]
    
    // MARK: - R2-D2 Sounds
    
    /// R2-D2 gets the shared R2 sound library + BB-8 range sounds.
    private static let r2d2Sounds: [SoundDescriptor] = {
        var sounds = r2SharedSounds
        sounds.append(contentsOf: bb8RangeSounds)
        return sounds
    }()
    
    // MARK: - R2-Q5 Sounds (hardware-tested discovery)
    
    /// R2-Q5 core sound library (sounds outside BB-8 range) + BB-8 range sounds.
    /// Core sounds are from R2 address space (1600+), tested on Q5 hardware.
    private static let r2q5Sounds: [SoundDescriptor] = {
        var sounds = r2q5CoreSounds
        sounds.append(contentsOf: bb8RangeSounds)
        return sounds
    }()
    
    /// R2-Q5 core sounds — R2/Q5 address space only (IDs > 1600).
    /// All rated 2+ on Q5 hardware.
    private static let r2q5CoreSounds: [SoundDescriptor] = [
        // --- Positive (13) ---
        SoundDescriptor(id: 3307, name: "Q5_POSITIVE_11", category: "Positive", q5Rating: 3),
        SoundDescriptor(id: 3321, name: "Q5_POSITIVE_12", category: "Positive", q5Rating: 3),
        SoundDescriptor(id: 3335, name: "Q5_POSITIVE_13", category: "Positive", q5Rating: 3),
        SoundDescriptor(id: 3347, name: "Q5_POSITIVE_14", category: "Positive", q5Rating: 3),
        SoundDescriptor(id: 3365, name: "Q5_POSITIVE_15", category: "Positive", q5Rating: 3),
        SoundDescriptor(id: 3373, name: "Q5_POSITIVE_16", category: "Positive", q5Rating: 3),
        SoundDescriptor(id: 3387, name: "Q5_POSITIVE_17", category: "Positive", q5Rating: 3),
        SoundDescriptor(id: 3400, name: "Q5_POSITIVE_18", category: "Positive", q5Rating: 3),
        SoundDescriptor(id: 3412, name: "Q5_POSITIVE_19", category: "Positive", q5Rating: 3),
        SoundDescriptor(id: 3429, name: "Q5_POSITIVE_20", category: "Positive", q5Rating: 3),
        SoundDescriptor(id: 3441, name: "Q5_POSITIVE_21", category: "Positive", q5Rating: 3),
        SoundDescriptor(id: 3453, name: "Q5_POSITIVE_22", category: "Positive", q5Rating: 3),
        SoundDescriptor(id: 3469, name: "Q5_POSITIVE_23", category: "Positive", q5Rating: 3),
        // --- Negative (11) ---
        SoundDescriptor(id: 3112, name: "Q5_NEGATIVE_17", category: "Negative", q5Rating: 3),
        SoundDescriptor(id: 3130, name: "Q5_NEGATIVE_18", category: "Negative", q5Rating: 3),
        SoundDescriptor(id: 3145, name: "Q5_NEGATIVE_19", category: "Negative", q5Rating: 3),
        SoundDescriptor(id: 3151, name: "Q5_NEGATIVE_20", category: "Negative", q5Rating: 3),
        SoundDescriptor(id: 3188, name: "Q5_NEGATIVE_21", category: "Negative", q5Rating: 3),
        SoundDescriptor(id: 3201, name: "Q5_NEGATIVE_22", category: "Negative", q5Rating: 3),
        SoundDescriptor(id: 3216, name: "Q5_NEGATIVE_23", category: "Negative", q5Rating: 3),
        SoundDescriptor(id: 3243, name: "Q5_NEGATIVE_24", category: "Negative", q5Rating: 3),
        SoundDescriptor(id: 3255, name: "Q5_NEGATIVE_25", category: "Negative", q5Rating: 3),
        SoundDescriptor(id: 3274, name: "Q5_NEGATIVE_26", category: "Negative", q5Rating: 3),
        SoundDescriptor(id: 3290, name: "Q5_NEGATIVE_27", category: "Negative", q5Rating: 3),
        // --- Chatty (40 — R2 Chatty range hits) ---
        SoundDescriptor(id: 1954, name: "Q5_CHATTY_17", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 1965, name: "Q5_CHATTY_18", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 1977, name: "Q5_CHATTY_19", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 1992, name: "Q5_CHATTY_20", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2007, name: "Q5_CHATTY_21", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2019, name: "Q5_CHATTY_22", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2039, name: "Q5_CHATTY_23", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2052, name: "Q5_CHATTY_24", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2070, name: "Q5_CHATTY_25", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2082, name: "Q5_CHATTY_26", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2100, name: "Q5_CHATTY_27", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2115, name: "Q5_CHATTY_28", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2128, name: "Q5_CHATTY_29", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2142, name: "Q5_CHATTY_30", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2161, name: "Q5_CHATTY_31", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2174, name: "Q5_CHATTY_32", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2191, name: "Q5_CHATTY_33", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2208, name: "Q5_CHATTY_34", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2226, name: "Q5_CHATTY_35", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2240, name: "Q5_CHATTY_36", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2259, name: "Q5_CHATTY_37", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2275, name: "Q5_CHATTY_38", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2292, name: "Q5_CHATTY_39", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2307, name: "Q5_CHATTY_40", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2323, name: "Q5_CHATTY_41", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2336, name: "Q5_CHATTY_42", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2355, name: "Q5_CHATTY_43", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2370, name: "Q5_CHATTY_44", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2390, name: "Q5_CHATTY_45", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2410, name: "Q5_CHATTY_46", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2428, name: "Q5_CHATTY_47", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2441, name: "Q5_CHATTY_48", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2453, name: "Q5_CHATTY_49", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2465, name: "Q5_CHATTY_50", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2486, name: "Q5_CHATTY_51", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2505, name: "Q5_CHATTY_52", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2525, name: "Q5_CHATTY_53", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2538, name: "Q5_CHATTY_54", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2557, name: "Q5_CHATTY_55", category: "Chatty", q5Rating: 3),
        SoundDescriptor(id: 2569, name: "Q5_CHATTY_56", category: "Chatty", q5Rating: 3),
        // --- Sad (11 — from R2 Sad range) ---
        SoundDescriptor(id: 3497, name: "Q5_SAD_8", category: "Sad", q5Rating: 3),
        SoundDescriptor(id: 3515, name: "Q5_SAD_9", category: "Sad", q5Rating: 3),
        SoundDescriptor(id: 3534, name: "Q5_SAD_10", category: "Sad", q5Rating: 3),
        SoundDescriptor(id: 3547, name: "Q5_SAD_11", category: "Sad", q5Rating: 3),
        SoundDescriptor(id: 3567, name: "Q5_SAD_12", category: "Sad", q5Rating: 3),
        SoundDescriptor(id: 3585, name: "Q5_SAD_13", category: "Sad", q5Rating: 3),
        SoundDescriptor(id: 3606, name: "Q5_SAD_14", category: "Sad", q5Rating: 3),
        SoundDescriptor(id: 3624, name: "Q5_SAD_15", category: "Sad", q5Rating: 3),
        SoundDescriptor(id: 3637, name: "Q5_SAD_16", category: "Sad", q5Rating: 3),
        SoundDescriptor(id: 3646, name: "Q5_SAD_17", category: "Sad", q5Rating: 3),
        SoundDescriptor(id: 3687, name: "Q5_SAD_18", category: "Sad", q5Rating: 3),
        // --- Sad (from R2 Sad + Neg range, 3) ---
        SoundDescriptor(id: 3484, name: "Q5_SAD_R2_1", category: "Sad", q5Rating: 3),
        SoundDescriptor(id: 3661, name: "Q5_SAD_R2_2", category: "Sad", q5Rating: 3),
        SoundDescriptor(id: 3674, name: "Q5_SAD_R2_3", category: "Sad", q5Rating: 3),
        // --- Alert (1 — from R2 Sad range) ---
        SoundDescriptor(id: 3705, name: "Q5_ALERT_8", category: "Alert", q5Rating: 3),
        // --- Emotion (3 — from R2 Emotion range) ---
        SoundDescriptor(id: 3791, name: "Q5_EMOTION_5", category: "Emotion", q5Rating: 3),
        SoundDescriptor(id: 3808, name: "Q5_EMOTION_6", category: "Emotion", q5Rating: 3),
        SoundDescriptor(id: 3820, name: "Q5_EMOTION_7", category: "Emotion", q5Rating: 3),
        // --- Burnout (3 — from R2 Sad range) ---
        SoundDescriptor(id: 3719, name: "Q5_BURNOUT_3", category: "Burnout", q5Rating: 3),
        SoundDescriptor(id: 3748, name: "Q5_BURNOUT_4", category: "Burnout", q5Rating: 3),
        SoundDescriptor(id: 3767, name: "Q5_BURNOUT_5", category: "Burnout", q5Rating: 3),
        // --- Mechanical (from Q5 Named + R2 ranges) ---
        SoundDescriptor(id: 1609, name: "Q5_FALL", category: "Mechanical", q5Rating: 3),
        SoundDescriptor(id: 1623, name: "Q5_HIT_6", category: "Mechanical", q5Rating: 2),
        SoundDescriptor(id: 1628, name: "Q5_HIT_7", category: "Mechanical", q5Rating: 2),
        SoundDescriptor(id: 1635, name: "Q5_HIT_8", category: "Mechanical", q5Rating: 2),
        SoundDescriptor(id: 1642, name: "Q5_HIT_1", category: "Mechanical", q5Rating: 2),
        SoundDescriptor(id: 1647, name: "Q5_HIT_2", category: "Mechanical", q5Rating: 2),
        SoundDescriptor(id: 1653, name: "Q5_HIT_3", category: "Mechanical", q5Rating: 2),
        SoundDescriptor(id: 1659, name: "Q5_HIT_9", category: "Mechanical", q5Rating: 2),
        SoundDescriptor(id: 1664, name: "Q5_HIT_10", category: "Mechanical", q5Rating: 2),
        SoundDescriptor(id: 1669, name: "Q5_HIT_11", category: "Mechanical", q5Rating: 2),
        SoundDescriptor(id: 1676, name: "Q5_HIT_4", category: "Mechanical", q5Rating: 2),
        SoundDescriptor(id: 1684, name: "Q5_HIT_5", category: "Mechanical", q5Rating: 2),
        SoundDescriptor(id: 1704, name: "Q5_ACCESS_PANELS", category: "Mechanical", q5Rating: 3),
        SoundDescriptor(id: 1737, name: "Q5_MECHANICAL_1", category: "Mechanical", q5Rating: 3),
        SoundDescriptor(id: 1753, name: "Q5_MOTOR_SOUND", category: "Mechanical", q5Rating: 3),
        SoundDescriptor(id: 3868, name: "Q5_MECH_CRASH", category: "Mechanical", q5Rating: 3),
        // --- Alarm (from R2 Alarm range, 4) ---
        SoundDescriptor(id: 1796, name: "Q5_ALARM_1", category: "Alarm", q5Rating: 3),
        SoundDescriptor(id: 1884, name: "Q5_ALARM_2", category: "Alarm", q5Rating: 3),
        SoundDescriptor(id: 1892, name: "Q5_ALARM_3", category: "Alarm", q5Rating: 2),
        SoundDescriptor(id: 1898, name: "Q5_ALARM_4", category: "Alarm", q5Rating: 2),
        // --- Excited (13 — from R2 Excited range) ---
        SoundDescriptor(id: 2604, name: "Q5_EXCITED_1", category: "Excited", q5Rating: 3),
        SoundDescriptor(id: 2617, name: "Q5_EXCITED_2", category: "Excited", q5Rating: 3),
        SoundDescriptor(id: 2631, name: "Q5_EXCITED_3", category: "Excited", q5Rating: 3),
        SoundDescriptor(id: 2651, name: "Q5_EXCITED_4", category: "Excited", q5Rating: 3),
        SoundDescriptor(id: 2671, name: "Q5_EXCITED_5", category: "Excited", q5Rating: 3),
        SoundDescriptor(id: 2692, name: "Q5_EXCITED_6", category: "Excited", q5Rating: 3),
        SoundDescriptor(id: 2712, name: "Q5_EXCITED_7", category: "Excited", q5Rating: 3),
        SoundDescriptor(id: 2725, name: "Q5_EXCITED_8", category: "Excited", q5Rating: 3),
        SoundDescriptor(id: 2739, name: "Q5_EXCITED_9", category: "Excited", q5Rating: 3),
        SoundDescriptor(id: 2752, name: "Q5_EXCITED_10", category: "Excited", q5Rating: 3),
        SoundDescriptor(id: 2768, name: "Q5_EXCITED_11", category: "Excited", q5Rating: 3),
        SoundDescriptor(id: 2784, name: "Q5_EXCITED_12", category: "Excited", q5Rating: 3),
        SoundDescriptor(id: 2797, name: "Q5_EXCITED_13", category: "Excited", q5Rating: 3),
        // --- Hey (from R2 Hey range, 10) ---
        SoundDescriptor(id: 2816, name: "Q5_HEY_R2_1", category: "Hey", q5Rating: 3),
        SoundDescriptor(id: 2831, name: "Q5_HEY_R2_2", category: "Hey", q5Rating: 3),
        SoundDescriptor(id: 2843, name: "Q5_HEY_R2_3", category: "Hey", q5Rating: 3),
        SoundDescriptor(id: 2858, name: "Q5_HEY_R2_4", category: "Hey", q5Rating: 3),
        SoundDescriptor(id: 2871, name: "Q5_HEY_R2_5", category: "Hey", q5Rating: 3),
        SoundDescriptor(id: 2882, name: "Q5_HEY_R2_6", category: "Hey", q5Rating: 3),
        SoundDescriptor(id: 2902, name: "Q5_HEY_R2_7", category: "Hey", q5Rating: 3),
        SoundDescriptor(id: 2920, name: "Q5_HEY_R2_8", category: "Hey", q5Rating: 3),
        SoundDescriptor(id: 2940, name: "Q5_HEY_R2_9", category: "Hey", q5Rating: 3),
        SoundDescriptor(id: 2953, name: "Q5_HEY_R2_10", category: "Hey", q5Rating: 3),
        // --- Special (4 — Q5 Named/Extended, R2 Neg+Pos+Sad range) ---
        SoundDescriptor(id: 3172, name: "Q5_SPECIAL_1", category: "Special", q5Rating: 3),
        SoundDescriptor(id: 3779, name: "Q5_SPECIAL_2", category: "Special", q5Rating: 3),
        SoundDescriptor(id: 3928, name: "Q5_SPECIAL_3", category: "Special", q5Rating: 3),
        SoundDescriptor(id: 3946, name: "Q5_SPECIAL_4", category: "Special", q5Rating: 3),
    ]
    
    // MARK: - BB-8 Range Sounds (shared between D2 and Q5)
    
    /// Sounds from BB-8 address space (IDs 200-1600) that play rich audio
    /// on both R2-D2 and R2-Q5 hardware. Kept as a separate "BB-8" category
    /// so they don't mingle with each droid's core sound library.
    /// Discovered via Q5 hardware testing, confirmed working on D2.
    private static let bb8RangeSounds: [SoundDescriptor] = [
        SoundDescriptor(id: 218, name: "BB8_218", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 235, name: "BB8_235", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 254, name: "BB8_254", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 258, name: "BB8_258", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 264, name: "BB8_264", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 272, name: "BB8_272", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 279, name: "BB8_279", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 288, name: "BB8_288", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 296, name: "BB8_296", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 301, name: "BB8_301", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 309, name: "BB8_309", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 330, name: "BB8_330", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 352, name: "BB8_352", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 356, name: "BB8_356", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 360, name: "BB8_360", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 368, name: "BB8_368", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 375, name: "BB8_375", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 381, name: "BB8_381", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 390, name: "BB8_390", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 397, name: "BB8_397", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 404, name: "BB8_404", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 410, name: "BB8_410", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 417, name: "BB8_417", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 430, name: "BB8_430", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 464, name: "BB8_464", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 471, name: "BB8_471", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 477, name: "BB8_477", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 479, name: "BB8_479", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 492, name: "BB8_492", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 518, name: "BB8_518", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 525, name: "BB8_525", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 537, name: "BB8_537", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 539, name: "BB8_539", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 544, name: "BB8_544", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 557, name: "BB8_557", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 570, name: "BB8_570", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 577, name: "BB8_577", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 581, name: "BB8_581", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 587, name: "BB8_587", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 599, name: "BB8_599", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 606, name: "BB8_606", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 612, name: "BB8_612", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 622, name: "BB8_622", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 630, name: "BB8_630", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 644, name: "BB8_644", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 671, name: "BB8_671", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 682, name: "BB8_682", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 686, name: "BB8_686", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 690, name: "BB8_690", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 700, name: "BB8_700", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 724, name: "BB8_724", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 734, name: "BB8_734", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 743, name: "BB8_743", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 744, name: "BB8_744", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 747, name: "BB8_747", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 753, name: "BB8_753", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 757, name: "BB8_757", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 761, name: "BB8_761", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 764, name: "BB8_764", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 787, name: "BB8_787", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 792, name: "BB8_792", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 802, name: "BB8_802", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 813, name: "BB8_813", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 825, name: "BB8_825", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 831, name: "BB8_831", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 836, name: "BB8_836", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 859, name: "BB8_859", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 867, name: "BB8_867", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 874, name: "BB8_874", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 888, name: "BB8_888", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 896, name: "BB8_896", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 902, name: "BB8_902", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 916, name: "BB8_916", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 927, name: "BB8_927", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 935, name: "BB8_935", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 946, name: "BB8_946", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 953, name: "BB8_953", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 963, name: "BB8_963", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 969, name: "BB8_969", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 983, name: "BB8_983", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 988, name: "BB8_988", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 998, name: "BB8_998", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1003, name: "BB8_1003", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1010, name: "BB8_1010", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1020, name: "BB8_1020", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1032, name: "BB8_1032", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1040, name: "BB8_1040", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1052, name: "BB8_1052", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1064, name: "BB8_1064", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1077, name: "BB8_1077", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1082, name: "BB8_1082", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1087, name: "BB8_1087", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1092, name: "BB8_1092", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1096, name: "BB8_1096", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1102, name: "BB8_1102", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1109, name: "BB8_1109", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1113, name: "BB8_1113", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1118, name: "BB8_1118", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1123, name: "BB8_1123", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1130, name: "BB8_1130", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1135, name: "BB8_1135", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1138, name: "BB8_1138", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1150, name: "BB8_1150", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1157, name: "BB8_1157", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1163, name: "BB8_1163", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1170, name: "BB8_1170", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1178, name: "BB8_1178", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1186, name: "BB8_1186", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1192, name: "BB8_1192", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1199, name: "BB8_1199", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1205, name: "BB8_1205", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1213, name: "BB8_1213", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1220, name: "BB8_1220", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1230, name: "BB8_1230", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1250, name: "BB8_1250", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1275, name: "BB8_1275", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1281, name: "BB8_1281", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1295, name: "BB8_1295", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1308, name: "BB8_1308", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1324, name: "BB8_1324", category: "BB-8", d2Rating: 2, q5Rating: 2),
        SoundDescriptor(id: 1329, name: "BB8_1329", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1347, name: "BB8_1347", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1363, name: "BB8_1363", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1375, name: "BB8_1375", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1384, name: "BB8_1384", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1394, name: "BB8_1394", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1408, name: "BB8_1408", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1432, name: "BB8_1432", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1442, name: "BB8_1442", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1463, name: "BB8_1463", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1476, name: "BB8_1476", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1486, name: "BB8_1486", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1494, name: "BB8_1494", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1505, name: "BB8_1505", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1516, name: "BB8_1516", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1523, name: "BB8_1523", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1531, name: "BB8_1531", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1549, name: "BB8_1549", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1558, name: "BB8_1558", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1583, name: "BB8_1583", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1592, name: "BB8_1592", category: "BB-8", d2Rating: 3, q5Rating: 3),
        SoundDescriptor(id: 1600, name: "BB8_1600", category: "BB-8", d2Rating: 3, q5Rating: 3),
    ]
    
    // MARK: - BB-9E Sounds (curated selection)
    
    /// BB-9E sounds from the BB9E range of the shared Audio enum.
    // MARK: - BB-8 Sounds (Sphero-authored, played via R2-D2 proxy)
    //
    // BB-8 has no speaker; the DroidParty app routes these IDs through the
    // connected R2-D2's CapabilityController. Categorized to match the same
    // Alarm/Chatty/Excited/Hey/Laugh/Negative/Positive/Sad buckets the R2
    // catalog uses so the same button grid works.

    private static let bb8Sounds: [SoundDescriptor] = [
        // Alarm (11 IDs)
        SoundDescriptor(id: 218,  name: "Alarm 1",  category: "Alarm"),
        SoundDescriptor(id: 235,  name: "Alarm 10", category: "Alarm"),
        SoundDescriptor(id: 254,  name: "Alarm 11", category: "Alarm"),
        SoundDescriptor(id: 258,  name: "Alarm 12", category: "Alarm"),
        SoundDescriptor(id: 264,  name: "Alarm 2",  category: "Alarm"),
        SoundDescriptor(id: 268,  name: "Alarm 3",  category: "Alarm"),
        SoundDescriptor(id: 272,  name: "Alarm 4",  category: "Alarm"),
        SoundDescriptor(id: 279,  name: "Alarm 6",  category: "Alarm"),
        SoundDescriptor(id: 288,  name: "Alarm 7",  category: "Alarm"),
        SoundDescriptor(id: 296,  name: "Alarm 8",  category: "Alarm"),
        SoundDescriptor(id: 301,  name: "Alarm 9",  category: "Alarm"),
        // Boot-up (grouped under Excited so it surfaces on the "wake me up" button)
        SoundDescriptor(id: 309,  name: "Boot Up",   category: "Excited"),
        SoundDescriptor(id: 330,  name: "Boot Up 2", category: "Excited"),
        // Chatty (28 IDs)
        SoundDescriptor(id: 352,  name: "Chatty 1",  category: "Chatty"),
        SoundDescriptor(id: 356,  name: "Chatty 10", category: "Chatty"),
        SoundDescriptor(id: 360,  name: "Chatty 11", category: "Chatty"),
        SoundDescriptor(id: 368,  name: "Chatty 12", category: "Chatty"),
        SoundDescriptor(id: 375,  name: "Chatty 13", category: "Chatty"),
        SoundDescriptor(id: 381,  name: "Chatty 14", category: "Chatty"),
        SoundDescriptor(id: 390,  name: "Chatty 15", category: "Chatty"),
        SoundDescriptor(id: 397,  name: "Chatty 16", category: "Chatty"),
        SoundDescriptor(id: 404,  name: "Chatty 17", category: "Chatty"),
        SoundDescriptor(id: 410,  name: "Chatty 18", category: "Chatty"),
        SoundDescriptor(id: 417,  name: "Chatty 19", category: "Chatty"),
        SoundDescriptor(id: 430,  name: "Chatty 2",  category: "Chatty"),
        SoundDescriptor(id: 464,  name: "Chatty 20", category: "Chatty"),
        SoundDescriptor(id: 471,  name: "Chatty 22", category: "Chatty"),
        SoundDescriptor(id: 479,  name: "Chatty 23", category: "Chatty"),
        SoundDescriptor(id: 492,  name: "Chatty 24", category: "Chatty"),
        SoundDescriptor(id: 518,  name: "Chatty 25", category: "Chatty"),
        SoundDescriptor(id: 525,  name: "Chatty 26", category: "Chatty"),
        SoundDescriptor(id: 537,  name: "Chatty 27", category: "Chatty"),
        SoundDescriptor(id: 544,  name: "Chatty 3",  category: "Chatty"),
        SoundDescriptor(id: 557,  name: "Chatty 4",  category: "Chatty"),
        SoundDescriptor(id: 570,  name: "Chatty 5",  category: "Chatty"),
        SoundDescriptor(id: 577,  name: "Chatty 6",  category: "Chatty"),
        SoundDescriptor(id: 581,  name: "Chatty 7",  category: "Chatty"),
        SoundDescriptor(id: 587,  name: "Chatty 8",  category: "Chatty"),
        SoundDescriptor(id: 599,  name: "Chatty 9",  category: "Chatty"),
        // Misc chatty-flavored (grouped under Chatty)
        SoundDescriptor(id: 606,  name: "Don't Know", category: "Chatty"),
        SoundDescriptor(id: 1308, name: "Shortcut",   category: "Chatty"),
        // Excited (4 IDs + Wow)
        SoundDescriptor(id: 612,  name: "Excited 1", category: "Excited"),
        SoundDescriptor(id: 622,  name: "Excited 2", category: "Excited"),
        SoundDescriptor(id: 630,  name: "Excited 3", category: "Excited"),
        SoundDescriptor(id: 644,  name: "Excited 4", category: "Excited"),
        SoundDescriptor(id: 1324, name: "Wow",       category: "Excited"),
        // Hey (13 IDs)
        SoundDescriptor(id: 671,  name: "Hey 1",  category: "Hey"),
        SoundDescriptor(id: 682,  name: "Hey 10", category: "Hey"),
        SoundDescriptor(id: 686,  name: "Hey 11", category: "Hey"),
        SoundDescriptor(id: 690,  name: "Hey 12", category: "Hey"),
        SoundDescriptor(id: 700,  name: "Hey 13", category: "Hey"),
        SoundDescriptor(id: 724,  name: "Hey 2",  category: "Hey"),
        SoundDescriptor(id: 732,  name: "Hey 3",  category: "Hey"),
        SoundDescriptor(id: 734,  name: "Hey 4",  category: "Hey"),
        SoundDescriptor(id: 739,  name: "Hey 5",  category: "Hey"),
        SoundDescriptor(id: 743,  name: "Hey 6",  category: "Hey"),
        SoundDescriptor(id: 747,  name: "Hey 7",  category: "Hey"),
        SoundDescriptor(id: 753,  name: "Hey 8",  category: "Hey"),
        SoundDescriptor(id: 757,  name: "Hey 9",  category: "Hey"),
        // Laugh (2)
        SoundDescriptor(id: 761,  name: "Laugh 1", category: "Laugh"),
        SoundDescriptor(id: 764,  name: "Laugh 2", category: "Laugh"),
        // Negative (30 IDs)
        SoundDescriptor(id: 787,  name: "Negative 1",  category: "Negative"),
        SoundDescriptor(id: 792,  name: "Negative 10", category: "Negative"),
        SoundDescriptor(id: 802,  name: "Negative 11", category: "Negative"),
        SoundDescriptor(id: 813,  name: "Negative 12", category: "Negative"),
        SoundDescriptor(id: 825,  name: "Negative 13", category: "Negative"),
        SoundDescriptor(id: 831,  name: "Negative 14", category: "Negative"),
        SoundDescriptor(id: 836,  name: "Negative 15", category: "Negative"),
        SoundDescriptor(id: 859,  name: "Negative 16", category: "Negative"),
        SoundDescriptor(id: 867,  name: "Negative 17", category: "Negative"),
        SoundDescriptor(id: 874,  name: "Negative 18", category: "Negative"),
        SoundDescriptor(id: 888,  name: "Negative 19", category: "Negative"),
        SoundDescriptor(id: 896,  name: "Negative 2",  category: "Negative"),
        SoundDescriptor(id: 902,  name: "Negative 20", category: "Negative"),
        SoundDescriptor(id: 916,  name: "Negative 21", category: "Negative"),
        SoundDescriptor(id: 927,  name: "Negative 22", category: "Negative"),
        SoundDescriptor(id: 935,  name: "Negative 23", category: "Negative"),
        SoundDescriptor(id: 946,  name: "Negative 24", category: "Negative"),
        SoundDescriptor(id: 953,  name: "Negative 25", category: "Negative"),
        SoundDescriptor(id: 963,  name: "Negative 26", category: "Negative"),
        SoundDescriptor(id: 969,  name: "Negative 27", category: "Negative"),
        SoundDescriptor(id: 983,  name: "Negative 28", category: "Negative"),
        SoundDescriptor(id: 988,  name: "Negative 29", category: "Negative"),
        SoundDescriptor(id: 998,  name: "Negative 3",  category: "Negative"),
        SoundDescriptor(id: 1003, name: "Negative 30", category: "Negative"),
        SoundDescriptor(id: 1010, name: "Negative 4",  category: "Negative"),
        SoundDescriptor(id: 1020, name: "Negative 5",  category: "Negative"),
        SoundDescriptor(id: 1032, name: "Negative 6",  category: "Negative"),
        SoundDescriptor(id: 1040, name: "Negative 7",  category: "Negative"),
        SoundDescriptor(id: 1052, name: "Negative 8",  category: "Negative"),
        SoundDescriptor(id: 1064, name: "Negative 9",  category: "Negative"),
        // Positive (16)
        SoundDescriptor(id: 1077, name: "Positive 1",  category: "Positive"),
        SoundDescriptor(id: 1082, name: "Positive 10", category: "Positive"),
        SoundDescriptor(id: 1087, name: "Positive 11", category: "Positive"),
        SoundDescriptor(id: 1092, name: "Positive 12", category: "Positive"),
        SoundDescriptor(id: 1096, name: "Positive 13", category: "Positive"),
        SoundDescriptor(id: 1102, name: "Positive 14", category: "Positive"),
        SoundDescriptor(id: 1109, name: "Positive 15", category: "Positive"),
        SoundDescriptor(id: 1113, name: "Positive 16", category: "Positive"),
        SoundDescriptor(id: 1118, name: "Positive 2",  category: "Positive"),
        SoundDescriptor(id: 1123, name: "Positive 3",  category: "Positive"),
        SoundDescriptor(id: 1130, name: "Positive 4",  category: "Positive"),
        SoundDescriptor(id: 1135, name: "Positive 5",  category: "Positive"),
        SoundDescriptor(id: 1138, name: "Positive 6",  category: "Positive"),
        SoundDescriptor(id: 1147, name: "Positive 7",  category: "Positive"),
        SoundDescriptor(id: 1150, name: "Positive 8",  category: "Positive"),
        SoundDescriptor(id: 1157, name: "Positive 9",  category: "Positive"),
        // Sad (18)
        SoundDescriptor(id: 1163, name: "Sad 1",  category: "Sad"),
        SoundDescriptor(id: 1170, name: "Sad 10", category: "Sad"),
        SoundDescriptor(id: 1178, name: "Sad 11", category: "Sad"),
        SoundDescriptor(id: 1186, name: "Sad 12", category: "Sad"),
        SoundDescriptor(id: 1192, name: "Sad 13", category: "Sad"),
        SoundDescriptor(id: 1199, name: "Sad 14", category: "Sad"),
        SoundDescriptor(id: 1205, name: "Sad 15", category: "Sad"),
        SoundDescriptor(id: 1213, name: "Sad 16", category: "Sad"),
        SoundDescriptor(id: 1220, name: "Sad 17", category: "Sad"),
        SoundDescriptor(id: 1230, name: "Sad 18", category: "Sad"),
        SoundDescriptor(id: 1236, name: "Sad 2",  category: "Sad"),
        SoundDescriptor(id: 1240, name: "Sad 3",  category: "Sad"),
        SoundDescriptor(id: 1250, name: "Sad 4",  category: "Sad"),
        SoundDescriptor(id: 1268, name: "Sad 5",  category: "Sad"),
        SoundDescriptor(id: 1275, name: "Sad 6",  category: "Sad"),
        SoundDescriptor(id: 1281, name: "Sad 7",  category: "Sad"),
        SoundDescriptor(id: 1295, name: "Sad 8",  category: "Sad"),
        SoundDescriptor(id: 1303, name: "Sad 9",  category: "Sad"),
    ]

    // MARK: - BB-9E Sounds (Sphero-authored, played via R2-Q5 proxy)
    //
    // BB-9E's Sphero library is much smaller than BB-8's (~22 sounds vs 133).
    // Same category conventions; routed through R2-Q5.

    private static let bb9eSounds: [SoundDescriptor] = [
        // Alarm (5)
        SoundDescriptor(id: 1329, name: "Alarm 1", category: "Alarm"),
        SoundDescriptor(id: 1347, name: "Alarm 2", category: "Alarm"),
        SoundDescriptor(id: 1363, name: "Alarm 3", category: "Alarm"),
        SoundDescriptor(id: 1375, name: "Alarm 4", category: "Alarm"),
        SoundDescriptor(id: 1384, name: "Alarm 5", category: "Alarm"),
        // Chatty (2)
        SoundDescriptor(id: 1394, name: "Chatty 1", category: "Chatty"),
        SoundDescriptor(id: 1408, name: "Chatty 2", category: "Chatty"),
        // Excited (3)
        SoundDescriptor(id: 1432, name: "Excited 1", category: "Excited"),
        SoundDescriptor(id: 1442, name: "Excited 2", category: "Excited"),
        SoundDescriptor(id: 1463, name: "Excited 3", category: "Excited"),
        // Hey (2)
        SoundDescriptor(id: 1476, name: "Hey 1", category: "Hey"),
        SoundDescriptor(id: 1486, name: "Hey 2", category: "Hey"),
        // Negative (4)
        SoundDescriptor(id: 1494, name: "Negative 1", category: "Negative"),
        SoundDescriptor(id: 1505, name: "Negative 2", category: "Negative"),
        SoundDescriptor(id: 1516, name: "Negative 3", category: "Negative"),
        SoundDescriptor(id: 1523, name: "Negative 4", category: "Negative"),
        // Positive (5)
        SoundDescriptor(id: 1531, name: "Positive 1", category: "Positive"),
        SoundDescriptor(id: 1549, name: "Positive 2", category: "Positive"),
        SoundDescriptor(id: 1558, name: "Positive 3", category: "Positive"),
        SoundDescriptor(id: 1571, name: "Positive 4", category: "Positive"),
        SoundDescriptor(id: 1583, name: "Positive 5", category: "Positive"),
        // Sad (2)
        SoundDescriptor(id: 1592, name: "Sad 1", category: "Sad"),
        SoundDescriptor(id: 1600, name: "Sad 2", category: "Sad"),
    ]
    
    // MARK: - Animation Categories
    
    /// Returns sorted unique category names for a droid's animations.
    static func animationCategories(for droidType: DroidType) -> [String] {
        let anims = animations(for: droidType)
        return Array(Set(anims.map(\.category))).sorted()
    }
    
    /// Returns animation categories suitable for the Operate screen
    /// (excludes System, Idle, and Eye which are not useful for interactive play).
    static func operateAnimationCategories(for droidType: DroidType) -> [String] {
        let anims = animations(for: droidType)
        let excluded: Set<String> = ["System", "Idle", "Eye"]
        let cats = Set(anims.map(\.category)).subtracting(excluded)
        // Return in a fixed display order rather than alphabetical
        return AnimationBank.operateCategories.filter { cats.contains($0) }
    }
    
    /// Returns sorted unique category names for a droid's sounds (all categories).
    static func soundCategories(for droidType: DroidType) -> [String] {
        let snds = sounds(for: droidType)
        return Array(Set(snds.map(\.category))).sorted()
    }
    
    /// Returns categories suitable for the Operate screen (excludes Test and Special).
    ///
    /// R-series droids (R2-D2, R2-Q5) also expose a "BB-8" sound category
    /// that lives inside their own catalog — those BB-flavored sounds are
    /// intentionally exposed on the BB-series tabs (which proxy through
    /// the matching R-series speaker) rather than on the R-series tabs.
    static func operateSoundCategories(for droidType: DroidType) -> [String] {
        let snds = sounds(for: droidType)
        var excluded: Set<String> = ["Test", "Special"]
        if droidType == .r2d2 || droidType == .r2q5 {
            excluded.insert("BB-8")
        }
        return Array(Set(snds.map(\.category)).subtracting(excluded)).sorted()
    }
}

// MARK: - Sound Bank

/// Smart sound selection based on hardware-tested quality ratings.
///
/// Selects sounds for the Operate screen category buttons:
/// - Prefers level 3 (rich) sounds when available
/// - Falls back to level 2 (short) sounds
/// - Excludes silent (0), test-only (9), and contextual sounds
enum SoundBank {
    
    /// Sound categories available on the Operate screen.
    /// These are the user-facing emotion/mood categories.
    static let operateCategories = ["BB-8", "Mechanical", "Alarm", "Alert", "Burnout", "Chatty", "Emotion", "Excited", "Hey", "Laugh", "Negative", "Positive", "Sad"]
    
    /// Returns a random sound from the given category for the given droid.
    /// Only considers sounds rated 2 (short) or 3 (rich). Prefers level 3.
    /// Returns nil if no playable sounds exist.
    static func randomSound(category: String, for droidType: DroidType) -> SoundDescriptor? {
        let all = CapabilityRegistry.sounds(for: droidType)
            .filter { $0.category == category && !$0.isContextual && $0.rating(for: droidType) >= 2 && $0.rating(for: droidType) < 9 }
        
        let level3 = all.filter { $0.rating(for: droidType) == 3 }
        if !level3.isEmpty { return level3.randomElement() }
        
        return all.randomElement()
    }
    
    /// Returns true if a category has any playable sounds (rating 2+) for a droid.
    static func hasPlayableSounds(category: String, for droidType: DroidType) -> Bool {
        CapabilityRegistry.sounds(for: droidType)
            .contains { $0.category == category && !$0.isContextual && $0.rating(for: droidType) >= 2 }
    }
    
    /// The motor sound ID (contextual — played while driving R2-series droids).
    static let motorSoundID: UInt16 = 2970
    
    /// The head spin sound ID (contextual — played when moving the R2-series dome).
    static let headSpinSoundID: UInt16 = 2797
}

// MARK: - Animation Bank

/// Smart animation selection for the Operate screen category buttons.
enum AnimationBank {
    
    /// Animation categories available on the Operate screen, in display order.
    static let operateCategories = ["Happy", "Angry", "Scared", "Curious", "Sass", "Action"]
    
    /// Returns a random animation from the given category for the given droid.
    /// Returns nil if no animations exist for that category.
    static func randomAnimation(category: String, for droidType: DroidType) -> AnimationDescriptor? {
        CapabilityRegistry.animations(for: droidType)
            .filter { $0.category == category }
            .randomElement()
    }
    
    /// Returns true if a category has any animations for a droid.
    static func hasAnimations(category: String, for droidType: DroidType) -> Bool {
        CapabilityRegistry.animations(for: droidType)
            .contains { $0.category == category }
    }
}
