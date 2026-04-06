#!/usr/bin/env swift
// GenerateCameraDoc.swift
// Generates a DesignDocument JSON for a camera app UI with Liquid Glass elements.
// Run: swift Tools/GenerateCameraDoc.swift

import Foundation

// Minimal inline model types matching DesignModel's Codable output
// so we can generate valid JSON without importing the framework.

// MARK: - Color

enum DesignColor: Codable {
    case custom(red: Double, green: Double, blue: Double, opacity: Double)
    case system(SystemColor)

    enum SystemColor: String, Codable {
        case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown
        case gray, gray2, gray3, gray4, gray5, gray6
        case primary, secondary, accentColor
        case label, secondaryLabel, tertiaryLabel, quaternaryLabel
        case systemBackground, secondarySystemBackground, tertiarySystemBackground
        case systemGroupedBackground, secondarySystemGroupedBackground, tertiarySystemGroupedBackground
        case systemFill, secondarySystemFill, tertiarySystemFill, quaternarySystemFill
        case separator, opaqueSeparator
    }
}

// MARK: - Payload & Modifier enums

enum ElementPayload: Codable {
    case vStack(spacing: CGFloat?, alignment: String)
    case hStack(spacing: CGFloat?, alignment: String)
    case zStack(alignment: String)
    case text(content: String, style: String?)
    case image(systemName: String?, assetName: String?)
    case rectangle
    case circle
    case roundedRectangle(cornerRadius: CGFloat)
    case capsule
    case spacer(minLength: CGFloat?)
    case divider
    case color(designColor: DesignColor)
    case slider(minValue: Double, maxValue: Double, value: Double)
    case button(title: String, style: String)
    case group
    case label(title: String, systemImage: String)
    case progressView(style: String, value: Double?)
}

enum DesignModifier: Codable {
    case frame(width: CGFloat?, height: CGFloat?, minWidth: CGFloat?, maxWidth: CGFloat?,
               minHeight: CGFloat?, maxHeight: CGFloat?, alignment: String?)
    case padding(edges: String, amount: CGFloat)
    case foregroundStyle(DesignColor)
    case background(DesignColor)
    case backgroundMaterial(String)
    case opacity(Double)
    case font(style: String?, size: CGFloat?, weight: String?, design: String?)
    case cornerRadius(CGFloat)
    case clipShape(String)
    case overlay(String, color: DesignColor, lineWidth: CGFloat)
    case shadow(color: DesignColor, radius: CGFloat, x: CGFloat, y: CGFloat)
    case blur(radius: CGFloat)
    case glassEffect(String)
    case glassConfig(GlassConfig)
    case offset(x: CGFloat, y: CGFloat)
    case rotationEffect(degrees: Double)
    case scaleEffect(x: CGFloat, y: CGFloat)
    case zIndex(Double)
    case layoutPriority(Double)
    case tint(DesignColor)
}

struct GlassConfig: Codable {
    var style: String
    var tintColor: DesignColor?
    var tintIntensity: Double
    var isInteractive: Bool
    var shape: String
}

// MARK: - Node & Document

struct ElementNode: Codable {
    let id: String
    var name: String
    var payload: ElementPayload
    var modifiers: [DesignModifier]
    var children: [ElementNode]
    var isLocked: Bool
    var isVisible: Bool
    var booleanConfig: String? // null
}

struct DesignPage: Codable {
    let id: String
    var name: String
    var deviceFrame: String
    var rootElement: ElementNode
    var animationTimeline: AnimationTimeline
    var isDarkMode: Bool
}

struct AnimationTimeline: Codable {
    var tracks: [String] // empty
}

struct DesignTokenSet: Codable {
    var spacingScale: [CGFloat]
    var cornerRadii: [CGFloat]
    var accentColor: DesignColor
    var backgroundColor: DesignColor
    var textColor: DesignColor
}

struct ExportConfig: Codable {
    var projectName: String
    var bundleIdentifier: String
    var deploymentTarget: String
    var organizationName: String
}

struct DocumentData: Codable {
    var pages: [DesignPage]
    var tokens: DesignTokenSet
    var exportConfig: ExportConfig
}

// MARK: - Helpers

func uuid() -> String { UUID().uuidString }

func node(_ name: String, _ payload: ElementPayload, mods: [DesignModifier] = [], children: [ElementNode] = []) -> ElementNode {
    ElementNode(id: uuid(), name: name, payload: payload, modifiers: mods, children: children, isLocked: false, isVisible: true, booleanConfig: nil)
}

let black = DesignColor.custom(red: 0, green: 0, blue: 0, opacity: 1)
let white = DesignColor.custom(red: 1, green: 1, blue: 1, opacity: 1)
let clear = DesignColor.custom(red: 0, green: 0, blue: 0, opacity: 0)
let warmOrange = DesignColor.custom(red: 0.93, green: 0.58, blue: 0.35, opacity: 1)
let warmOrangeBg = DesignColor.custom(red: 0.93, green: 0.58, blue: 0.35, opacity: 0.15)
let darkGray = DesignColor.custom(red: 0.15, green: 0.15, blue: 0.15, opacity: 1)
let midGray = DesignColor.custom(red: 0.25, green: 0.25, blue: 0.25, opacity: 1)
let lightGray = DesignColor.custom(red: 0.6, green: 0.6, blue: 0.6, opacity: 1)
let dimWhite = DesignColor.custom(red: 1, green: 1, blue: 1, opacity: 0.7)
let redColor = DesignColor.custom(red: 0.9, green: 0.2, blue: 0.2, opacity: 1)
let viewfinderBg = DesignColor.custom(red: 0.35, green: 0.30, blue: 0.25, opacity: 1)
let gridLine = DesignColor.custom(red: 1, green: 1, blue: 1, opacity: 0.15)
let sliderBg = DesignColor.custom(red: 0.85, green: 0.70, blue: 0.55, opacity: 0.3)

// MARK: - Build Camera UI

// --- AUTO badge (top left) ---
let autoBadge = node("AUTO Badge", .text(content: "AUTO", style: nil), mods: [
    .font(style: nil, size: 13, weight: "bold", design: nil),
    .foregroundStyle(redColor),
    .padding(edges: "horizontal", amount: 12),
    .padding(edges: "vertical", amount: 5),
    .overlay("capsule", color: redColor, lineWidth: 1.5),
])

// --- Exposure ±0 button (glass) ---
let exposureBtn = node("Exposure Button", .hStack(spacing: 4, alignment: "center"), mods: [
    .padding(edges: "horizontal", amount: 12),
    .padding(edges: "vertical", amount: 6),
    .glassConfig(GlassConfig(style: "regular", tintColor: nil, tintIntensity: 0.2, isInteractive: true, shape: "capsule")),
], children: [
    node("Exp Icon", .image(systemName: "plusminus", assetName: nil), mods: [
        .font(style: nil, size: 13, weight: "medium", design: nil),
        .foregroundStyle(white),
    ]),
    node("Exp Value", .text(content: "±0", style: nil), mods: [
        .font(style: nil, size: 14, weight: "medium", design: nil),
        .foregroundStyle(white),
    ]),
])

// --- Flash button (glass) ---
let flashBtn = node("Flash Button", .image(systemName: "bolt.slash.fill", assetName: nil), mods: [
    .font(style: nil, size: 16, weight: "medium", design: nil),
    .foregroundStyle(white),
    .frame(width: 36, height: 36, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
    .glassConfig(GlassConfig(style: "regular", tintColor: nil, tintIntensity: 0.2, isInteractive: true, shape: "circle")),
])

// --- Top controls bar ---
let topBar = node("Top Bar", .hStack(spacing: 8, alignment: "center"), mods: [
    .padding(edges: "horizontal", amount: 16),
    .padding(edges: "vertical", amount: 8),
], children: [
    autoBadge,
    node("Top Spacer", .spacer(minLength: nil)),
    exposureBtn,
    flashBtn,
])

// --- Viewfinder placeholder ---
// Grid lines (rule of thirds)
let vLine1 = node("VLine1", .rectangle, mods: [
    .frame(width: 0.5, height: nil, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
    .foregroundStyle(gridLine),
    .offset(x: -60, y: 0),
])
let vLine2 = node("VLine2", .rectangle, mods: [
    .frame(width: 0.5, height: nil, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
    .foregroundStyle(gridLine),
    .offset(x: 60, y: 0),
])
let hLine1 = node("HLine1", .rectangle, mods: [
    .frame(width: nil, height: 0.5, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
    .foregroundStyle(gridLine),
    .offset(x: 0, y: -80),
])
let hLine2 = node("HLine2", .rectangle, mods: [
    .frame(width: nil, height: 0.5, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
    .foregroundStyle(gridLine),
    .offset(x: 0, y: 80),
])

let viewfinder = node("Viewfinder", .zStack(alignment: "center"), mods: [
    .frame(width: nil, height: 480, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
    .padding(edges: "horizontal", amount: 0),
    .cornerRadius(4),
], children: [
    node("VF Background", .roundedRectangle(cornerRadius: 4), mods: [
        .foregroundStyle(viewfinderBg),
    ]),
    // Center dark circle (cup in the photo)
    node("Center Circle", .circle, mods: [
        .frame(width: 120, height: 120, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
        .foregroundStyle(DesignColor.custom(red: 0.2, green: 0.18, blue: 0.14, opacity: 0.8)),
        .shadow(color: DesignColor.custom(red: 0, green: 0, blue: 0, opacity: 0.3), radius: 20, x: 0, y: 0),
    ]),
    // Grid overlay
    vLine1, vLine2, hLine1, hLine2,
    // Viewfinder label
    node("VF Label", .text(content: "VIEWFINDER", style: nil), mods: [
        .font(style: nil, size: 10, weight: "medium", design: "monospaced"),
        .foregroundStyle(DesignColor.custom(red: 1, green: 1, blue: 1, opacity: 0.25)),
    ]),
])

// --- Light meter (glass slider area) ---
let lightMeterTicks = node("LM Ticks", .hStack(spacing: 0, alignment: "center"), mods: [
    .padding(edges: "horizontal", amount: 20),
], children: [
    node("-3", .text(content: "-3", style: nil), mods: [.font(style: nil, size: 9, weight: "medium", design: "monospaced"), .foregroundStyle(dimWhite)]),
    node("Sp1", .spacer(minLength: nil)),
    node("-2", .text(content: "-2", style: nil), mods: [.font(style: nil, size: 9, weight: "medium", design: "monospaced"), .foregroundStyle(dimWhite)]),
    node("Sp2", .spacer(minLength: nil)),
    node("-1", .text(content: "-1", style: nil), mods: [.font(style: nil, size: 9, weight: "medium", design: "monospaced"), .foregroundStyle(dimWhite)]),
    node("Sp3", .spacer(minLength: nil)),
    node("0", .text(content: "0", style: nil), mods: [.font(style: nil, size: 10, weight: "bold", design: "monospaced"), .foregroundStyle(white)]),
    node("Sp4", .spacer(minLength: nil)),
    node("+1", .text(content: "+1", style: nil), mods: [.font(style: nil, size: 9, weight: "medium", design: "monospaced"), .foregroundStyle(dimWhite)]),
    node("Sp5", .spacer(minLength: nil)),
    node("+2", .text(content: "+2", style: nil), mods: [.font(style: nil, size: 9, weight: "medium", design: "monospaced"), .foregroundStyle(dimWhite)]),
    node("Sp6", .spacer(minLength: nil)),
    node("+3", .text(content: "+3", style: nil), mods: [.font(style: nil, size: 9, weight: "medium", design: "monospaced"), .foregroundStyle(dimWhite)]),
])

let lightMeter = node("Light Meter", .vStack(spacing: 4, alignment: "center"), mods: [
    .padding(edges: "horizontal", amount: 24),
    .padding(edges: "vertical", amount: 8),
], children: [
    node("LIGHT Label", .text(content: "LIGHT", style: nil), mods: [
        .font(style: nil, size: 9, weight: "semibold", design: "monospaced"),
        .foregroundStyle(dimWhite),
    ]),
    node("LM Glass Bar", .zStack(alignment: "center"), mods: [
        .frame(width: nil, height: 28, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
        .glassConfig(GlassConfig(style: "regular", tintColor: warmOrange, tintIntensity: 0.15, isInteractive: false, shape: "capsule")),
    ], children: [
        lightMeterTicks,
        // Red indicator line at center
        node("Indicator", .rectangle, mods: [
            .frame(width: 2, height: 16, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
            .foregroundStyle(redColor),
            .cornerRadius(1),
        ]),
    ]),
])

// --- Film simulation / ISO / SS row ---
let filmSimBtn = node("Film Sim", .hStack(spacing: 4, alignment: "center"), mods: [
    .padding(edges: "horizontal", amount: 14),
    .padding(edges: "vertical", amount: 8),
    .glassConfig(GlassConfig(style: "regular", tintColor: warmOrange, tintIntensity: 0.1, isInteractive: true, shape: "capsule")),
], children: [
    node("Film Name", .text(content: "Superia", style: nil), mods: [
        .font(style: nil, size: 14, weight: "semibold", design: nil),
        .foregroundStyle(white),
    ]),
    node("Chevron", .image(systemName: "chevron.down", assetName: nil), mods: [
        .font(style: nil, size: 10, weight: "bold", design: nil),
        .foregroundStyle(dimWhite),
    ]),
])

let photoLibBtn = node("Photo Lib", .image(systemName: "photo.on.rectangle.angled", assetName: nil), mods: [
    .font(style: nil, size: 18, weight: "medium", design: nil),
    .foregroundStyle(dimWhite),
    .frame(width: 40, height: 40, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
    .glassConfig(GlassConfig(style: "regular", tintColor: nil, tintIntensity: 0.15, isInteractive: true, shape: "roundedRectangle")),
])

let isoBtn = node("ISO Button", .hStack(spacing: 3, alignment: "center"), mods: [
    .padding(edges: "horizontal", amount: 12),
    .padding(edges: "vertical", amount: 8),
    .glassConfig(GlassConfig(style: "regular", tintColor: nil, tintIntensity: 0.15, isInteractive: true, shape: "capsule")),
], children: [
    node("ISO Label", .text(content: "ISO", style: nil), mods: [
        .font(style: nil, size: 11, weight: "medium", design: "monospaced"),
        .foregroundStyle(lightGray),
    ]),
    node("ISO Value", .text(content: "AUTO", style: nil), mods: [
        .font(style: nil, size: 13, weight: "semibold", design: nil),
        .foregroundStyle(white),
    ]),
])

let ssBtn = node("SS Button", .hStack(spacing: 3, alignment: "center"), mods: [
    .padding(edges: "horizontal", amount: 12),
    .padding(edges: "vertical", amount: 8),
    .glassConfig(GlassConfig(style: "regular", tintColor: nil, tintIntensity: 0.15, isInteractive: true, shape: "capsule")),
], children: [
    node("SS Label", .text(content: "SS", style: nil), mods: [
        .font(style: nil, size: 11, weight: "medium", design: "monospaced"),
        .foregroundStyle(lightGray),
    ]),
    node("SS Value", .text(content: "AUTO", style: nil), mods: [
        .font(style: nil, size: 13, weight: "semibold", design: nil),
        .foregroundStyle(white),
    ]),
])

let controlsRow = node("Controls Row", .hStack(spacing: 10, alignment: "center"), mods: [
    .padding(edges: "horizontal", amount: 16),
    .padding(edges: "vertical", amount: 4),
], children: [
    photoLibBtn,
    filmSimBtn,
    node("C Spacer", .spacer(minLength: nil)),
    isoBtn,
    ssBtn,
])

// --- Bottom bar: thumbnail, shutter, zoom ---
let thumbnail = node("Thumbnail", .zStack(alignment: "center"), mods: [
    .frame(width: 52, height: 52, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
], children: [
    node("Thumb BG", .circle, mods: [
        .foregroundStyle(midGray),
    ]),
    node("Thumb Icon", .image(systemName: "photo.fill", assetName: nil), mods: [
        .font(style: nil, size: 18, weight: "regular", design: nil),
        .foregroundStyle(dimWhite),
    ]),
])

// Shutter button — warm orange with glass ring
let shutterButton = node("Shutter Button", .zStack(alignment: "center"), mods: [
    .frame(width: 72, height: 72, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
], children: [
    // Outer glass ring
    node("Shutter Ring", .circle, mods: [
        .foregroundStyle(DesignColor.custom(red: 0, green: 0, blue: 0, opacity: 0.01)),
        .overlay("circle", color: warmOrange, lineWidth: 3),
        .glassConfig(GlassConfig(style: "regular", tintColor: warmOrange, tintIntensity: 0.2, isInteractive: true, shape: "circle")),
    ]),
    // Inner filled circle
    node("Shutter Fill", .circle, mods: [
        .frame(width: 58, height: 58, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
        .foregroundStyle(warmOrange),
    ]),
])

let zoomBtn = node("Zoom Button", .text(content: "1x", style: nil), mods: [
    .font(style: nil, size: 15, weight: "bold", design: "monospaced"),
    .foregroundStyle(white),
    .frame(width: 44, height: 44, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
    .glassConfig(GlassConfig(style: "regular", tintColor: nil, tintIntensity: 0.2, isInteractive: true, shape: "circle")),
])

let bottomBar = node("Bottom Bar", .hStack(spacing: 0, alignment: "center"), mods: [
    .padding(edges: "horizontal", amount: 32),
    .padding(edges: "vertical", amount: 16),
], children: [
    thumbnail,
    node("B Spacer1", .spacer(minLength: nil)),
    shutterButton,
    node("B Spacer2", .spacer(minLength: nil)),
    zoomBtn,
])

// --- Root layout ---
let rootElement = ElementNode(
    id: uuid(),
    name: "Root",
    payload: .zStack(alignment: "center"),
    modifiers: [
        .background(black),
    ],
    children: [
        node("Main VStack", .vStack(spacing: 0, alignment: "center"), mods: [
            .frame(width: nil, height: nil, minWidth: nil, maxWidth: nil, minHeight: nil, maxHeight: nil, alignment: nil),
        ], children: [
            topBar,
            viewfinder,
            node("Sp After VF", .spacer(minLength: 12)),
            lightMeter,
            node("Sp After LM", .spacer(minLength: 8)),
            controlsRow,
            node("Sp After Ctrl", .spacer(minLength: nil)),
            bottomBar,
        ]),
    ],
    isLocked: false,
    isVisible: true,
    booleanConfig: nil
)

// MARK: - Assemble Document

let page = DesignPage(
    id: uuid(),
    name: "Camera",
    deviceFrame: "iPhone16Pro",
    rootElement: rootElement,
    animationTimeline: AnimationTimeline(tracks: []),
    isDarkMode: true
)

let tokens = DesignTokenSet(
    spacingScale: [4, 8, 12, 16, 20, 24, 32, 40, 48],
    cornerRadii: [4, 8, 12, 16, 20, 24],
    accentColor: warmOrange,
    backgroundColor: black,
    textColor: white
)

let exportConfig = ExportConfig(
    projectName: "CameraApp",
    bundleIdentifier: "com.example.cameraapp",
    deploymentTarget: "26.0",
    organizationName: ""
)

let doc = DocumentData(pages: [page], tokens: tokens, exportConfig: exportConfig)

// MARK: - Encode & Save

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
encoder.nonConformingFloatEncodingStrategy = .convertToString(
    positiveInfinity: "inf",
    negativeInfinity: "-inf",
    nan: "nan"
)

do {
    let data = try encoder.encode(doc)
    let outputPath = CommandLine.arguments.count > 1
        ? CommandLine.arguments[1]
        : NSString("~/Documents/CameraApp.iosdesign").expandingTildeInPath
    try data.write(to: URL(fileURLWithPath: outputPath))
    print("✅ Saved to \(outputPath)")
} catch {
    print("❌ Error: \(error)")
    exit(1)
}
