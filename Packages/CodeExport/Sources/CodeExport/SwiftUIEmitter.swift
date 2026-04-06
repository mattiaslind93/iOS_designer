import Foundation
import DesignModel

/// Recursively walks an ElementNode tree and emits SwiftUI source code.
public struct SwiftUIEmitter {
    private var indentLevel: Int = 0
    private let indentString = "    "

    public init() {}

    /// Generate SwiftUI code for a complete page
    public func emit(page: DesignPage, viewName: String) -> String {
        var lines: [String] = []
        lines.append("import SwiftUI")
        lines.append("")
        lines.append("struct \(viewName): View {")
        lines.append("    var body: some View {")

        let bodyCode = emitNode(page.rootElement, indent: 2)
        lines.append(bodyCode)

        lines.append("    }")
        lines.append("}")
        lines.append("")
        lines.append("#Preview {")
        lines.append("    \(viewName)()")
        lines.append("}")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// Generate SwiftUI code for a single element node
    public func emitNode(_ node: ElementNode, indent: Int) -> String {
        let prefix = String(repeating: indentString, count: indent)
        var lines: [String] = []

        let opening = emitPayload(node.payload)

        if node.isContainer && !node.children.isEmpty {
            lines.append("\(prefix)\(opening) {")
            for child in node.children where child.isVisible {
                lines.append(emitNode(child, indent: indent + 1))
            }
            lines.append("\(prefix)}")
        } else {
            lines.append("\(prefix)\(opening)")
        }

        // Apply modifiers (skip default root modifiers)
        let applicableModifiers = node.modifiers.filter { !isDefaultRootModifier($0) || node.name != "Root" }
        for modifier in applicableModifiers {
            let modCode = emitModifier(modifier)
            if !modCode.isEmpty {
                lines.append("\(prefix)\(modCode)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func emitPayload(_ payload: ElementPayload) -> String {
        switch payload {
        case .vStack(let spacing, let alignment):
            return "VStack(alignment: .\(alignment.rawValue)\(spacing.map { ", spacing: \(Int($0))" } ?? ""))"
        case .hStack(let spacing, let alignment):
            return "HStack(alignment: .\(alignment.rawValue)\(spacing.map { ", spacing: \(Int($0))" } ?? ""))"
        case .zStack(let alignment):
            return "ZStack(alignment: .\(alignment.rawValue))"
        case .scrollView(let axis):
            return "ScrollView(.\(axis.rawValue))"
        case .lazyVGrid(let columns, let spacing):
            let cols = columns.map { emitGridColumn($0) }.joined(separator: ", ")
            return "LazyVGrid(columns: [\(cols)]\(spacing.map { ", spacing: \(Int($0))" } ?? ""))"
        case .lazyHGrid(let rows, let spacing):
            let rowsStr = rows.map { emitGridColumn($0) }.joined(separator: ", ")
            return "LazyHGrid(rows: [\(rowsStr)]\(spacing.map { ", spacing: \(Int($0))" } ?? ""))"
        case .text(let content, _):
            return "Text(\"\(content)\")"
        case .image(let systemName, let assetName):
            if let systemName { return "Image(systemName: \"\(systemName)\")" }
            if let assetName { return "Image(\"\(assetName)\")" }
            return "Image(systemName: \"photo\")"
        case .rectangle:           return "Rectangle()"
        case .circle:              return "Circle()"
        case .roundedRectangle(let r): return "RoundedRectangle(cornerRadius: \(Int(r)))"
        case .capsule:             return "Capsule()"
        case .spacer(let min):     return min.map { "Spacer(minLength: \(Int($0)))" } ?? "Spacer()"
        case .divider:             return "Divider()"
        case .color(let c):        return emitColor(c)
        case .navigationStack(let title, let mode):
            return "NavigationStack"
        case .tabView:             return "TabView"
        case .sheet:               return "// Sheet"
        case .button(let title, let style):
            let styleStr: String
            switch style {
            case .automatic: styleStr = ""
            case .borderedProminent: styleStr = "\n    .buttonStyle(.borderedProminent)"
            case .bordered: styleStr = "\n    .buttonStyle(.bordered)"
            case .borderless: styleStr = "\n    .buttonStyle(.borderless)"
            case .plain: styleStr = "\n    .buttonStyle(.plain)"
            case .glass: styleStr = "\n    .buttonStyle(.glass)"
            case .glassProminent: styleStr = "\n    .buttonStyle(.glassProminent)"
            }
            return "Button(\"\(title)\") { }\(styleStr)"
        case .textField(let p):    return "TextField(\"\(p)\", text: .constant(\"\"))"
        case .secureField(let p):  return "SecureField(\"\(p)\", text: .constant(\"\"))"
        case .toggle(let l, let v): return "Toggle(\"\(l)\", isOn: .constant(\(v)))"
        case .slider(let min, let max, let v):
            return "Slider(value: .constant(\(v)), in: \(min)...\(max))"
        case .picker(let l, let opts, let sel):
            return "Picker(\"\(l)\", selection: .constant(\(sel)))"
        case .stepper(let l, let min, let max, let v):
            return "Stepper(\"\(l)\", value: .constant(\(v)), in: \(min)...\(max))"
        case .datePicker(let l):   return "DatePicker(\"\(l)\", selection: .constant(Date()))"
        case .progressView(_, let v):
            return v.map { "ProgressView(value: \($0))" } ?? "ProgressView()"
        case .label(let t, let i): return "Label(\"\(t)\", systemImage: \"\(i)\")"
        case .list:                return "List"
        case .form:                return "Form"
        case .group:               return "Group"

        case .vectorPath(let path, let stroke, let fill):
            return emitVectorPath(path, stroke: stroke, fill: fill)
        case .importedImage(let data):
            return "Image(uiImage: UIImage(data: Data(base64Encoded: \"\(data.imageData.base64EncodedString().prefix(20))...\")!)!) // \(data.fileName)"
        }
    }

    private func emitModifier(_ modifier: DesignModifier) -> String {
        switch modifier {
        case .frame(let w, let h, _, let maxW, _, let maxH, _):
            var parts: [String] = []
            if let w { parts.append("width: \(Int(w))") }
            if let h { parts.append("height: \(Int(h))") }
            if let maxW, maxW == .infinity { parts.append("maxWidth: .infinity") }
            if let maxH, maxH == .infinity { parts.append("maxHeight: .infinity") }
            return parts.isEmpty ? "" : ".frame(\(parts.joined(separator: ", ")))"
        case .padding(let edges, let amount):
            if edges == .all { return ".padding(\(Int(amount)))" }
            return ".padding(.\(edges.rawValue), \(Int(amount)))"
        case .foregroundStyle(let color):
            return ".foregroundStyle(\(emitColor(color)))"
        case .background(let color):
            return ".background(\(emitColor(color)))"
        case .backgroundMaterial(let material):
            return ".background(.\(material.rawValue)Material)"
        case .tint(let color):
            return ".tint(\(emitColor(color)))"
        case .opacity(let o):
            return ".opacity(\(String(format: "%.2f", o)))"
        case .font(let style, let size, let weight, let design):
            if let style { return ".font(.\(style.rawValue))" }
            var parts: [String] = ["size: \(Int(size ?? 17))"]
            if let weight { parts.append("weight: .\(weight.rawValue)") }
            if let design, design != .default { parts.append("design: .\(design.rawValue)") }
            return ".font(.system(\(parts.joined(separator: ", "))))"
        case .cornerRadius(let r):
            return ".clipShape(RoundedRectangle(cornerRadius: \(Int(r))))"
        case .shadow(_, let r, let x, let y):
            return ".shadow(radius: \(Int(r)), x: \(Int(x)), y: \(Int(y)))"
        case .blur(let r):
            return ".blur(radius: \(Int(r)))"
        case .glassEffect(let style):
            return ".glassEffect(.\(style.rawValue))"
        case .glassConfig(let config):
            // Export full glassEffect chain
            var code = ".glassEffect(.\(config.style.rawValue)"
            if let tint = config.tintColor {
                code += ".tint(\(emitColor(tint)))"
            }
            if config.isInteractive {
                code += ".interactive()"
            }
            code += ", in: \(emitGlassShape(config.shape))"
            code += ")"
            return code
        case .glassEffectContainer:
            return "" // Applied at container level
        case .carPaint:
            return "// Car paint material (requires CarPaintView)"
        case .floatPosition(let alignment):
            return ".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .\(alignment.rawValue))"
        case .offset(let x, let y):
            return ".offset(x: \(Int(x)), y: \(Int(y)))"
        case .rotationEffect(let degrees):
            return ".rotationEffect(.degrees(\(Int(degrees))))"
        case .scaleEffect(let x, let y):
            if x == y { return ".scaleEffect(\(String(format: "%.2f", x)))" }
            return ".scaleEffect(x: \(String(format: "%.2f", x)), y: \(String(format: "%.2f", y)))"
        case .zIndex(let z):
            return ".zIndex(\(Int(z)))"
        default:
            return ""
        }
    }

    private func emitGlassShape(_ shape: GlassShapeType) -> String {
        switch shape {
        case .capsule:          return ".capsule"
        case .circle:           return ".circle"
        case .roundedRectangle: return "RoundedRectangle(cornerRadius: 12)"
        case .rectangle:        return "Rectangle()"
        case .ellipse:          return "Ellipse()"
        }
    }

    private func emitColor(_ color: DesignColor) -> String {
        switch color {
        case .custom(let r, let g, let b, let o):
            if o == 1.0 {
                return "Color(red: \(String(format: "%.2f", r)), green: \(String(format: "%.2f", g)), blue: \(String(format: "%.2f", b)))"
            }
            return "Color(red: \(String(format: "%.2f", r)), green: \(String(format: "%.2f", g)), blue: \(String(format: "%.2f", b))).opacity(\(String(format: "%.2f", o)))"
        case .system(let sys):
            switch sys {
            case .primary:   return ".primary"
            case .secondary: return ".secondary"
            case .accentColor: return ".accentColor"
            default:         return ".\(sys.rawValue)"
            }
        }
    }

    private func emitVectorPath(_ path: VectorPath, stroke: VectorStrokeStyle?, fill: DesignColor?) -> String {
        var lines: [String] = []
        lines.append("Path { path in")
        for (i, point) in path.points.enumerated() {
            if i == 0 {
                lines.append("    path.move(to: CGPoint(x: \(String(format: "%.1f", point.position.x)), y: \(String(format: "%.1f", point.position.y))))")
            } else {
                let prev = path.points[i - 1]
                if let handleOut = prev.handleOutAbsolute, let handleIn = point.handleInAbsolute {
                    lines.append("    path.addCurve(to: CGPoint(x: \(String(format: "%.1f", point.position.x)), y: \(String(format: "%.1f", point.position.y))), control1: CGPoint(x: \(String(format: "%.1f", handleOut.x)), y: \(String(format: "%.1f", handleOut.y))), control2: CGPoint(x: \(String(format: "%.1f", handleIn.x)), y: \(String(format: "%.1f", handleIn.y))))")
                } else if let handleOut = prev.handleOutAbsolute {
                    lines.append("    path.addQuadCurve(to: CGPoint(x: \(String(format: "%.1f", point.position.x)), y: \(String(format: "%.1f", point.position.y))), control: CGPoint(x: \(String(format: "%.1f", handleOut.x)), y: \(String(format: "%.1f", handleOut.y))))")
                } else {
                    lines.append("    path.addLine(to: CGPoint(x: \(String(format: "%.1f", point.position.x)), y: \(String(format: "%.1f", point.position.y))))")
                }
            }
        }
        if path.isClosed {
            lines.append("    path.closeSubpath()")
        }
        lines.append("}")
        if let fill {
            lines.append(".fill(\(emitColor(fill)))")
        }
        if let stroke {
            lines.append(".stroke(\(emitColor(stroke.color)), lineWidth: \(Int(stroke.width)))")
        }
        return lines.joined(separator: "\n")
    }

    private func emitGridColumn(_ config: GridColumnConfig) -> String {
        switch config.type {
        case .flexible: return "GridItem(.flexible())"
        case .fixed:    return "GridItem(.fixed(\(Int(config.size ?? 100))))"
        case .adaptive: return "GridItem(.adaptive(minimum: \(Int(config.size ?? 80))))"
        }
    }

    private func isDefaultRootModifier(_ modifier: DesignModifier) -> Bool {
        switch modifier {
        case .frame(_, _, _, let maxW, _, let maxH, _) where maxW == .infinity && maxH == .infinity:
            return true
        case .background(.system(.systemBackground)):
            return true
        default:
            return false
        }
    }
}
