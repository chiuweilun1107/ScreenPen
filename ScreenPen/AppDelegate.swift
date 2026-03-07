import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var overlayWindows: [NSScreen: OverlayWindow] = [:]
    private var isDrawingMode = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupGlobalHotkey()
        observeScreenChanges()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pencil.tip", accessibilityDescription: "ScreenPen")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Drawing (⌃⌥D)", action: #selector(toggleDrawing), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let toolsMenu = NSMenu()
        toolsMenu.addItem(NSMenuItem(title: "Pen (P)", action: nil, keyEquivalent: ""))
        toolsMenu.addItem(NSMenuItem(title: "Arrow (A)", action: nil, keyEquivalent: ""))
        toolsMenu.addItem(NSMenuItem(title: "Line (L)", action: nil, keyEquivalent: ""))
        toolsMenu.addItem(NSMenuItem(title: "Rectangle (R)", action: nil, keyEquivalent: ""))
        toolsMenu.addItem(NSMenuItem(title: "Circle (O)", action: nil, keyEquivalent: ""))
        toolsMenu.addItem(NSMenuItem(title: "Highlighter (H)", action: nil, keyEquivalent: ""))
        toolsMenu.addItem(NSMenuItem(title: "Text (T)", action: nil, keyEquivalent: ""))
        toolsMenu.addItem(NSMenuItem(title: "Eraser (E)", action: nil, keyEquivalent: ""))
        let toolsItem = NSMenuItem(title: "Tools", action: nil, keyEquivalent: "")
        toolsItem.submenu = toolsMenu
        menu.addItem(toolsItem)

        menu.addItem(NSMenuItem(title: "Clear All (⌘⌫)", action: #selector(clearAll), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Undo (⌘Z)", action: #selector(undoLast), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    // MARK: - Global Hotkey

    private func setupGlobalHotkey() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Control + Option + D
            if event.modifierFlags.contains([.control, .option]) && event.keyCode == 2 {
                self?.toggleDrawing()
            }
        }
        // Also monitor local events when app is active
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.control, .option]) && event.keyCode == 2 {
                self?.toggleDrawing()
                return nil
            }
            return event
        }
    }

    // MARK: - Screen Observation

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensChanged() {
        if isDrawingMode {
            hideOverlays()
            showOverlays()
        }
    }

    // MARK: - Toggle Drawing

    @objc func toggleDrawing() {
        isDrawingMode.toggle()
        if isDrawingMode {
            showOverlays()
        } else {
            hideOverlays()
        }
        updateStatusIcon()
    }

    private func showOverlays() {
        for screen in NSScreen.screens {
            if overlayWindows[screen] == nil {
                let window = OverlayWindow(screen: screen)
                overlayWindows[screen] = window
            }
            overlayWindows[screen]?.orderFrontRegardless()
        }
    }

    private func hideOverlays() {
        for (_, window) in overlayWindows {
            window.orderOut(nil)
        }
    }

    private func updateStatusIcon() {
        if let button = statusItem.button {
            let symbolName = isDrawingMode ? "pencil.tip.crop.circle.fill" : "pencil.tip"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "ScreenPen")
        }
    }

    @objc private func clearAll() {
        for (_, window) in overlayWindows {
            (window.contentView as? OverlayView)?.clearAll()
        }
    }

    @objc private func undoLast() {
        for (_, window) in overlayWindows {
            (window.contentView as? OverlayView)?.undoLast()
        }
    }
}
