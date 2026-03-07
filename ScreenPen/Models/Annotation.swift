import Cocoa

struct Annotation {
    let tool: DrawingTool
    let color: NSColor
    let lineWidth: CGFloat
    var points: [CGPoint]
}

enum DrawingTool: String, CaseIterable {
    case pen = "Pen"
    case arrow = "Arrow"
    case line = "Line"
    case rectangle = "Rectangle"
    case circle = "Circle"
    case highlighter = "Highlighter"
    case text = "Text"
    case eraser = "Eraser"
}
