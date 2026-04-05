# SpaceRenamer

A lightweight macOS menu bar app that lets you assign custom names to macOS Spaces (virtual desktops) and switch between them with keyboard shortcuts.

## Features

- **Custom Space Names** — Rename Spaces from the menu bar popover
- **Global Keyboard Shortcuts** — Switch between named Spaces with configurable hotkeys
- **Persistent HUD** — Always-visible widget showing the current Space name
- **Quick Rename** — Single hotkey to instantly rename the current Space
- **Launch at Login** — Optional auto-start on system boot
- **Multi-Monitor Support** — Per-Space names across multiple displays (HUD shows main display in v1)

## Architecture

### Core Components

1. **SpaceManager** — Manages Space state via private CGS APIs
2. **ShortcutManager** — Registers and handles global hotkeys via CGEvent tap
3. **PersistenceStore** — Stores configuration in `~/Library/Application Support/SpaceRenamer/config.json`
4. **MenuBarUI** — SwiftUI popover for configuration
5. **HUDPanel** — Floating NSPanel showing current Space name

### Data Model

```swift
struct SpaceInfo: Identifiable {
    let id: String              // ManagedSpaceID (UUID)
    let numericId: UInt64       // id64
    let displayUUID: String
    var position: Int           // 1-based
    var customName: String
    var shortcut: KeyCombo?
    var isActive: Bool
}
```

## Building

### Requirements

- macOS 14+ (Sonoma)
- Swift 5.9+
- Xcode 15+

### Build Steps

```bash
# Clone and navigate to project
cd window-rename

# Build
swift build

# Run
./.build/debug/SpaceRenamer
```

### Installation

```bash
# Create an app bundle (requires xcconfig setup)
# For now, run directly from build output
```

## Configuration

SpaceRenamer stores settings in `~/Library/Application Support/SpaceRenamer/config.json`:

```json
{
  "spaces": {
    "uuid-abc": { "name": "Development", "shortcut": "ctrl+opt+1" },
    "uuid-def": { "name": "Chat & Communication", "shortcut": "ctrl+opt+2" }
  },
  "quickRenameShortcut": "ctrl+opt+r",
  "launchAtLogin": true,
  "hudPosition": "topRight",
  "hudEnabled": true
}
```

## Permissions

The app requires **Accessibility** permission to intercept global keyboard shortcuts. On first launch, it will prompt you with a link to System Settings.

## Private APIs

The app uses private macOS APIs declared in `CGSPrivateAPI.h`:

- `CGSMainConnectionID()` — Connect to Core Graphics Server
- `CGSCopyManagedDisplaySpaces()` — List Spaces
- `CGSGetActiveSpace()` — Get active Space

These are resolved at runtime from the SkyLight framework (available in all GUI processes via dyld shared cache). No explicit framework linking is needed.

## Constraints (v1)

- No Mission Control name injection (requires SIP disabled)
- HUD shows main display only
- No custom Space icons
- No Mac App Store distribution (due to private API usage)

## Development

### Project Structure

```
Sources/SpaceRenamer/
├── SpaceRenamerApp.swift      # Main app entry point
├── SpaceManager.swift          # Space state management
├── ShortcutManager.swift       # Global hotkey handling
├── PersistenceStore.swift      # Config file I/O
├── MenuBarUI.swift             # SwiftUI popover UI
├── HUDPanel.swift              # Floating HUD widget
├── CGSPrivateAPI.h             # Private API declarations
└── Info.plist                  # App configuration
```

### Testing

The project is built with Swift Package Manager and uses SwiftUI previews for UI development.

## License

Private. All rights reserved.
