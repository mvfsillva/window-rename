# SpaceRenamer Project Context

## Project Overview

SpaceRenamer is a lightweight macOS menu bar app that lets users assign custom names to macOS Spaces (virtual desktops) and switch between them with keyboard shortcuts. A persistent HUD widget shows the current Space name on screen.

The detailed design specification is at: `docs/superpowers/specs/2026-04-05-space-renamer-design.md`

## Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI (macOS 14+ / Sonoma minimum)
- **Private APIs:** CGSSpace APIs, CGEvent for global hotkeys
- **Permissions:** Accessibility (for global hotkey interception)
- **Distribution:** DMG download, Code signed with Developer ID
- **Storage:** JSON config at `~/Library/Application Support/SpaceRenamer/config.json`

## Architecture

### Core Components

1. **SpaceManager** — `@Observable` class managing all Space state
   - List Spaces via `CGSCopyManagedDisplaySpaces`
   - Detect active Space via `CGSGetActiveSpace`
   - React to Space switches via `NSWorkspace.activeSpaceDidChangeNotification`
   - Poll for topology changes every 3 seconds

2. **ShortcutManager** — Global hotkey registration via `CGEvent` tap
   - Per-Space "switch to Space X" shortcuts
   - Single "quick rename current Space" shortcut
   - Conflict detection and recording

3. **PersistenceStore** — JSON config file management
   - Space name mappings (UUID-based, not position-based)
   - Shortcut bindings
   - HUD preferences and app settings

4. **MenuBarUI** — SwiftUI popover
   - List all Spaces with inline name editing
   - Shortcut recording interface
   - HUD corner picker and enable/disable toggle
   - "Launch at Login" toggle

5. **HUDPanel** — NSPanel floating widget
   - Persistent display of current Space name
   - Corner positioning (top-left, top-right, bottom-left, bottom-right)
   - Semi-transparent blurred background with vibrancy
   - Crossfade animation on Space switch

### Data Model

```swift
struct SpaceInfo: Identifiable {
    let uuid: String          // stable ManagedSpaceID
    let numericId: UInt64     // id64
    var displayUUID: String
    var position: Int         // 1-based index
    var customName: String    // user-editable
    var shortcut: KeyCombo?   // optional hotkey
    var isActive: Bool
}
```

## Key Constraints

- **No Mission Control injection** — Names shown only in app HUD/menu bar (stable, no SIP required)
- **Space identity via UUID** — Names follow Spaces even if reordered
- **Multi-monitor support** — Per-Space per-display names, but HUD shows main display only (v1)
- **Accessibility required** — Needed for global hotkey interception
- **Private APIs** — App not eligible for Mac App Store

## Conventions

- Use `@Observable` and reactive SwiftUI patterns
- Debounce config file writes (0.5s)
- UUID-based identification for stable persistence
- SGF Symbol `desktopcomputer` for menu bar icon
- Auto-assign new Spaces as "Desktop N" matching macOS defaults
- Retain removed Space configs for 30 days before cleanup

## Out of Scope (v1)

- Mission Control name injection
- Per-display HUD widgets
- Custom icons per Space
- Space creation/deletion UI
- Window management
- Mac App Store support
