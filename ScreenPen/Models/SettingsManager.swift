import Cocoa

class SettingsManager {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    // MARK: - Keys
    private enum Key: String {
        case defaultColor
        case defaultLineWidth
        case defaultTool
        case globalHotkeyModifier
        case globalHotkeyKeyCode
        case launchAtLogin
        case fadeDuration
        case spotlightRadius
    }

    // MARK: - Properties

    var defaultColor: NSColor {
        get {
            let index = defaults.integer(forKey: Key.defaultColor.rawValue)
            return Self.colorOptions[safe: index] ?? .systemRed
        }
        set {
            let index = Self.colorOptions.firstIndex(of: newValue) ?? 0
            defaults.set(index, forKey: Key.defaultColor.rawValue)
        }
    }

    var defaultLineWidth: CGFloat {
        get { CGFloat(defaults.float(forKey: Key.defaultLineWidth.rawValue)).clamped(to: 1...20) }
        set { defaults.set(Float(newValue), forKey: Key.defaultLineWidth.rawValue) }
    }

    var defaultTool: DrawingTool {
        get {
            guard let raw = defaults.string(forKey: Key.defaultTool.rawValue),
                  let tool = DrawingTool(rawValue: raw) else { return .pen }
            return tool
        }
        set { defaults.set(newValue.rawValue, forKey: Key.defaultTool.rawValue) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin.rawValue) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin.rawValue) }
    }

    var fadeDuration: TimeInterval {
        get {
            let val = defaults.double(forKey: Key.fadeDuration.rawValue)
            return val > 0 ? val : 2.0
        }
        set { defaults.set(newValue, forKey: Key.fadeDuration.rawValue) }
    }

    var spotlightRadius: CGFloat {
        get {
            let val = CGFloat(defaults.float(forKey: Key.spotlightRadius.rawValue))
            return val > 0 ? val : 60.0
        }
        set { defaults.set(Float(newValue), forKey: Key.spotlightRadius.rawValue) }
    }

    // MARK: - Custom Shortcuts

    /// All configurable shortcut actions with their default keyCodes
    enum ShortcutAction: String, CaseIterable {
        case pen, arrow, line, rectangle, circle, highlighter, text, eraser
        case screenshot, interactive, spotlight, boardMode, fadeToggle
        case color1, color2, color3, color4, color5
        case widthDown, widthUp

        var displayName: String {
            switch self {
            case .pen: return "Pen"
            case .arrow: return "Arrow"
            case .line: return "Line"
            case .rectangle: return "Rectangle"
            case .circle: return "Circle"
            case .highlighter: return "Highlighter"
            case .text: return "Text"
            case .eraser: return "Eraser"
            case .screenshot: return "Screenshot"
            case .interactive: return "Interactive"
            case .spotlight: return "Spotlight"
            case .boardMode: return "Board Mode"
            case .fadeToggle: return "Fade Toggle"
            case .color1: return "Color: Red"
            case .color2: return "Color: Orange"
            case .color3: return "Color: Yellow"
            case .color4: return "Color: Green"
            case .color5: return "Color: Blue"
            case .widthDown: return "Width -"
            case .widthUp: return "Width +"
            }
        }

        var defaultKeyCode: UInt16 {
            switch self {
            case .pen: return 3          // F
            case .arrow: return 0        // A
            case .line: return 37        // L
            case .rectangle: return 15   // R
            case .circle: return 8       // C
            case .highlighter: return 4  // H
            case .text: return 17        // T
            case .eraser: return 14      // E
            case .screenshot: return 1   // S
            case .interactive: return 34 // I
            case .spotlight: return 40   // K
            case .boardMode: return 13   // W
            case .fadeToggle: return 49  // Space
            case .color1: return 18      // 1
            case .color2: return 19      // 2
            case .color3: return 20      // 3
            case .color4: return 21      // 4
            case .color5: return 23      // 5
            case .widthDown: return 33   // [
            case .widthUp: return 30     // ]
            }
        }
    }

    func keyCode(for action: ShortcutAction) -> UInt16 {
        let val = defaults.object(forKey: "shortcut_\(action.rawValue)") as? Int
        return UInt16(val ?? Int(action.defaultKeyCode))
    }

    func setKeyCode(_ code: UInt16, for action: ShortcutAction) {
        defaults.set(Int(code), forKey: "shortcut_\(action.rawValue)")
    }

    func resetShortcut(for action: ShortcutAction) {
        defaults.removeObject(forKey: "shortcut_\(action.rawValue)")
    }

    func resetAllShortcuts() {
        for action in ShortcutAction.allCases {
            defaults.removeObject(forKey: "shortcut_\(action.rawValue)")
        }
    }

    /// Build a reverse lookup: keyCode → action
    func shortcutMap() -> [UInt16: ShortcutAction] {
        var map: [UInt16: ShortcutAction] = [:]
        for action in ShortcutAction.allCases {
            map[keyCode(for: action)] = action
        }
        return map
    }

    /// Convert keyCode to human-readable string
    static func keyName(for keyCode: UInt16) -> String {
        let names: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 49: "Space", 50: "`",
        ]
        return names[keyCode] ?? "Key\(keyCode)"
    }

    // MARK: - Color Options

    static let colorOptions: [NSColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue,
        .white, .black, .systemPurple, .systemPink, .systemTeal
    ]

    static let colorNames: [String] = [
        "Red", "Orange", "Yellow", "Green", "Blue",
        "White", "Black", "Purple", "Pink", "Teal"
    ]

    private init() {
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Key.defaultColor.rawValue: 0,
            Key.defaultLineWidth.rawValue: Float(3.0),
            Key.defaultTool.rawValue: DrawingTool.pen.rawValue,
            Key.launchAtLogin.rawValue: false,
            Key.fadeDuration.rawValue: 2.0,
            Key.spotlightRadius.rawValue: Float(60.0),
        ])
    }
}

// MARK: - Helpers

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
