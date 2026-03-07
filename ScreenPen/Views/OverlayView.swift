import Cocoa

class OverlayView: NSView {

    // MARK: - State

    private var annotations: [Annotation] = []
    private var currentAnnotation: Annotation?
    private var redoStack: [Annotation] = []

    var currentTool: DrawingTool = .pen
    var currentColor: NSColor = .systemRed
    var currentLineWidth: CGFloat = 3.0

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
        NSColor.clear.set()
        dirtyRect.fill()

        for annotation in annotations {
            drawAnnotation(annotation)
        }
        if let current = currentAnnotation {
            drawAnnotation(current)
        }
    }

    private func drawAnnotation(_ annotation: Annotation) {
        let color = annotation.color
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
        case .highlighter:
            drawFreehand(annotation.points, color: color.withAlphaComponent(0.3), lineWidth: lineWidth * 4)
        case .text:
            break
        case .eraser:
            break
        }
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
        guard let first = points.first, let last = points.last else { return }
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.move(to: first)
        path.line(to: last)
        color.setStroke()
        path.stroke()
    }

    private func drawArrow(_ points: [CGPoint], color: NSColor, lineWidth: CGFloat) {
        guard let first = points.first, let last = points.last, first != last else { return }
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
        guard let first = points.first, let last = points.last else { return }
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

    private func drawCircle(_ points: [CGPoint], color: NSColor, lineWidth: CGFloat) {
        guard let first = points.first, let last = points.last else { return }
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

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if currentTool == .eraser {
            eraseAtPoint(point)
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
    }

    // MARK: - Keyboard (keyCode based, input-method safe)

    override func keyDown(with event: NSEvent) {
        let code = event.keyCode
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd = flags.contains(.command)
        let opt = flags.contains(.option)
        let shift = flags.contains(.shift)

        switch code {
        // Tools (single key, like Presentify)
        case 3:  currentTool = .pen          // F (Freehand)
        case 0:  currentTool = .arrow        // A
        case 37: currentTool = .line         // L
        case 15: currentTool = .rectangle    // R
        case 8:  currentTool = .circle       // C
        case 4:  currentTool = .highlighter  // H
        case 17: currentTool = .text         // T
        case 14: currentTool = .eraser       // E

        // Colors 1-5
        case 18: currentColor = .systemRed       // 1
        case 19: currentColor = .systemOrange    // 2
        case 20: currentColor = .systemYellow    // 3
        case 21: currentColor = .systemGreen     // 4
        case 23: currentColor = .systemBlue      // 5

        // Line width
        case 33: currentLineWidth = max(1, currentLineWidth - 1) // [
        case 30: currentLineWidth = min(20, currentLineWidth + 1) // ]

        // Editing
        case 6 where cmd && shift: redoLast()    // ⌘⇧Z
        case 6 where cmd: undoLast()              // ⌘Z
        case 51 where opt:                           // ⌥⌫ — clear all + close
            (NSApp.delegate as? AppDelegate)?.clearAllAnnotations()
        case 51: deleteLastAnnotation()           // ⌫ — delete last

        // Escape — pause (keep drawings, exit drawing mode)
        case 53:
            (NSApp.delegate as? AppDelegate)?.toggleDrawing()

        default:
            break
        }

        NSCursor.crosshair.set()
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        NSCursor.crosshair.set()
        return true
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    // MARK: - Actions

    func clearAll() {
        annotations.removeAll()
        redoStack.removeAll()
        currentAnnotation = nil
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
