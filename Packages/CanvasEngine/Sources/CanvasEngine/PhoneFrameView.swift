import SwiftUI
import DesignModel

/// Renders an iPhone device frame with accurate dimensions, Dynamic Island, and safe area indicators.
public struct PhoneFrameView: View {
    let deviceFrame: DeviceFrame
    let isDarkMode: Bool
    let showSafeAreas: Bool
    let content: AnyView

    public init(
        deviceFrame: DeviceFrame,
        isDarkMode: Bool = false,
        showSafeAreas: Bool = true,
        @ViewBuilder content: () -> some View
    ) {
        self.deviceFrame = deviceFrame
        self.isDarkMode = isDarkMode
        self.showSafeAreas = showSafeAreas
        self.content = AnyView(content())
    }

    /// Large interaction area so elements can be dragged well beyond the phone frame.
    private var interactionSize: CGSize {
        CGSize(
            width: deviceFrame.size.width + 600,
            height: deviceFrame.size.height + 600
        )
    }

    public var body: some View {
        ZStack {
            // Device outer bezel (visual only)
            RoundedRectangle(cornerRadius: deviceFrame.screenCornerRadius + 4)
                .fill(Color.black)
                .frame(
                    width: deviceFrame.size.width + 8,
                    height: deviceFrame.size.height + 8
                )
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .allowsHitTesting(false)

            // Screen background (clipped to phone shape, visual only)
            Rectangle()
                .fill(isDarkMode ? Color.black : Color.white)
                .frame(width: deviceFrame.size.width, height: deviceFrame.size.height)
                .clipShape(RoundedRectangle(cornerRadius: deviceFrame.screenCornerRadius))
                .allowsHitTesting(false)

            // Content — uses a much larger frame than the phone so elements
            // near edges or outside the phone can still receive drag gestures.
            // The content itself is aligned to a phone-sized area via its internal layout.
            content
                .colorScheme(isDarkMode ? .dark : .light)
                .frame(width: deviceFrame.size.width, height: deviceFrame.size.height, alignment: .center)
                .frame(width: interactionSize.width, height: interactionSize.height)
                .contentShape(Rectangle())

            // Phone frame overlays (clipped to phone shape, non-interactive)
            ZStack {
                if showSafeAreas {
                    safeAreaOverlay
                }
                if deviceFrame.hasDynamicIsland {
                    dynamicIsland
                }
                homeIndicator
            }
            .frame(width: deviceFrame.size.width, height: deviceFrame.size.height)
            .clipShape(RoundedRectangle(cornerRadius: deviceFrame.screenCornerRadius))
            .allowsHitTesting(false)

            // Phone frame border (visual only)
            RoundedRectangle(cornerRadius: deviceFrame.screenCornerRadius)
                .strokeBorder(Color.black, lineWidth: 4)
                .frame(width: deviceFrame.size.width, height: deviceFrame.size.height)
                .allowsHitTesting(false)
        }
        // The outer ZStack must also be large enough for the expanded interaction area
        .frame(width: interactionSize.width, height: interactionSize.height)
    }

    private var dynamicIsland: some View {
        VStack {
            Capsule()
                .fill(Color.black)
                .frame(width: 126, height: 37)
                .padding(.top, 11)
            Spacer()
        }
    }

    private var homeIndicator: some View {
        VStack {
            Spacer()
            Capsule()
                .fill(isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
                .frame(width: 134, height: 5)
                .padding(.bottom, 8)
        }
    }

    private var safeAreaOverlay: some View {
        ZStack {
            // Top safe area
            VStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.06))
                    .frame(height: deviceFrame.safeAreaInsets.top)
                Spacer()
            }

            // Bottom safe area
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.gray.opacity(0.06))
                    .frame(height: deviceFrame.safeAreaInsets.bottom)
            }
        }
    }
}
