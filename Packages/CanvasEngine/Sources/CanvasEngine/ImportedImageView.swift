import SwiftUI
import DesignModel

#if os(macOS)
import AppKit
#endif

/// Renders an ImportedImageData as an image view.
/// Supports PNG, JPEG, and other formats with alpha transparency.
public struct ImportedImageView: View {
    let imageData: ImportedImageData

    public init(imageData: ImportedImageData) {
        self.imageData = imageData
    }

    public var body: some View {
        if let nsImage = NSImage(data: imageData.imageData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: imageData.contentMode.swiftUIValue)
        } else {
            // Fallback: show placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundStyle(.secondary)
                    )
                VStack(spacing: 4) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(imageData.fileName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Content Mode Conversion

extension ImageContentMode {
    public var swiftUIValue: ContentMode {
        switch self {
        case .fit:     return .fit
        case .fill:    return .fill
        case .stretch: return .fit // SwiftUI doesn't have stretch, use fit
        }
    }
}
