# SpaceRenamer — macOS Space Naming App

## Problem

macOS labels Spaces generically as "Desktop 1", "Desktop 2", etc. There's no native way to rename them, making it hard to identify desktops when using multiple for different purposes.

## Solution

A lightweight menu bar app that lets you assign custom names to macOS Spaces. A persistent HUD widget shows the current Space name on screen. Configurable keyboard shortcuts let you switch between named Spaces and trigger quick renaming.

**Key constraint:** Writing custom names into Mission Control's UI is not possible without disabling SIP and injecting code into Dock.app. This app takes the stable, no-SIP approach: names are shown via the app's own HUD and menu bar UI, not in Mission Control itself.

## Architecture

### App Type

Menu bar-only macOS app (no dock icon via `LSUIElement = true`, no main window). Built with SwiftUI lifecycle using `MenuBarExtra`. Minimum macOS 14 (Sonoma).

### Core Components

1. **SpaceManager** — `@Observable` class that owns all Space state. Interfaces with private `CGSSpace` APIs to:
   - List current Spaces via `CGSCopyManagedDisplaySpaces`
   - Read Space UUIDs (`ManagedSpaceID`) for stable identity
   - Detect the active Space via `CGSGetActiveSpace`
   - React to Space switches via `NSWorkspace.activeSpaceDidChangeNotification`
   - Poll for topology changes (new/removed Spaces) every 3 seconds

2. **ShortcutManager** — Registers and manages global hotkeys via `CGEvent` tap (requires Accessibility permission). Handles:
   - Per-Space "switch to Space X" shortcuts (simulates macOS built-in Desktop shortcuts via CGEvents)
   - A single "quick rename current Space" shortcut

3. **PersistenceStore** — Reads/writes a JSON config file at `~/Library/Application Support/SpaceRenamer/config.json`. Stores Space name mappings (UUID-based), shortcut bindings, HUD preferences, and app preferences.

4. **MenuBarUI** — SwiftUI popover with inline editing for Space names, shortcut recording, HUD settings, and app settings.

5. **HUDPanel** — `NSPanel`-based floating widget that persistently shows the current Space name in a corner of the screen.

### Private API Access

Declared via an Objective-C bridging header:

```c
typedef int CGSConnectionID;
typedef uint64_t CGSSpaceID;

extern CGSConnectionID CGSMainConnectionID(void);
extern CFArrayRef CGSCopyManagedDisplaySpaces(CGSConnectionID cid);
extern CGSSpaceID CGSGetActiveSpace(CGSConnectionID cid);
```

These symbols are resolved at runtime from the SkyLight framework (loaded into every GUI process via dyld shared cache). No explicit framework linking needed.

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

### Data Flow

```
NSWorkspace.activeSpaceDidChangeNotification (instant)
+ CGSCopyManagedDisplaySpaces poll (every 3s)
        |
        v
SpaceManager diffs against cached state
        |
        v
Merge with PersistenceStore (known names + defaults for new Spaces)
        |
        v
MenuBarUI + HUDPanel update reactively via @Observable
        |
        v
User edits name, shortcut, or settings
        |
        v
PersistenceStore saves to disk (debounced 0.5s)
```

## Space Identity

Spaces have stable UUIDs (`ManagedSpaceID`). Names are mapped to UUIDs, not positions. If the user reorders Spaces, the name follows the Space.

## Multi-Monitor

Each display has its own Space list. The app tracks them independently — names are per-Space, per-display. The HUD shows the active Space name for the main display only (v1).

The `"Main"` display identifier returned by `CGSCopyManagedDisplaySpaces` is resolved to `NSScreen.main`'s UUID. When "Displays have separate Spaces" is disabled, all displays share one Space set — handled transparently.

## HUD Widget

### Implementation

`NSPanel` with styles:
- `.nonactivatingPanel` — doesn't steal focus
- `.floating` — stays above normal windows
- `.canJoinAllSpaces` collection behavior — visible on all Spaces

Contains an `NSHostingView` with a SwiftUI view. Uses `NSVisualEffectView` for semi-transparent blurred background.

### Appearance

- Small pill/rounded rectangle showing the current Space name
- Semi-transparent background with vibrancy (native blur material)
- Respects light/dark mode
- Crossfade animation when the Space name changes
- Auto-sized to text content

### Positioning

- Pinned to user's chosen corner: `topLeft`, `topRight`, `bottomLeft`, `bottomRight`
- Default: `topRight`
- 12pt margin from screen edges
- Position preference stored in config

## Menu Bar UI

### Icon

SF Symbol `desktopcomputer` in the menu bar. Click to open popover.

### Popover Layout

| Column | Content |
|--------|---------|
| # | Space position number (1, 2, 3...) |
| Name | Editable text field. Active Space has an accent-colored dot indicator. |
| Shortcut | Recorder button. Click, press key combo, saved. Click again to clear/re-record. |

Spaces grouped by display if multi-monitor.

### Below the List

- Quick rename shortcut config row (recorder button)
- HUD settings: corner picker (4-option segmented control), enable/disable toggle
- "Launch at Login" toggle
- "About" link

### Quick Rename Flow

1. User presses the quick rename hotkey (e.g., `Ctrl+Opt+R`)
2. A small floating `NSPanel` appears center-screen (Spotlight-style)
3. Pre-filled with the current Space name, text selected
4. User types new name, presses Enter — name is saved
5. Escape or focus loss cancels

## Keyboard Shortcuts

### Implementation

Global hotkeys via `CGEvent.tapCreate` (requires Accessibility permission). Same approach used by Rectangle, Raycast, and similar utilities.

### Types

1. **Switch to Space X** — One configurable shortcut per Space. When triggered, the app simulates the corresponding macOS built-in shortcut (e.g., `Ctrl+1` for Desktop 1) via `CGEvent` posting. The app maps the Space's current position to the correct macOS shortcut. Requires the user to have "Switch to Desktop N" shortcuts enabled in System Settings > Keyboard > Shortcuts > Mission Control.
2. **Quick rename** — Single global hotkey opens the floating rename field for the current Space.

### Recording

Standard macOS shortcut recorder UX: click the field, press your desired key combination (e.g., `Ctrl+Opt+1`), saves immediately. Click again to clear or re-record.

### Conflict Detection

If a shortcut conflicts with an existing binding in the app, warn the user and ask for confirmation before saving.

## Persistence

### Config File

Location: `~/Library/Application Support/SpaceRenamer/config.json`

```json
{
  "spaces": {
    "uuid-abc": { "name": "Gord App", "shortcut": "ctrl+opt+1" },
    "uuid-def": { "name": "Docs and Personal", "shortcut": "ctrl+opt+2" }
  },
  "quickRenameShortcut": "ctrl+opt+r",
  "launchAtLogin": true,
  "hudPosition": "topRight",
  "hudEnabled": true
}
```

### New Spaces

When a new Space UUID appears, the app assigns it "Desktop N" where N is the Space's current position number, matching the macOS default label. No prompt — the user renames when ready.

### Removed Spaces

When a Space UUID disappears, its config entry is retained for 30 days (in case it reappears after reboot/reorder), then cleaned up.

### Re-apply on Wake/Restart

The app re-reads all Spaces and merges with persisted config on launch and on `NSWorkspace.didWakeNotification`.

## Accessibility Permission

### Flow

1. On first launch, check `AXIsProcessTrusted()`
2. If not trusted, show a guided alert explaining that Accessibility permission is needed for global hotkeys
3. Deep link to System Settings > Privacy & Security > Accessibility
4. Poll `AXIsProcessTrusted()` to detect when granted, then activate the CGEvent tap

### Why Required

`CGEvent` tap for global hotkey interception requires Accessibility permission. Without it, the app still works for naming Spaces via the menu bar popover, but hotkeys (switching and quick rename) are disabled.

## Launch at Login

Uses `SMAppService` (modern macOS login items API). Toggled from the menu bar popover.

## Distribution

- **Primary**: DMG download from GitHub or project website
- **Secondary**: Homebrew cask (can add later)
- **Not eligible**: Mac App Store (private API usage)
- **Code signing**: Developer ID certificate recommended to avoid Gatekeeper warnings

### Minimum macOS Version

macOS 14 (Sonoma). Ensures `MenuBarExtra`, `SMAppService`, and `@Observable` support.

## V2 — Mission Control Name Integration

### Goal

Show custom Space names directly in Mission Control, replacing the default "Desktop 1", "Desktop 2", etc. labels. This removes the need for users to rely solely on the HUD or menu bar to identify their Spaces.

### Approach

Use the `CGSSpaceSetName` private API from the SkyLight framework. This is the same framework already used in v1 for `CGSMainConnectionID`, `CGSCopyManagedDisplaySpaces`, and `CGSGetActiveSpace`. No SIP disable is required — unlike SIMBL/Dock injection approaches, `CGSSpaceSetName` works with SIP enabled and needs no special entitlements or root access.

New bridging header declaration:

```c
extern void CGSSpaceSetName(CGSConnectionID cid, CGSSpaceID sid, CFStringRef name);
```

### How It Works

1. **On rename** — When the user renames a Space (via popover or quick rename), `SpaceManager` calls `CGSSpaceSetName(cid, sid, name)` to push the custom name to the system immediately. Mission Control reflects the new name the next time it is opened.
2. **On app launch** — All saved custom names from `PersistenceStore` are re-applied via `CGSSpaceSetName` so that Mission Control shows the correct labels from startup.
3. **On topology refresh** — Every Space refresh cycle (3-second poll, `activeSpaceDidChangeNotification`, `didWakeNotification`) re-applies all custom names. This ensures names survive Dock restarts, display configuration changes, and sleep/wake cycles.

### Limitations

- **Names persist only until the Dock process restarts.** The WindowServer does not persist names set via `CGSSpaceSetName` across Dock restarts. SpaceRenamer must be running to maintain them.
- **If SpaceRenamer quits**, names revert to "Desktop N" the next time the Dock process restarts (e.g., on reboot or `killall Dock`). While the app is not running, Mission Control shows default labels. Re-launching SpaceRenamer restores all saved names.
- **Private API compatibility.** `CGSSpaceSetName` is a private SkyLight API tested on macOS 14 (Sonoma). As an undocumented API, it may change or be removed in future macOS versions.
- **Graceful degradation.** If `CGSSpaceSetName` is removed in a future macOS release, the app continues to function normally for HUD and menu bar Space naming. Only the Mission Control label injection degrades — users would see the default "Desktop N" labels in Mission Control while custom names remain visible in the HUD and menu bar.

### Alternatives Considered

| Approach | Why rejected |
|----------|-------------|
| **SIMBL Dock injection** | Requires disabling SIP to inject code into Dock.app. Breaks on every macOS update. Not viable for general distribution. |
| **Accessibility API** | Could overlay text on Mission Control labels, but causes visual flicker, requires precise coordinate tracking, and is fragile across macOS versions. |
| **Plist modification** | Editing `com.apple.spaces.plist` or `com.apple.dock.plist` can store names but does not update the Mission Control UI without a Dock restart, causing a disruptive visual reset. |
| **WindowServer IPC** | Direct Mach message manipulation of WindowServer is extremely fragile, undocumented, and changes between macOS releases. |

### Changes to "Out of Scope (v1)"

With v2, the following item moves from out-of-scope to implemented:

- ~~Mission Control name injection (requires SIP disabled)~~ — Now supported via `CGSSpaceSetName` without SIP disable.

## Out of Scope (v1)

- ~~Mission Control name injection (requires SIP disabled)~~ — Resolved in V2 via `CGSSpaceSetName` (see above)
- Per-display HUD widgets (only main display in v1)
- Custom icons per Space
- Space creation/deletion from within the app
- Drag-to-reorder Spaces
- Window management features
- App Store distribution
