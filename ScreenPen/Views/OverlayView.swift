import Cocoa

class OverlayView: NSView {

    // MARK: - State

    private var annotations: [Annotation] = []
    private var currentAnnotation: Annotation?
    private var undoStack: [Annotation] = []

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

        // Draw completed annotations
        for annotation in annotations {
            drawAnnotation(annotation)
        }

        // Draw current annotation in progress
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
            break // TODO: text input
        case .eraser:
            break // eraser removes on mouse up
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

        // Arrow head
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
        undoStack.removeAll()
        currentAnnotation = nil
        needsDisplay = true
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let cmd = event.modifierFlags.contains(.command)

        switch key {
        case "p": currentTool = .pen
        case "a": currentTool = .arrow
        case "l": currentTool = .line
        case "r": currentTool = .rectangle
        case "o": currentTool = .circle
        case "h": currentTool = .highlighter
        case "t": currentTool = .text
        case "e": currentTool = .eraser
        case "z" where cmd: undoLast()
        case "1": currentColor = .systemRed
        case "2": currentColor = .systemOrange
        case "3": currentColor = .systemYellow
        case "4": currentColor = .systemGreen
        case "5": currentColor = .systemBlue
        case "6": currentColor = .systemPurple
        case "7": currentColor = .white
        case "8": currentColor = .black
        case "[": currentLineWidth = max(1, currentLineWidth - 1)
        case "]": currentLineWidth = min(20, currentLineWidth + 1)
        default:
            if event.keyCode == 53 { // Escape
                (window as? OverlayWindow).flatMap { _ in
                    (NSApp.delegate as? AppDelegate)?.toggleDrawing()
                }
            }
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
        undoStack.removeAll()
        currentAnnotation = nil
        needsDisplay = true
    }

    func undoLast() {
        if let last = annotations.popLast() {
            undoStack.append(last)
            needsDisplay = true
        }
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
