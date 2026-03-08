import Cocoa

class OverlayView: NSView {

    // MARK: - State

    private var annotations: [Annotation] = []
    private var currentAnnotation: Annotation?
    private var redoStack: [Annotation] = []

    var currentTool: DrawingTool = .pen
    var currentColor: NSColor = .systemRed
    var currentLineWidth: CGFloat = 3.0

    // Feature: Fade mode
    var fadeEnabled = false
    private var fadeDuration: TimeInterval { SettingsManager.shared.fadeDuration }
    private var fadeTimer: Timer?

    // Feature: Board mode
    var boardMode: BoardMode = .none {
        didSet { needsDisplay = true }
    }

    // Feature: Cursor spotlight
    var spotlightEnabled = false
    private var spotlightRadius: CGFloat { SettingsManager.shared.spotlightRadius }
    private var mouseLocation: CGPoint = .zero

    // Feature: Shift constraint
    private var shiftHeld = false

    // Feature: Text annotation
    private var activeTextField: NSTextField?
    private var textInsertPoint: CGPoint = .zero

    // Feature: Interactive mode (Fn toggle)
    var interactiveMode = false

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTrackingArea()
    }

    private func setupTrackingArea() {
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Board mode background
        switch boardMode {
        case .whiteboard:
            NSColor.white.setFill()
            dirtyRect.fill()
        case .blackboard:
            NSColor(white: 0.15, alpha: 1.0).setFill()
            dirtyRect.fill()
        case .none:
            NSColor.clear.set()
            dirtyRect.fill()
        }

        // Draw annotations (with fade alpha if enabled)
        let now = Date()
        for annotation in annotations {
            let alpha = fadeAlpha(for: annotation, at: now)
            if alpha > 0 {
                drawAnnotation(annotation, alpha: alpha)
            }
        }
        if let current = currentAnnotation {
            drawAnnotation(current, alpha: 1.0)
        }

        // Cursor spotlight
        if spotlightEnabled {
            drawSpotlight()
        }
    }

    private func fadeAlpha(for annotation: Annotation, at now: Date) -> CGFloat {
        guard fadeEnabled else { return 1.0 }
        let age = now.timeIntervalSince(annotation.creationTime)
        if age >= fadeDuration { return 0.0 }
        if age <= fadeDuration * 0.5 { return 1.0 }
        // Fade out in second half
        return CGFloat(1.0 - (age - fadeDuration * 0.5) / (fadeDuration * 0.5))
    }

    private func drawAnnotation(_ annotation: Annotation, alpha: CGFloat) {
        let color = annotation.color.withAlphaComponent(annotation.color.alphaComponent * alpha)
        let lineWidth = annotation.lineWidth

        switch annotation.tool {
        case .pen:
            drawFreehand(annotation.points, color: color, lineWidth: lineWidth)
        case .arrow:
            drawArrow(annotation.points, color: color, lineWidth: lineWidth)
        case .line:
            drawLine(annotation.points, color: color, lineWidth: lineWidth)
        case .rectangle:
            drawRectangle(annotation.points, color: color, lineWidth: lineWidth)
        case .circle:
            drawCircle(annotation.points, color: color, lineWidth: lineWidth)
        case .heart:
            drawHeart(annotation.points, color: color, lineWidth: lineWidth)
        case .highlighter:
            drawFreehand(annotation.points, color: color.withAlphaComponent(0.3 * alpha), lineWidth: lineWidth * 4)
        case .text:
            drawText(annotation, alpha: alpha)
        case .eraser:
            break
        }
    }

    // MARK: - Spotlight

    private func drawSpotlight() {
        let ctx = NSGraphicsContext.current?.cgContext
        ctx?.saveGState()

        // Dark overlay with spotlight hole
        let overlayColor = NSColor.black.withAlphaComponent(0.4)
        overlayColor.setFill()
        bounds.fill()

        // Cut out spotlight circle
        ctx?.setBlendMode(.clear)
        let spotRect = NSRect(
            x: mouseLocation.x - spotlightRadius,
            y: mouseLocation.y - spotlightRadius,
            width: spotlightRadius * 2,
            height: spotlightRadius * 2
        )
        let spotPath = NSBezierPath(ovalIn: spotRect)
        spotPath.fill()

        // Soft edge glow
        ctx?.setBlendMode(.normal)
        let glowRect = spotRect.insetBy(dx: -10, dy: -10)
        let glowPath = NSBezierPath(ovalIn: glowRect)
        NSColor.white.withAlphaComponent(0.05).setFill()
        glowPath.fill()

        ctx?.restoreGState()
    }

    // MARK: - Shape Drawing

    private func drawFreehand(_ points: [CGPoint], color: NSColor, lineWidth: CGFloat) {
        guard points.count >= 2 else { return }
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: points[0])
        for i in 1..<points.count {
            path.line(to: points[i])
        }
        color.setStroke()
        path.stroke()
    }

    private func drawLine(_ points: [CGPoint], color: NSColor, lineWidth: CGFloat) {
        guard let first = points.first, var last = points.last else { return }
        if shiftHeld { last = constrainToAxis(from: first, to: last) }
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.move(to: first)
        path.line(to: last)
        color.setStroke()
        path.stroke()
    }

    private func drawArrow(_ points: [CGPoint], color: NSColor, lineWidth: CGFloat) {
        guard let first = points.first, var last = points.last, first != last else { return }
        if shiftHeld { last = constrainToAxis(from: first, to: last) }
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.move(to: first)
        path.line(to: last)
        color.setStroke()
        path.stroke()

        let headLength: CGFloat = 15.0
        let headAngle: CGFloat = .pi / 6
        let angle = atan2(last.y - first.y, last.x - first.x)

        let arrowHead = NSBezierPath()
        arrowHead.lineWidth = lineWidth
        arrowHead.lineCapStyle = .round
        arrowHead.move(to: last)
        arrowHead.line(to: CGPoint(
            x: last.x - headLength * cos(angle - headAngle),
            y: last.y - headLength * sin(angle - headAngle)
        ))
        arrowHead.move(to: last)
        arrowHead.line(to: CGPoint(
            x: last.x - headLength * cos(angle + headAngle),
            y: last.y - headLength * sin(angle + headAngle)
        ))
        arrowHead.stroke()
    }

    private func drawRectangle(_ points: [CGPoint], color: NSColor, lineWidth: CGFloat) {
        guard let first = points.first, var last = points.last else { return }
        if shiftHeld { last = constrainToSquare(from: first, to: last) }
        let rect = NSRect(
            x: min(first.x, last.x),
            y: min(first.y, last.y),
            width: abs(last.x - first.x),
            height: abs(last.y - first.y)
        )
        let path = NSBezierPath(rect: rect)
        path.lineWidth = lineWidth
        color.setStroke()
        path.stroke()
    }

    private func drawHeart(_ points: [CGPoint], color: NSColor, lineWidth: CGFloat) {
        guard let first = points.first, let last = points.last else { return }
        let rect = NSRect(
            x: min(first.x, last.x),
            y: min(first.y, last.y),
            width: abs(last.x - first.x),
            height: abs(last.y - first.y)
        )
        guard rect.width > 2, rect.height > 2 else { return }

        let path = NSBezierPath()
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY

        // Bottom tip
        path.move(to: CGPoint(x: x + w * 0.5, y: y))
        // Right side up to top-right bump
        path.curve(
            to: CGPoint(x: x + w, y: y + h * 0.65),
            controlPoint1: CGPoint(x: x + w * 0.8, y: y + h * 0.05),
            controlPoint2: CGPoint(x: x + w, y: y + h * 0.35)
        )
        // Top-right bump arc
        path.curve(
            to: CGPoint(x: x + w * 0.5, y: y + h * 0.72),
            controlPoint1: CGPoint(x: x + w, y: y + h),
            controlPoint2: CGPoint(x: x + w * 0.6, y: y + h)
        )
        // Top-left bump arc
        path.curve(
            to: CGPoint(x: x, y: y + h * 0.65),
            controlPoint1: CGPoint(x: x + w * 0.4, y: y + h),
            controlPoint2: CGPoint(x: x, y: y + h)
        )
        // Left side back to bottom tip
        path.curve(
            to: CGPoint(x: x + w * 0.5, y: y),
            controlPoint1: CGPoint(x: x, y: y + h * 0.35),
            controlPoint2: CGPoint(x: x + w * 0.2, y: y + h * 0.05)
        )
        path.close()

        path.lineWidth = lineWidth
        path.lineJoinStyle = .round
        color.setStroke()
        path.stroke()
    }

    private func drawCircle(_ points: [CGPoint], color: NSColor, lineWidth: CGFloat) {
        guard let first = points.first, var last = points.last else { return }
        if shiftHeld { last = constrainToSquare(from: first, to: last) }
        let rect = NSRect(
            x: min(first.x, last.x),
            y: min(first.y, last.y),
            width: abs(last.x - first.x),
            height: abs(last.y - first.y)
        )
        let path = NSBezierPath(ovalIn: rect)
        path.lineWidth = lineWidth
        color.setStroke()
        path.stroke()
    }

    private func drawText(_ annotation: Annotation, alpha: CGFloat) {
        guard let text = annotation.text, let position = annotation.points.first else { return }
        let color = annotation.color.withAlphaComponent(annotation.color.alphaComponent * alpha)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: annotation.fontSize, weight: .medium),
            .foregroundColor: color
        ]
        let nsString = text as NSString
        nsString.draw(at: position, withAttributes: attrs)
    }

    // MARK: - Screenshot

    func captureScreenshot() {
        guard self.window != nil else { return }
        // Temporarily hide HUD for clean capture
        let hudWasVisible = !hudPanel.isHidden
        hudPanel.isHidden = true

        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return }
        cacheDisplay(in: bounds, to: rep)

        if hudWasVisible { hudPanel.isHidden = false }

        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)

        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])

        // Save to Desktop
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let filename = "ScreenPen-\(formatter.string(from: Date())).png"
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let fileURL = desktopURL.appendingPathComponent(filename)

        if let tiffData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: fileURL)
        }

        // Flash feedback
        showScreenshotFeedback()
    }

    private func showScreenshotFeedback() {
        hudPanel.showMessage("Screenshot saved & copied ✓")
        if hudPanel.isHidden {
            hudPanel.layoutForCurrentState()
            let x = (bounds.width - hudPanel.frame.width) / 2
            let y = bounds.height - hudPanel.frame.height - 48
            hudPanel.setFrameOrigin(CGPoint(x: x, y: y))
            hudPanel.isHidden = false
        }
        screenshotFeedbackTimer?.invalidate()
        screenshotFeedbackTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.updateHUD()
        }
    }

    // MARK: - Text Input

    private func beginTextInput(at point: CGPoint) {
        textInsertPoint = point
        let textField = NSTextField(frame: NSRect(x: point.x, y: point.y - 10, width: 300, height: 24))
        textField.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        textField.textColor = currentColor
        textField.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        textField.isBordered = false
        textField.isBezeled = false
        textField.isEditable = true
        textField.focusRingType = .none
        textField.drawsBackground = true
        textField.wantsLayer = true
        textField.layer?.cornerRadius = 4
        textField.target = self
        textField.action = #selector(commitText(_:))
        addSubview(textField)
        window?.makeFirstResponder(textField)
        activeTextField = textField
    }

    @objc private func commitText(_ sender: NSTextField) {
        let text = sender.stringValue
        if !text.isEmpty {
            let annotation = Annotation(
                tool: .text,
                color: currentColor,
                lineWidth: currentLineWidth,
                points: [textInsertPoint],
                text: text
            )
            annotations.append(annotation)
            redoStack.removeAll()
            if fadeEnabled { startFadeTimer() }
        }
        sender.removeFromSuperview()
        activeTextField = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    func cancelTextInput() {
        activeTextField?.removeFromSuperview()
        activeTextField = nil
        window?.makeFirstResponder(self)
    }

    // MARK: - Shift Constraint Helpers

    /// Constrain line to nearest 0°/45°/90° axis
    private func constrainToAxis(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(abs(dy), abs(dx))

        if angle < .pi / 8 {
            // Horizontal
            return CGPoint(x: end.x, y: start.y)
        } else if angle > .pi * 3 / 8 {
            // Vertical
            return CGPoint(x: start.x, y: end.y)
        } else {
            // 45 degree
            let dist = max(abs(dx), abs(dy))
            return CGPoint(
                x: start.x + dist * (dx > 0 ? 1 : -1),
                y: start.y + dist * (dy > 0 ? 1 : -1)
            )
        }
    }

    /// Constrain rectangle/circle to square (equal width & height)
    private func constrainToSquare(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let size = max(abs(dx), abs(dy))
        return CGPoint(
            x: start.x + size * (dx > 0 ? 1 : -1),
            y: start.y + size * (dy > 0 ? 1 : -1)
        )
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if currentTool == .eraser {
            eraseAtPoint(point)
            return
        }

        if currentTool == .text {
            beginTextInput(at: point)
            return
        }

        currentAnnotation = Annotation(
            tool: currentTool,
            color: currentColor,
            lineWidth: currentLineWidth,
            points: [point]
        )
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if currentTool == .eraser {
            eraseAtPoint(point)
            return
        }

        currentAnnotation?.points.append(point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let annotation = currentAnnotation else { return }
        annotations.append(annotation)
        redoStack.removeAll()
        currentAnnotation = nil
        needsDisplay = true

        // Start fade timer if needed
        if fadeEnabled {
            startFadeTimer()
        }
    }

    override func mouseMoved(with event: NSEvent) {
        mouseLocation = convert(event.locationInWindow, from: nil)
        if spotlightEnabled {
            needsDisplay = true
        }
    }

    // MARK: - Fade Timer

    private func startFadeTimer() {
        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Remove fully faded annotations
            let now = Date()
            self.annotations.removeAll { now.timeIntervalSince($0.creationTime) >= self.fadeDuration }
            self.needsDisplay = true
            // Stop timer if nothing to fade
            if self.annotations.isEmpty {
                self.fadeTimer?.invalidate()
                self.fadeTimer = nil
            }
        }
    }

    // MARK: - Keyboard (keyCode based, input-method safe)

    override func keyDown(with event: NSEvent) {
        let code = event.keyCode
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd = flags.contains(.command)
        let opt = flags.contains(.option)
        let shift = flags.contains(.shift)

        // Fixed shortcuts (not remappable)
        switch code {
        case 6 where cmd && shift: redoLast(); updateHUD(); return   // ⌘⇧Z
        case 6 where cmd: undoLast(); updateHUD(); return            // ⌘Z
        case 51 where opt:                                            // ⌥⌫
            (NSApp.delegate as? AppDelegate)?.clearAllAnnotations(); return
        case 51: deleteLastAnnotation(); updateHUD(); return          // ⌫
        case 53:                                                      // Escape
            if activeTextField != nil { cancelTextInput(); return }
            (NSApp.delegate as? AppDelegate)?.toggleDrawing(); return
        default: break
        }

        // Configurable shortcuts via SettingsManager
        let map = SettingsManager.shared.shortcutMap()
        if let action = map[code] {
            handleShortcutAction(action)
        }

        updateHUD()
        NSCursor.crosshair.set()
    }

    override func flagsChanged(with event: NSEvent) {
        shiftHeld = event.modifierFlags.contains(.shift)

        // Fn key toggle for interactive mode
        let fnHeld = event.modifierFlags.contains(.function)
        if interactiveMode {
            // In interactive mode: Fn held = draw (interactive overlay), Fn released = passthrough
            let shouldBeInteractive = fnHeld
            (NSApp.delegate as? AppDelegate)?.setInteractiveModeState(drawing: shouldBeInteractive)
        }

        if currentAnnotation != nil {
            needsDisplay = true
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        NSCursor.crosshair.set()
        updateHUD()
        return true
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    // MARK: - Shortcut Actions

    private func handleShortcutAction(_ action: SettingsManager.ShortcutAction) {
        switch action {
        case .pen:         currentTool = .pen
        case .arrow:       currentTool = .arrow
        case .line:        currentTool = .line
        case .rectangle:   currentTool = .rectangle
        case .circle:      currentTool = .circle
        case .heart:       currentTool = .heart
        case .highlighter: currentTool = .highlighter
        case .text:        currentTool = .text
        case .eraser:      currentTool = .eraser
        case .color1:      currentColor = .systemRed
        case .color2:      currentColor = .systemOrange
        case .color3:      currentColor = .systemYellow
        case .color4:      currentColor = .systemGreen
        case .color5:      currentColor = .systemBlue
        case .widthDown:   currentLineWidth = max(1, currentLineWidth - 1)
        case .widthUp:     currentLineWidth = min(20, currentLineWidth + 1)
        case .fadeToggle:
            fadeEnabled.toggle()
            if fadeEnabled { startFadeTimer() }
        case .boardMode:
            switch boardMode {
            case .none: boardMode = .whiteboard
            case .whiteboard: boardMode = .blackboard
            case .blackboard: boardMode = .none
            }
        case .spotlight:
            spotlightEnabled.toggle()
            needsDisplay = true
        case .interactive:
            interactiveMode.toggle()
            if interactiveMode {
                (NSApp.delegate as? AppDelegate)?.setInteractiveModeState(drawing: false)
            } else {
                (NSApp.delegate as? AppDelegate)?.setInteractiveModeState(drawing: true)
            }
        case .screenshot:
            captureScreenshot()
            return
        case .showHUD:
            if hudPanel.isHidden {
                updateHUD()
            } else {
                hudPanel.isHidden = true
            }
            return
        }
        updateHUD()
        NSCursor.crosshair.set()
    }

    // MARK: - HUD (floating status, draggable, interactive)

    private lazy var hudPanel: HUDPanel = {
        let panel = HUDPanel()
        addSubview(panel)
        panel.isHidden = true
        panel.onClose = { [weak self] in
            self?.hudPanel.isHidden = true
        }
        panel.onColorChange = { [weak self] color in
            self?.currentColor = color
            self?.updateHUD()
        }
        panel.onToolChange = { [weak self] tool in
            self?.currentTool = tool
            self?.updateHUD()
            NSCursor.crosshair.set()
        }
        return panel
    }()

    private var screenshotFeedbackTimer: Timer?

    private func updateHUD() {
        hudPanel.update(
            tool: currentTool,
            color: currentColor,
            width: Int(currentLineWidth),
            extras: [
                fadeEnabled ? "Fade" : nil,
                boardMode != .none ? boardMode.rawValue : nil,
                spotlightEnabled ? "Spot" : nil,
                interactiveMode ? "Fn" : nil,
            ].compactMap { $0 }
        )

        if hudPanel.isHidden {
            hudPanel.layoutForCurrentState()
            let x = (bounds.width - hudPanel.frame.width) / 2
            let y = bounds.height - hudPanel.frame.height - 48
            hudPanel.setFrameOrigin(CGPoint(x: x, y: y))
        }
        hudPanel.isHidden = false
    }

    // MARK: - Actions

    func clearAll() {
        annotations.removeAll()
        redoStack.removeAll()
        currentAnnotation = nil
        fadeTimer?.invalidate()
        fadeTimer = nil
        needsDisplay = true
    }

    func undoLast() {
        if let last = annotations.popLast() {
            redoStack.append(last)
            needsDisplay = true
        }
    }

    func redoLast() {
        if let last = redoStack.popLast() {
            annotations.append(last)
            needsDisplay = true
        }
    }

    private func deleteLastAnnotation() {
        _ = annotations.popLast()
        needsDisplay = true
    }

    private func eraseAtPoint(_ point: CGPoint) {
        let eraseRadius: CGFloat = 20.0
        annotations.removeAll { annotation in
            annotation.points.contains { p in
                hypot(p.x - point.x, p.y - point.y) < eraseRadius
            }
        }
        needsDisplay = true
    }
}

// MARK: - HUDPanel (premium, draggable, interactive)

private class HUDPanel: NSView {

    // MARK: Callbacks
    var onClose: (() -> Void)?
    var onColorChange: ((NSColor) -> Void)?
    var onToolChange: ((DrawingTool) -> Void)?

    // MARK: State
    private var currentTool: DrawingTool = .pen
    private var currentColor: NSColor = .systemRed
    private var currentWidth: Int = 3
    private var currentExtras: [String] = []
    private var messageMode = false

    private var colorPickerVisible = false
    private var toolPickerVisible = false

    // MARK: Layout constants
    private let rowH: CGFloat = 44
    private let pickerH: CGFloat = 40
    private let hPad: CGFloat = 14
    private let itemGap: CGFloat = 10
    private let dotSize: CGFloat = 20
    private let toolIconSize: CGFloat = 20

    // MARK: Drag
    private var dragOffset: CGPoint = .zero
    private var isDragging = false

    // MARK: Subviews — background
    private let vfx: NSVisualEffectView = {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = 14
        v.layer?.masksToBounds = true
        v.layer?.borderWidth = 0.5
        v.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        return v
    }()

    // MARK: Main row elements
    private let toolIcon: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.contentTintColor = .white
        return iv
    }()
    private let toolLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .white
        l.isBezeled = false; l.isEditable = false; l.drawsBackground = false
        return l
    }()
    private let colorDot: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.cornerRadius = 10
        v.layer?.borderWidth = 1.5
        v.layer?.borderColor = NSColor.white.withAlphaComponent(0.4).cgColor
        return v
    }()
    private let widthLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        l.textColor = NSColor.white.withAlphaComponent(0.7)
        l.isBezeled = false; l.isEditable = false; l.drawsBackground = false
        return l
    }()
    private let extrasLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        l.textColor = NSColor.white.withAlphaComponent(0.5)
        l.isBezeled = false; l.isEditable = false; l.drawsBackground = false
        return l
    }()
    private lazy var closeBtn: NSButton = {
        let btn = NSButton(title: "✕", target: self, action: #selector(closeTapped))
        btn.bezelStyle = .inline; btn.isBordered = false
        btn.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        btn.contentTintColor = NSColor.white.withAlphaComponent(0.45)
        return btn
    }()

    // MARK: Separator line
    private let separator: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
        return v
    }()

    // MARK: Picker container
    private let pickerContainer: NSView = {
        let v = NSView()
        v.isHidden = true
        return v
    }()
    private var colorSwatches: [NSView] = []
    private var toolButtons: [NSButton] = []

    // MARK: Message label (for transient messages like screenshot)
    private let messageLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        l.textColor = .white
        l.isBezeled = false; l.isEditable = false; l.drawsBackground = false
        l.isHidden = true
        return l
    }()

    // MARK: Init
    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        addSubview(vfx)
        vfx.addSubview(toolIcon)
        vfx.addSubview(toolLabel)
        vfx.addSubview(colorDot)
        vfx.addSubview(widthLabel)
        vfx.addSubview(extrasLabel)
        vfx.addSubview(closeBtn)
        vfx.addSubview(separator)
        vfx.addSubview(pickerContainer)
        vfx.addSubview(messageLabel)

        buildColorSwatches()
        buildToolButtons()

        // Clickable areas
        let toolArea = ClickableView { [weak self] in self?.toggleToolPicker() }
        let colorArea = ClickableView { [weak self] in self?.toggleColorPicker() }
        toolArea.frame = .zero
        colorArea.frame = .zero
        vfx.addSubview(toolArea)
        vfx.addSubview(colorArea)
        self.toolClickArea = toolArea
        self.colorClickArea = colorArea
    }

    private var toolClickArea: ClickableView?
    private var colorClickArea: ClickableView?

    // MARK: Build pickers

    private func buildColorSwatches() {
        colorSwatches.forEach { $0.removeFromSuperview() }
        colorSwatches = SettingsManager.colorOptions.map { color in
            let v = NSView()
            v.wantsLayer = true
            v.layer?.backgroundColor = color.cgColor
            v.layer?.cornerRadius = 11
            v.layer?.borderWidth = 1.5
            v.layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
            let click = ClickableView { [weak self] in
                self?.onColorChange?(color)
                self?.hideAllPickers()
            }
            click.frame = v.bounds
            click.autoresizingMask = [.width, .height]
            v.addSubview(click)
            pickerContainer.addSubview(v)
            return v
        }
    }

    private func buildToolButtons() {
        toolButtons.forEach { $0.removeFromSuperview() }
        toolButtons = DrawingTool.allCases.map { tool in
            let btn = NSButton(title: "", target: self, action: #selector(toolBtnTapped(_:)))
            btn.bezelStyle = .inline
            btn.isBordered = false
            if let img = NSImage(systemSymbolName: tool.symbolName, accessibilityDescription: tool.rawValue) {
                btn.image = img
                btn.imageScaling = .scaleProportionallyUpOrDown
            } else {
                btn.title = String(tool.rawValue.prefix(1))
                btn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            }
            btn.contentTintColor = .white
            btn.tag = DrawingTool.allCases.firstIndex(of: tool) ?? 0
            pickerContainer.addSubview(btn)
            return btn
        }
    }

    @objc private func toolBtnTapped(_ sender: NSButton) {
        let tool = DrawingTool.allCases[sender.tag]
        onToolChange?(tool)
        hideAllPickers()
    }

    // MARK: Public API

    func update(tool: DrawingTool, color: NSColor, width: Int, extras: [String]) {
        currentTool = tool; currentColor = color; currentWidth = width; currentExtras = extras
        guard !messageMode else { return }

        if let img = NSImage(systemSymbolName: tool.symbolName, accessibilityDescription: tool.rawValue) {
            toolIcon.image = img
            toolIcon.isHidden = false
        } else {
            toolIcon.isHidden = true
        }
        toolLabel.stringValue = tool.rawValue
        toolLabel.sizeToFit()

        colorDot.layer?.backgroundColor = color.cgColor

        widthLabel.stringValue = "●".repeated(min(width, 5))
        widthLabel.sizeToFit()

        extrasLabel.stringValue = extras.isEmpty ? "" : extras.joined(separator: " · ")
        extrasLabel.sizeToFit()

        updateSelectedSwatch()
        updateSelectedTool()
        layoutForCurrentState()
    }

    func showMessage(_ msg: String) {
        messageMode = true
        messageLabel.stringValue = msg
        messageLabel.sizeToFit()
        messageLabel.isHidden = false
        toolIcon.isHidden = true; toolLabel.isHidden = true
        colorDot.isHidden = true; widthLabel.isHidden = true
        extrasLabel.isHidden = true
        toolClickArea?.isHidden = true; colorClickArea?.isHidden = true
        separator.isHidden = true; pickerContainer.isHidden = true
        colorPickerVisible = false; toolPickerVisible = false
        layoutForCurrentState()
    }

    func endMessageMode() {
        messageMode = false
        messageLabel.isHidden = true
        toolIcon.isHidden = false; toolLabel.isHidden = false
        colorDot.isHidden = false; widthLabel.isHidden = false
        toolClickArea?.isHidden = false; colorClickArea?.isHidden = false
    }

    // MARK: Layout

    func layoutForCurrentState() {
        if messageMode {
            let msgW = messageLabel.frame.width + hPad * 2 + 28
            let totalH = rowH
            setFrameSize(NSSize(width: msgW, height: totalH))
            vfx.frame = bounds
            let cx = (msgW - messageLabel.frame.width) / 2
            messageLabel.frame.origin = CGPoint(x: cx, y: (rowH - messageLabel.frame.height) / 2)
            closeBtn.frame = NSRect(x: msgW - 26, y: (rowH - 16) / 2, width: 20, height: 16)
            return
        }

        // Main row layout
        var x = hPad

        // Tool icon
        let iconSize: CGFloat = toolIconSize
        toolIcon.frame = NSRect(x: x, y: (rowH - iconSize) / 2, width: iconSize, height: iconSize)
        x += iconSize + 6

        // Tool label (clickable area)
        toolLabel.frame.origin = CGPoint(x: x, y: (rowH - toolLabel.frame.height) / 2)
        let toolAreaW = toolLabel.frame.width + 4
        toolClickArea?.frame = NSRect(x: x - 2, y: 0, width: toolAreaW, height: rowH)
        x += toolAreaW + itemGap

        // Separator dot
        x += 4
        let sepDot = NSTextField(labelWithString: "·")
        sepDot.textColor = NSColor.white.withAlphaComponent(0.3)
        sepDot.font = NSFont.systemFont(ofSize: 13)
        sepDot.sizeToFit()
        x += sepDot.frame.width + 4

        // Color dot (clickable)
        colorDot.frame = NSRect(x: x, y: (rowH - dotSize) / 2, width: dotSize, height: dotSize)
        colorClickArea?.frame = NSRect(x: x - 4, y: 0, width: dotSize + 8, height: rowH)
        x += dotSize + itemGap

        // Width dots
        widthLabel.frame.origin = CGPoint(x: x, y: (rowH - widthLabel.frame.height) / 2)
        x += widthLabel.frame.width + itemGap

        // Extras
        if !currentExtras.isEmpty {
            extrasLabel.isHidden = false
            extrasLabel.frame.origin = CGPoint(x: x, y: (rowH - extrasLabel.frame.height) / 2)
            x += extrasLabel.frame.width + itemGap
        } else {
            extrasLabel.isHidden = true
        }

        // Close button
        x += 4
        let closeBtnW: CGFloat = 20
        closeBtn.frame = NSRect(x: x, y: (rowH - 16) / 2, width: closeBtnW, height: 16)
        x += closeBtnW + hPad / 2

        let mainRowW = x

        // Picker layout
        var totalH = rowH
        if colorPickerVisible || toolPickerVisible {
            separator.isHidden = false
            separator.frame = NSRect(x: 0, y: rowH - 0.5, width: mainRowW, height: 0.5)
            pickerContainer.isHidden = false
            pickerContainer.frame = NSRect(x: 0, y: rowH, width: mainRowW, height: pickerH)
            if colorPickerVisible { layoutColorSwatches(in: pickerContainer.bounds) }
            if toolPickerVisible { layoutToolButtons(in: pickerContainer.bounds) }
            totalH = rowH + pickerH
        } else {
            separator.isHidden = true
            pickerContainer.isHidden = true
        }

        setFrameSize(NSSize(width: mainRowW, height: totalH))
        vfx.frame = bounds

        // Shadow
        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.35
        layer?.shadowRadius = 12
        layer?.shadowOffset = CGSize(width: 0, height: -3)
    }

    private func layoutColorSwatches(in rect: NSRect) {
        let count = colorSwatches.count
        let swatchSize: CGFloat = 22
        let gap: CGFloat = 6
        let totalW = CGFloat(count) * swatchSize + CGFloat(count - 1) * gap
        var sx = (rect.width - totalW) / 2
        let sy = (rect.height - swatchSize) / 2
        for swatch in colorSwatches {
            swatch.frame = NSRect(x: sx, y: sy, width: swatchSize, height: swatchSize)
            swatch.layer?.cornerRadius = swatchSize / 2
            sx += swatchSize + gap
        }
    }

    private func layoutToolButtons(in rect: NSRect) {
        let count = toolButtons.count
        let btnSize: CGFloat = 26
        let gap: CGFloat = 4
        let totalW = CGFloat(count) * btnSize + CGFloat(count - 1) * gap
        var bx = (rect.width - totalW) / 2
        let by = (rect.height - btnSize) / 2
        for btn in toolButtons {
            btn.frame = NSRect(x: bx, y: by, width: btnSize, height: btnSize)
            bx += btnSize + gap
        }
    }

    private func updateSelectedSwatch() {
        for (i, swatch) in colorSwatches.enumerated() {
            let col = SettingsManager.colorOptions[i]
            let isSelected = col.isApproximatelyEqual(to: currentColor)
            swatch.layer?.borderWidth = isSelected ? 2.5 : 1.5
            swatch.layer?.borderColor = isSelected
                ? NSColor.white.cgColor
                : NSColor.white.withAlphaComponent(0.25).cgColor
        }
    }

    private func updateSelectedTool() {
        for (i, btn) in toolButtons.enumerated() {
            let isSelected = DrawingTool.allCases[i] == currentTool
            btn.contentTintColor = isSelected ? NSColor.controlAccentColor : .white
        }
    }

    // MARK: Toggle pickers

    private func toggleColorPicker() {
        toolPickerVisible = false
        colorPickerVisible.toggle()
        animateLayout()
    }

    private func toggleToolPicker() {
        colorPickerVisible = false
        toolPickerVisible.toggle()
        animateLayout()
    }

    private func hideAllPickers() {
        colorPickerVisible = false
        toolPickerVisible = false
        animateLayout()
    }

    private func animateLayout() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layoutForCurrentState()
        }
    }

    // MARK: Actions

    @objc private func closeTapped() { onClose?() }

    // MARK: Drag

    override func mouseDown(with event: NSEvent) {
        dragOffset = convert(event.locationInWindow, from: nil)
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        isDragging = true
        guard let sv = superview else { return }
        let loc = sv.convert(event.locationInWindow, from: nil)
        setFrameOrigin(CGPoint(x: loc.x - dragOffset.x, y: loc.y - dragOffset.y))
    }

    override func cursorUpdate(with event: NSEvent) { NSCursor.arrow.set() }
    override var acceptsFirstResponder: Bool { false }
}

// MARK: - Helpers

private class ClickableView: NSView {
    private let action: () -> Void
    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func mouseUp(with event: NSEvent) { action() }
    override func cursorUpdate(with event: NSEvent) { NSCursor.pointingHand.set() }
    override var acceptsFirstResponder: Bool { false }
}

private extension DrawingTool {
    var symbolName: String {
        switch self {
        case .pen:         return "pencil"
        case .arrow:       return "arrow.up.right"
        case .line:        return "line.diagonal"
        case .rectangle:   return "rectangle"
        case .circle:      return "circle"
        case .heart:       return "heart"
        case .highlighter: return "highlighter"
        case .text:        return "textformat"
        case .eraser:      return "eraser"
        }
    }
}

private extension String {
    func repeated(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}

private extension NSColor {
    func isApproximatelyEqual(to other: NSColor) -> Bool {
        guard let c1 = usingColorSpace(.deviceRGB),
              let c2 = other.usingColorSpace(.deviceRGB) else { return self == other }
        return abs(c1.redComponent - c2.redComponent) < 0.01 &&
               abs(c1.greenComponent - c2.greenComponent) < 0.01 &&
               abs(c1.blueComponent - c2.blueComponent) < 0.01
    }
}
