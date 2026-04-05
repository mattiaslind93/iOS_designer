# iOS Designer

macOS app for visually designing iPhone apps targeting iOS 26, with SwiftUI code export.

## Architecture

Modular SPM workspace with 7 packages:

- **DesignModel** — Core data types (ElementNode, DesignDocument, DeviceFrame, etc). No UI dependencies.
- **CanvasEngine** — Zoomable canvas, phone frame rendering, element renderer, selection overlay.
- **ComponentLibrary** — Categorized component sidebar with drag-and-drop support.
- **PropertyInspector** — Editable property panels (layout, appearance, typography, effects).
- **LayerPanel** — Tree-view of element hierarchy with visibility/lock toggles.
- **AnimationEditor** — Keynote-like timeline with animation presets.
- **CodeExport** — Recursive SwiftUI code emitter and Xcode project generator.

All feature packages depend only on DesignModel, never on each other.

## Key Design Decisions

- **ElementNode** is a recursive tree struct with an **ElementPayload** enum + ordered **DesignModifier** stack. This directly mirrors SwiftUI's view + modifier chain.
- **DesignDocument** is a ReferenceFileDocument using JSON serialization.
- Canvas renders on macOS but targets iOS 26 visual design (Liquid Glass is approximated).
- Code export generates complete Xcode-ready projects.

## Building

```bash
# Build individual package
cd Packages/DesignModel && swift build

# Run tests
cd Packages/DesignModel && swift test

# Full app requires Xcode (document-based macOS app)
open iOSDesigner/ in Xcode
```

## iOS 26 Design Guidelines

- 8pt grid system for all spacing
- SF Pro typography with Dynamic Type support
- Liquid Glass only on navigation layer (tabs, nav bars, toolbars)
- Content-first philosophy
- Semantic colors for dark/light mode adaptation
