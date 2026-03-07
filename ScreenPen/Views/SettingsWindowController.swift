import Cocoa

class SettingsWindowController: NSWindowController, NSWindowDelegate {

    static var shared: SettingsWindowController?

    static func show() {
        if shared == nil {
            shared = SettingsWindowController()
        }
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ScreenPen Settings"
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        window.delegate = self
        window.contentView = buildSettingsView()
    }

    func windowWillClose(_ notification: Notification) {
        SettingsWindowController.shared = nil
    }

    // MARK: - Build UI

    private func buildSettingsView() -> NSView {
        let settings = SettingsManager.shared
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 380))

        var y: CGFloat = 340

        // Title
        let title = makeLabel("ScreenPen Settings", bold: true, size: 16)
        title.frame = NSRect(x: 20, y: y, width: 380, height: 24)
        container.addSubview(title)
        y -= 40

        // Default Tool
        let toolLabel = makeLabel("Default Tool:")
        toolLabel.frame = NSRect(x: 20, y: y, width: 120, height: 22)
        container.addSubview(toolLabel)

        let toolPopup = NSPopUpButton(frame: NSRect(x: 150, y: y, width: 200, height: 24))
        let tools: [DrawingTool] = [.pen, .arrow, .line, .rectangle, .circle, .highlighter]
        for tool in tools { toolPopup.addItem(withTitle: tool.rawValue) }
        toolPopup.selectItem(withTitle: settings.defaultTool.rawValue)
        toolPopup.target = self
        toolPopup.action = #selector(toolChanged(_:))
        container.addSubview(toolPopup)
        y -= 36

        // Default Color
        let colorLabel = makeLabel("Default Color:")
        colorLabel.frame = NSRect(x: 20, y: y, width: 120, height: 22)
        container.addSubview(colorLabel)

        let colorPopup = NSPopUpButton(frame: NSRect(x: 150, y: y, width: 200, height: 24))
        for name in SettingsManager.colorNames { colorPopup.addItem(withTitle: name) }
        let colorIndex = SettingsManager.colorOptions.firstIndex(of: settings.defaultColor) ?? 0
        colorPopup.selectItem(at: colorIndex)
        colorPopup.target = self
        colorPopup.action = #selector(colorChanged(_:))
        container.addSubview(colorPopup)
        y -= 36

        // Line Width
        let widthLabel = makeLabel("Line Width:")
        widthLabel.frame = NSRect(x: 20, y: y, width: 120, height: 22)
        container.addSubview(widthLabel)

        let widthSlider = NSSlider(frame: NSRect(x: 150, y: y, width: 170, height: 22))
        widthSlider.minValue = 1
        widthSlider.maxValue = 20
        widthSlider.doubleValue = Double(settings.defaultLineWidth)
        widthSlider.target = self
        widthSlider.action = #selector(widthChanged(_:))
        container.addSubview(widthSlider)

        let widthValue = makeLabel("\(Int(settings.defaultLineWidth))")
        widthValue.frame = NSRect(x: 330, y: y, width: 40, height: 22)
        widthValue.tag = 100
        container.addSubview(widthValue)
        y -= 36

        // Fade Duration
        let fadeLabel = makeLabel("Fade Duration:")
        fadeLabel.frame = NSRect(x: 20, y: y, width: 120, height: 22)
        container.addSubview(fadeLabel)

        let fadeSlider = NSSlider(frame: NSRect(x: 150, y: y, width: 170, height: 22))
        fadeSlider.minValue = 0.5
        fadeSlider.maxValue = 10.0
        fadeSlider.doubleValue = settings.fadeDuration
        fadeSlider.target = self
        fadeSlider.action = #selector(fadeChanged(_:))
        container.addSubview(fadeSlider)

        let fadeValue = makeLabel(String(format: "%.1fs", settings.fadeDuration))
        fadeValue.frame = NSRect(x: 330, y: y, width: 50, height: 22)
        fadeValue.tag = 101
        container.addSubview(fadeValue)
        y -= 36

        // Spotlight Radius
        let spotLabel = makeLabel("Spotlight Radius:")
        spotLabel.frame = NSRect(x: 20, y: y, width: 120, height: 22)
        container.addSubview(spotLabel)

        let spotSlider = NSSlider(frame: NSRect(x: 150, y: y, width: 170, height: 22))
        spotSlider.minValue = 20
        spotSlider.maxValue = 200
        spotSlider.doubleValue = Double(settings.spotlightRadius)
        spotSlider.target = self
        spotSlider.action = #selector(spotChanged(_:))
        container.addSubview(spotSlider)

        let spotValue = makeLabel("\(Int(settings.spotlightRadius))px")
        spotValue.frame = NSRect(x: 330, y: y, width: 50, height: 22)
        spotValue.tag = 102
        container.addSubview(spotValue)
        y -= 50

        // Separator
        let sep = NSBox(frame: NSRect(x: 20, y: y + 10, width: 380, height: 1))
        sep.boxType = .separator
        container.addSubview(sep)
        y -= 10

        // Keyboard shortcuts reference
        let shortcutsTitle = makeLabel("Keyboard Shortcuts", bold: true, size: 13)
        shortcutsTitle.frame = NSRect(x: 20, y: y, width: 380, height: 20)
        container.addSubview(shortcutsTitle)
        y -= 24

        let shortcuts = [
            "⌃A: Toggle Drawing    F: Pen    A: Arrow    L: Line",
            "R: Rect    C: Circle    H: Highlighter    T: Text    E: Eraser",
            "1-5: Colors    [ ]: Width    ⌘Z/⌘⇧Z: Undo/Redo",
            "S: Screenshot    I: Interactive    K: Spotlight    W: Board",
            "Space: Fade    Esc: Pause    ⌫: Delete Last    ⌥⌫: Clear All",
        ]

        for line in shortcuts {
            let label = makeLabel(line, size: 11)
            label.frame = NSRect(x: 20, y: y, width: 380, height: 16)
            container.addSubview(label)
            y -= 18
        }

        return container
    }

    // MARK: - Actions

    @objc private func toolChanged(_ sender: NSPopUpButton) {
        guard let title = sender.selectedItem?.title,
              let tool = DrawingTool(rawValue: title) else { return }
        SettingsManager.shared.defaultTool = tool
    }

    @objc private func colorChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        SettingsManager.shared.defaultColor = SettingsManager.colorOptions[index]
    }

    @objc private func widthChanged(_ sender: NSSlider) {
        let val = CGFloat(sender.integerValue)
        SettingsManager.shared.defaultLineWidth = val
        if let label = window?.contentView?.viewWithTag(100) as? NSTextField {
            label.stringValue = "\(Int(val))"
        }
    }

    @objc private func fadeChanged(_ sender: NSSlider) {
        let val = sender.doubleValue
        SettingsManager.shared.fadeDuration = val
        if let label = window?.contentView?.viewWithTag(101) as? NSTextField {
            label.stringValue = String(format: "%.1fs", val)
        }
    }

    @objc private func spotChanged(_ sender: NSSlider) {
        let val = CGFloat(sender.doubleValue)
        SettingsManager.shared.spotlightRadius = val
        if let label = window?.contentView?.viewWithTag(102) as? NSTextField {
            label.stringValue = "\(Int(val))px"
        }
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, bold: Bool = false, size: CGFloat = 13) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        return label
    }
}
