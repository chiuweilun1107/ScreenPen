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
        let hudWasVisible = !hudLabel.isHidden
        hudLabel.isHidden = true

        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return }
        cacheDisplay(in: bounds, to: rep)

        if hudWasVisible { hudLabel.isHidden = false }

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
        hudLabel.stringValue = "  Screenshot saved & copied  "
        hudLabel.sizeToFit()
        let x = (bounds.width - hudLabel.frame.width) / 2
        let y = bounds.height - hudLabel.frame.height - 40
        hudLabel.frame = NSRect(x: x, y: y, width: hudLabel.frame.width + 16, height: hudLabel.frame.height + 8)
        hudLabel.isHidden = false
        hudHideTimer?.invalidate()
        hudHideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.hudLabel.isHidden = true
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
        }
        updateHUD()
        NSCursor.crosshair.set()
    }

    // MARK: - HUD (floating status)

    private lazy var hudLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = true
        label.alignment = .center
        label.wantsLayer = true
        label.layer?.cornerRadius = 8
        label.layer?.masksToBounds = true
        addSubview(label)
        return label
    }()

    private var hudHideTimer: Timer?

    private func updateHUD() {
        let parts: [String] = [
            currentTool.rawValue,
            colorName(currentColor),
            "W:\(Int(currentLineWidth))",
            fadeEnabled ? "Fade" : nil,
            boardMode != .none ? boardMode.rawValue : nil,
            spotlightEnabled ? "Spot" : nil,
            interactiveMode ? "Interactive(Fn)" : nil,
        ].compactMap { $0 }

        hudLabel.stringValue = "  " + parts.joined(separator: " | ") + "  "
        hudLabel.sizeToFit()

        // Position at top center of view
        let x = (bounds.width - hudLabel.frame.width) / 2
        let y = bounds.height - hudLabel.frame.height - 40
        hudLabel.frame = NSRect(x: x, y: y, width: hudLabel.frame.width + 16, height: hudLabel.frame.height + 8)
        hudLabel.isHidden = false

        // Auto-hide after 2 seconds
        hudHideTimer?.invalidate()
        hudHideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.hudLabel.isHidden = true
        }
    }

    private func colorName(_ color: NSColor) -> String {
        switch color {
        case .systemRed: return "Red"
        case .systemOrange: return "Orange"
        case .systemYellow: return "Yellow"
        case .systemGreen: return "Green"
        case .systemBlue: return "Blue"
        default: return "Custom"
        }
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
