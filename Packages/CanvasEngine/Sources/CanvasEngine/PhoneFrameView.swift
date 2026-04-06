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
        let w = deviceFrame.size.width
        let h = deviceFrame.size.height
        let cr = deviceFrame.screenCornerRadius

        ZStack {
            // 1. Device outer bezel — behind everything
            RoundedRectangle(cornerRadius: cr + 4)
                .fill(Color.black)
                .frame(width: w + 8, height: h + 8)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

            // 2. Screen background — clipped to phone shape (visual only)
            Rectangle()
                .fill(isDarkMode ? Color.black : Color.white)
                .frame(width: w, height: h)
                .clipShape(RoundedRectangle(cornerRadius: cr))
                .allowsHitTesting(false)

            // 3. Interactive content — NO clipShape so gestures work everywhere.
            //    Uses the phone-sized frame for layout but overflow is allowed.
            content
                .colorScheme(isDarkMode ? .dark : .light)
                .frame(width: w, height: h)

            // 4. Visual overlays — clipped to phone shape, pass-through for gestures
            overlayLayer
                .frame(width: w, height: h)
                .clipShape(RoundedRectangle(cornerRadius: cr))
                .allowsHitTesting(false)

            // 5. Bezel border ON TOP — hides any content overflow at rounded corners
            //    and completes the phone frame look. Non-interactive.
            bezelBorder
                .allowsHitTesting(false)
        }
    }

    // MARK: - Overlay layer (safe areas, dynamic island, home indicator)

    private var overlayLayer: some View {
        ZStack {
            if showSafeAreas {
                safeAreaOverlay
            }
            if deviceFrame.hasDynamicIsland {
                dynamicIsland
            }
            homeIndicator
        }
    }

    // MARK: - Bezel border that covers content overflow at corners

    private var bezelBorder: some View {
        let w = deviceFrame.size.width
        let h = deviceFrame.size.height
        let cr = deviceFrame.screenCornerRadius

        // A rectangle with a rounded-rect hole punched out — covers the corners
        return Rectangle()
            .fill(Color.black)
            .frame(width: w + 8, height: h + 8)
            .mask(
                ZStack {
                    // Full rect
                    Rectangle()
                    // Punch out the screen area
                    RoundedRectangle(cornerRadius: cr)
                        .frame(width: w, height: h)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            )
    }

    // MARK: - Sub-views

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
            VStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.06))
                    .frame(height: deviceFrame.safeAreaInsets.top)
                Spacer()
            }
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.gray.opacity(0.06))
                    .frame(height: deviceFrame.safeAreaInsets.bottom)
            }
        }
    }
}
