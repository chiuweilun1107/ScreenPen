import Cocoa
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var overlayWindows: [NSScreen: OverlayWindow] = [:]
    private var isDrawingMode = false
    private var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityPermission()
        setupStatusBar()
        setupCarbonHotkey()
        observeScreenChanges()
    }

    // MARK: - Accessibility Permission

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pencil.tip", accessibilityDescription: "ScreenPen")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Drawing (⌃A)", action: #selector(toggleDrawing), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Clear All (⌥⌫)", action: #selector(clearAllAnnotations), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Undo (⌘Z)", action: #selector(undoLast), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    // MARK: - Carbon Global Hotkey (immune to input method)

    private func setupCarbonHotkey() {
        var eventType = EventTypeSpec(eventClass: UInt32(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let appDelegate = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    appDelegate.toggleDrawing()
                }
                return noErr
            },
            1,
            &eventType,
            appDelegate,
            nil
        )

        // ⌃A (Control + A) — keyCode 0 = 'a'
        var hotKeyID = EventHotKeyID(signature: OSType(0x5350_454E), id: 1)
        let modifiers = UInt32(controlKey)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_A),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
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
            setOverlayInteractive(true)
            NSApp.activate(ignoringOtherApps: true)
            if let firstWindow = overlayWindows.values.first {
                firstWindow.makeKeyAndOrderFront(nil)
                firstWindow.makeFirstResponder(firstWindow.contentView)
            }
        } else {
            // Pause: keep drawings visible, let mouse through
            setOverlayInteractive(false)
            NSApp.hide(nil)
            // Re-show overlays after hide (hide deactivates the app)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self, !self.isDrawingMode else { return }
                for (_, window) in self.overlayWindows {
                    window.orderFrontRegardless()
                }
            }
        }
        updateStatusIcon()
    }

    /// Clear all annotations and fully close overlays
    @objc func clearAllAnnotations() {
        isDrawingMode = false
        for (_, window) in overlayWindows {
            (window.contentView as? OverlayView)?.clearAll()
        }
        hideOverlays()
        NSApp.hide(nil)
        updateStatusIcon()
    }

    // MARK: - Helpers

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

    private func setOverlayInteractive(_ interactive: Bool) {
        let maxLevel = [
            CGWindowLevelForKey(.mainMenuWindow),
            CGWindowLevelForKey(.statusWindow),
            CGWindowLevelForKey(.popUpMenuWindow),
            CGWindowLevelForKey(.screenSaverWindow)
        ].map { Int($0) }.max() ?? 0

        for (_, window) in overlayWindows {
            window.ignoresMouseEvents = !interactive
            window.level = interactive
                ? NSWindow.Level(rawValue: maxLevel + 1)
                : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
        }
    }

    private func updateStatusIcon() {
        if let button = statusItem.button {
            let symbolName = isDrawingMode ? "pencil.tip.crop.circle.fill" : "pencil.tip"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "ScreenPen")
        }
    }

    @objc private func undoLast() {
        for (_, window) in overlayWindows {
            (window.contentView as? OverlayView)?.undoLast()
        }
    }
}
