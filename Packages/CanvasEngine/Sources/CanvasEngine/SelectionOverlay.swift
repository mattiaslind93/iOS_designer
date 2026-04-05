import SwiftUI

/// Visual selection indicator shown around the currently selected element.
/// Displays a blue border with resize handles at corners and edges.
public struct SelectionOverlay: View {
    public init() {}

    public var body: some View {
        ZStack {
            // Selection border
            Rectangle()
                .strokeBorder(Color.accentColor, lineWidth: 1.5)

            // Corner handles
            ForEach(HandlePosition.allCases, id: \.self) { position in
                ResizeHandle()
                    .position(position.offset)
            }
        }
        .allowsHitTesting(false)
    }
}

struct ResizeHandle: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 8, height: 8)
            .overlay {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 1.5)
            }
    }
}

enum HandlePosition: CaseIterable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
    case topCenter, bottomCenter, leadingCenter, trailingCenter

    var offset: CGPoint {
        // These are relative positions; actual positions are set via GeometryReader
        // when used in the real selection overlay. This is a simplified version.
        switch self {
        case .topLeading:      return CGPoint(x: 0, y: 0)
        case .topTrailing:     return CGPoint(x: 1, y: 0)
        case .bottomLeading:   return CGPoint(x: 0, y: 1)
        case .bottomTrailing:  return CGPoint(x: 1, y: 1)
        case .topCenter:       return CGPoint(x: 0.5, y: 0)
        case .bottomCenter:    return CGPoint(x: 0.5, y: 1)
        case .leadingCenter:   return CGPoint(x: 0, y: 0.5)
        case .trailingCenter:  return CGPoint(x: 1, y: 0.5)
        }
    }
}
