import Cocoa

class SettingsWindowController: NSWindowController, NSWindowDelegate {

    static var shared: SettingsWindowController?
    private var shortcutButtons: [SettingsManager.ShortcutAction: NSButton] = [:]
    private var recordingAction: SettingsManager.ShortcutAction?
    private var keyMonitor: Any?

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
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ScreenPen Settings"
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        window.delegate = self

        let tabView = NSTabView(frame: NSRect(x: 0, y: 0, width: 480, height: 560))

        let generalTab = NSTabViewItem(identifier: "general")
        generalTab.label = "General"
        generalTab.view = buildGeneralView()
        tabView.addTabViewItem(generalTab)

        let shortcutsTab = NSTabViewItem(identifier: "shortcuts")
        shortcutsTab.label = "Shortcuts"
        shortcutsTab.view = buildShortcutsView()
        tabView.addTabViewItem(shortcutsTab)

        window.contentView = tabView
    }

    func windowWillClose(_ notification: Notification) {
        stopRecording()
        SettingsWindowController.shared = nil
    }

    // MARK: - General Tab

    private func buildGeneralView() -> NSView {
        let settings = SettingsManager.shared
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 520))

        var y: CGFloat = 480

        // Default Tool
        let toolLabel = makeLabel("Default Tool:")
        toolLabel.frame = NSRect(x: 20, y: y, width: 140, height: 22)
        container.addSubview(toolLabel)

        let toolPopup = NSPopUpButton(frame: NSRect(x: 170, y: y, width: 200, height: 24))
        let tools: [DrawingTool] = [.pen, .arrow, .line, .rectangle, .circle, .highlighter]
        for tool in tools { toolPopup.addItem(withTitle: tool.rawValue) }
        toolPopup.selectItem(withTitle: settings.defaultTool.rawValue)
        toolPopup.target = self
        toolPopup.action = #selector(toolChanged(_:))
        container.addSubview(toolPopup)
        y -= 36

        // Default Color
        let colorLabel = makeLabel("Default Color:")
        colorLabel.frame = NSRect(x: 20, y: y, width: 140, height: 22)
        container.addSubview(colorLabel)

        let colorPopup = NSPopUpButton(frame: NSRect(x: 170, y: y, width: 200, height: 24))
        for name in SettingsManager.colorNames { colorPopup.addItem(withTitle: name) }
        let colorIndex = SettingsManager.colorOptions.firstIndex(of: settings.defaultColor) ?? 0
        colorPopup.selectItem(at: colorIndex)
        colorPopup.target = self
        colorPopup.action = #selector(colorChanged(_:))
        container.addSubview(colorPopup)
        y -= 36

        // Line Width
        let widthLabel = makeLabel("Line Width:")
        widthLabel.frame = NSRect(x: 20, y: y, width: 140, height: 22)
        container.addSubview(widthLabel)

        let widthSlider = NSSlider(frame: NSRect(x: 170, y: y, width: 170, height: 22))
        widthSlider.minValue = 1
        widthSlider.maxValue = 20
        widthSlider.doubleValue = Double(settings.defaultLineWidth)
        widthSlider.target = self
        widthSlider.action = #selector(widthChanged(_:))
        container.addSubview(widthSlider)

        let widthValue = makeLabel("\(Int(settings.defaultLineWidth))")
        widthValue.frame = NSRect(x: 350, y: y, width: 40, height: 22)
        widthValue.tag = 100
        container.addSubview(widthValue)
        y -= 36

        // Fade Duration
        let fadeLabel = makeLabel("Fade Duration:")
        fadeLabel.frame = NSRect(x: 20, y: y, width: 140, height: 22)
        container.addSubview(fadeLabel)

        let fadeSlider = NSSlider(frame: NSRect(x: 170, y: y, width: 170, height: 22))
        fadeSlider.minValue = 0.5
        fadeSlider.maxValue = 10.0
        fadeSlider.doubleValue = settings.fadeDuration
        fadeSlider.target = self
        fadeSlider.action = #selector(fadeChanged(_:))
        container.addSubview(fadeSlider)

        let fadeValue = makeLabel(String(format: "%.1fs", settings.fadeDuration))
        fadeValue.frame = NSRect(x: 350, y: y, width: 50, height: 22)
        fadeValue.tag = 101
        container.addSubview(fadeValue)
        y -= 36

        // Spotlight Radius
        let spotLabel = makeLabel("Spotlight Radius:")
        spotLabel.frame = NSRect(x: 20, y: y, width: 140, height: 22)
        container.addSubview(spotLabel)

        let spotSlider = NSSlider(frame: NSRect(x: 170, y: y, width: 170, height: 22))
        spotSlider.minValue = 20
        spotSlider.maxValue = 200
        spotSlider.doubleValue = Double(settings.spotlightRadius)
        spotSlider.target = self
        spotSlider.action = #selector(spotChanged(_:))
        container.addSubview(spotSlider)

        let spotValue = makeLabel("\(Int(settings.spotlightRadius))px")
        spotValue.frame = NSRect(x: 350, y: y, width: 50, height: 22)
        spotValue.tag = 102
        container.addSubview(spotValue)

        return container
    }

    // MARK: - Shortcuts Tab

    private func buildShortcutsView() -> NSView {
        let settings = SettingsManager.shared

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 520))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let container = NSView()
        let actions = SettingsManager.ShortcutAction.allCases
        let rowHeight: CGFloat = 30
        let totalHeight = max(CGFloat(actions.count) * rowHeight + 60, 520)
        container.frame = NSRect(x: 0, y: 0, width: 460, height: totalHeight)

        var y = totalHeight - 30

        // Header
        let header = makeLabel("Click a key to reassign, then press a new key.", size: 11)
        header.textColor = .secondaryLabelColor
        header.frame = NSRect(x: 20, y: y, width: 420, height: 18)
        container.addSubview(header)
        y -= 10

        // Reset all button
        let resetBtn = NSButton(title: "Reset All to Defaults", target: self, action: #selector(resetAllShortcuts))
        resetBtn.bezelStyle = .rounded
        resetBtn.frame = NSRect(x: 310, y: y - 4, width: 150, height: 24)
        container.addSubview(resetBtn)
        y -= 30

        // Shortcut rows
        for action in actions {
            let label = makeLabel(action.displayName)
            label.frame = NSRect(x: 20, y: y, width: 160, height: 22)
            container.addSubview(label)

            let keyCode = settings.keyCode(for: action)
            let keyName = SettingsManager.keyName(for: keyCode)
            let isDefault = keyCode == action.defaultKeyCode

            let btn = NSButton(title: keyName, target: self, action: #selector(shortcutButtonClicked(_:)))
            btn.bezelStyle = .rounded
            btn.frame = NSRect(x: 190, y: y - 2, width: 80, height: 24)
            btn.tag = Int(action.hashValue)
            btn.toolTip = action.rawValue
            if !isDefault {
                btn.contentTintColor = .systemBlue
            }
            container.addSubview(btn)
            shortcutButtons[action] = btn

            if !isDefault {
                let resetOne = NSButton(title: "↺", target: self, action: #selector(resetOneShortcut(_:)))
                resetOne.bezelStyle = .rounded
                resetOne.frame = NSRect(x: 278, y: y - 2, width: 30, height: 24)
                resetOne.toolTip = action.rawValue
                container.addSubview(resetOne)
            }

            let defaultLabel = makeLabel("default: \(SettingsManager.keyName(for: action.defaultKeyCode))", size: 10)
            defaultLabel.textColor = .tertiaryLabelColor
            defaultLabel.frame = NSRect(x: 316, y: y, width: 120, height: 18)
            container.addSubview(defaultLabel)

            y -= rowHeight
        }

        scrollView.documentView = container
        return scrollView
    }

    // MARK: - Shortcut Recording

    @objc private func shortcutButtonClicked(_ sender: NSButton) {
        guard let actionRaw = sender.toolTip,
              let action = SettingsManager.ShortcutAction(rawValue: actionRaw) else { return }

        // Cancel any previous recording
        stopRecording()

        recordingAction = action
        sender.title = "Press key..."
        sender.contentTintColor = .systemRed

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.recordKey(event)
            return nil // consume the event
        }
    }

    private func recordKey(_ event: NSEvent) {
        guard let action = recordingAction else { return }

        let code = event.keyCode

        // Don't allow Escape/Delete/Cmd+Z — those are fixed
        if code == 53 || code == 51 || code == 6 {
            stopRecording()
            return
        }

        // Check for conflicts
        let settings = SettingsManager.shared
        for other in SettingsManager.ShortcutAction.allCases where other != action {
            if settings.keyCode(for: other) == code {
                // Swap: give the conflicting action our old key
                let oldCode = settings.keyCode(for: action)
                settings.setKeyCode(oldCode, for: other)
                if let btn = shortcutButtons[other] {
                    btn.title = SettingsManager.keyName(for: oldCode)
                    btn.contentTintColor = oldCode == other.defaultKeyCode ? nil : .systemBlue
                }
                break
            }
        }

        settings.setKeyCode(code, for: action)

        if let btn = shortcutButtons[action] {
            btn.title = SettingsManager.keyName(for: code)
            btn.contentTintColor = code == action.defaultKeyCode ? nil : .systemBlue
        }

        stopRecording()
    }

    private func stopRecording() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        // Restore button title if still in recording state
        if let action = recordingAction, let btn = shortcutButtons[action] {
            let code = SettingsManager.shared.keyCode(for: action)
            btn.title = SettingsManager.keyName(for: code)
            btn.contentTintColor = code == action.defaultKeyCode ? nil : .systemBlue
        }
        recordingAction = nil
    }

    @objc private func resetOneShortcut(_ sender: NSButton) {
        guard let actionRaw = sender.toolTip,
              let action = SettingsManager.ShortcutAction(rawValue: actionRaw) else { return }
        SettingsManager.shared.resetShortcut(for: action)
        refreshShortcutsTab()
    }

    @objc private func resetAllShortcuts() {
        SettingsManager.shared.resetAllShortcuts()
        refreshShortcutsTab()
    }

    private func refreshShortcutsTab() {
        shortcutButtons.removeAll()
        // Find the shortcuts tab and rebuild
        if let tabView = window?.contentView as? NSTabView {
            for item in tabView.tabViewItems where (item.identifier as? String) == "shortcuts" {
                item.view = buildShortcutsView()
                break
            }
        }
    }

    // MARK: - General Actions

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
        findLabel(tag: 100)?.stringValue = "\(Int(val))"
    }

    @objc private func fadeChanged(_ sender: NSSlider) {
        let val = sender.doubleValue
        SettingsManager.shared.fadeDuration = val
        findLabel(tag: 101)?.stringValue = String(format: "%.1fs", val)
    }

    @objc private func spotChanged(_ sender: NSSlider) {
        let val = CGFloat(sender.doubleValue)
        SettingsManager.shared.spotlightRadius = val
        findLabel(tag: 102)?.stringValue = "\(Int(val))px"
    }

    private func findLabel(tag: Int) -> NSTextField? {
        guard let tabView = window?.contentView as? NSTabView else { return nil }
        for item in tabView.tabViewItems {
            if let label = item.view?.viewWithTag(tag) as? NSTextField {
                return label
            }
        }
        return nil
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
