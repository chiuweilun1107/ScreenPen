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
