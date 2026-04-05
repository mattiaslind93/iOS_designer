import SwiftUI
import DesignModel

/// Keynote-like animation timeline editor.
/// Shows tracks per element with keyframes that can be dragged to adjust timing.
public struct AnimationEditorView: View {
    @ObservedObject var document: DesignDocument
    @State private var isExpanded = false

    public init(document: DesignDocument) {
        self.document = document
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Toggle bar
            HStack {
                Button {
                    withAnimation(.smooth) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "film")
                        Text("Animations")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            if isExpanded {
                Divider()
                timelineContent
            }
        }
    }

    private var timelineContent: some View {
        VStack(spacing: 0) {
            if let page = document.selectedPage {
                if page.animationTimeline.tracks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No animations yet")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("Select an element and add an animation preset")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                } else {
                    // Timeline tracks
                    ScrollView(.horizontal) {
                        VStack(spacing: 1) {
                            // Time ruler
                            timeRuler

                            ForEach(page.animationTimeline.tracks) { track in
                                trackRow(track)
                            }
                        }
                    }
                    .frame(height: 160)
                }

                // Preset bar
                presetBar
            }
        }
    }

    private var timeRuler: some View {
        HStack(spacing: 0) {
            ForEach(0..<10, id: \.self) { second in
                VStack {
                    Text("\(second)s")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(width: 80, height: 20)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 0.5)
                }
            }
        }
        .padding(.leading, 120)
    }

    private func trackRow(_ track: AnimationTrack) -> some View {
        HStack(spacing: 0) {
            // Track label
            HStack {
                Text(trackName(for: track))
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
            }
            .frame(width: 120)
            .padding(.horizontal, 8)

            // Keyframes
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.05))

                ForEach(track.keyframes) { keyframe in
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                        .offset(x: keyframe.time * 80)
                }
            }
        }
        .frame(height: 28)
    }

    private var presetBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AnimationPreset.allCases) { preset in
                    Button {
                        addPreset(preset)
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: preset.isSpring ? "water.waves" : "waveform.path")
                                .font(.system(size: 14))
                            Text(preset.displayName)
                                .font(.system(size: 9))
                        }
                        .frame(width: 56, height: 44)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func trackName(for track: AnimationTrack) -> String {
        guard let page = document.selectedPage else { return "Unknown" }
        return page.rootElement.find(by: track.elementID)?.name ?? "Unknown"
    }

    private func addPreset(_ preset: AnimationPreset) {
        guard let elementID = document.selectedElementID,
              let pageIndex = document.pages.firstIndex(where: { $0.id == document.selectedPageID }) else { return }

        let keyframe = Keyframe(time: 0, property: .opacity, value: 1.0, preset: preset)
        let track = AnimationTrack(elementID: elementID, keyframes: [keyframe])
        document.pages[pageIndex].animationTimeline.tracks.append(track)
    }
}
