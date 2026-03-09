import Cocoa

class OverlayWindow: NSPanel {

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        isRestorable = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Set above all other windows
        let maxLevel = [
            CGWindowLevelForKey(.mainMenuWindow),
            CGWindowLevelForKey(.statusWindow),
            CGWindowLevelForKey(.popUpMenuWindow),
            CGWindowLevelForKey(.screenSaverWindow)
        ].map { Int($0) }.max() ?? 0
        level = NSWindow.Level(rawValue: maxLevel + 1)

        let overlayView = OverlayView(frame: screen.frame)
        contentView = overlayView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
