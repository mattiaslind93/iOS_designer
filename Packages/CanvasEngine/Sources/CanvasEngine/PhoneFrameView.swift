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

    public var body: some View {
        ZStack {
            // Device outer bezel
            RoundedRectangle(cornerRadius: deviceFrame.screenCornerRadius + 4)
                .fill(Color.black)
                .frame(
                    width: deviceFrame.size.width + 8,
                    height: deviceFrame.size.height + 8
                )
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

            // Screen area
            ZStack {
                // Background
                Rectangle()
                    .fill(isDarkMode ? Color.black : Color.white)

                // Content
                content
                    .colorScheme(isDarkMode ? .dark : .light)

                // Safe area overlay
                if showSafeAreas {
                    safeAreaOverlay
                }

                // Dynamic Island
                if deviceFrame.hasDynamicIsland {
                    dynamicIsland
                }

                // Home indicator
                homeIndicator
            }
            .frame(width: deviceFrame.size.width, height: deviceFrame.size.height)
            .clipShape(RoundedRectangle(cornerRadius: deviceFrame.screenCornerRadius))
        }
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
                    .fill(Color.blue.opacity(0.08))
                    .frame(height: deviceFrame.safeAreaInsets.top)
                Spacer()
            }

            // Bottom safe area
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(height: deviceFrame.safeAreaInsets.bottom)
            }
        }
    }
}
