import Cocoa

struct Annotation {
    let tool: DrawingTool
    let color: NSColor
    let lineWidth: CGFloat
    var points: [CGPoint]
    let creationTime: Date

    init(tool: DrawingTool, color: NSColor, lineWidth: CGFloat, points: [CGPoint]) {
        self.tool = tool
        self.color = color
        self.lineWidth = lineWidth
        self.points = points
        self.creationTime = Date()
    }
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

enum BoardMode: String {
    case none = "None"
    case whiteboard = "Whiteboard"
    case blackboard = "Blackboard"
}
