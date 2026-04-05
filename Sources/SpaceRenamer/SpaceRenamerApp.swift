import SwiftUI
import AppKit

@main
struct SpaceRenamerApp: App {
    @State private var spaceManager = SpaceManager()
    @State private var persistenceStore = PersistenceStore()
    @State private var shortcutManager = ShortcutManager()
    @State private var hudPanel: HUDPanel?
    @State private var quickRenamePanel = QuickRenamePanel()
    @State private var hasCompletedSetup = false

    var body: some Scene {
        MenuBarExtra("SpaceRenamer", systemImage: "desktopcomputer") {
            MenuBarUI(
                spaceManager: spaceManager,
                persistenceStore: persistenceStore,
                shortcutManager: shortcutManager
            )
            .task {
                await initialSetup()
            }
        }
        .defaultPosition(.trailing)
        .menuBarExtraStyle(.window)
    }

    /// One-time setup: load persistence, create HUD, wire callbacks, register shortcuts
    private func initialSetup() async {
        guard !hasCompletedSetup else { return }
        hasCompletedSetup = true

        // 1. Sync Launch at Login state from system
        let systemLoginEnabled = LoginItemManager.shared.isEnabled
        let storedLoginEnabled = await persistenceStore.isLaunchAtLogin()
        if systemLoginEnabled != storedLoginEnabled {
            await persistenceStore.setLaunchAtLogin(systemLoginEnabled)
        }

        // 2. Load saved space configs and apply to SpaceManager
        let savedConfigs = await persistenceStore.getAllSpaceConfigs()
        spaceManager.loadSavedConfigs(savedConfigs)

        // 3. Run initial cleanup of stale Space configs (30-day retention)
        let currentUUIDs = Set(spaceManager.spaces.map(\.id))
        await persistenceStore.updateLastSeen(activeUUIDs: currentUUIDs)
        await persistenceStore.cleanupRemovedSpaces(activeUUIDs: currentUUIDs)

        // 4. Wire SpaceManager callbacks for persistence
        spaceManager.onSpaceUpdated = { [persistenceStore] space in
            Task {
                await persistenceStore.setSpaceName(space.customName, forUUID: space.id)
                await persistenceStore.setSpaceShortcut(space.shortcut, forUUID: space.id)
            }
        }

        // 5. Wire space-refresh callback to update lastSeen timestamps and run cleanup
        spaceManager.onSpacesRefreshed = { [persistenceStore] activeUUIDs in
            Task {
                await persistenceStore.updateLastSeen(activeUUIDs: activeUUIDs)
                await persistenceStore.cleanupRemovedSpaces(activeUUIDs: activeUUIDs)
            }
        }

        // 6. Register saved shortcuts with ShortcutManager
        registerShortcutsFromConfig(savedConfigs)

        // 7. Register quick rename shortcut
        if let quickRename = await persistenceStore.getQuickRenameShortcut() {
            registerQuickRenameShortcut(quickRename)
        }

        // 8. Setup HUD
        let hudSettings = await persistenceStore.getHUDSettings()
        if hudSettings.enabled {
            let panel = HUDPanel(spaceManager: spaceManager, position: hudSettings.position)
            panel.orderFrontRegardless()
            hudPanel = panel
        }

        // 9. Wire active space change to HUD updates
        spaceManager.onActiveSpaceChanged = { [weak hudPanel] activeSpace in
            if let name = activeSpace?.customName {
                hudPanel?.updateSpaceName(name)
            }
        }
    }

    /// Register per-Space switch shortcuts from saved config
    private func registerShortcutsFromConfig(_ configs: [String: AppConfig.SpaceConfig]) {
        for space in spaceManager.spaces {
            if let shortcut = space.shortcut {
                shortcutManager.registerShortcut(shortcut, id: ShortcutID.space(space.id)) { [shortcutManager] in
                    shortcutManager.switchToSpace(position: space.position)
                }
            }
        }
    }

    /// Register the quick rename shortcut to show the floating rename panel
    private func registerQuickRenameShortcut(_ combo: KeyCombo) {
        shortcutManager.registerShortcut(combo, id: ShortcutID.quickRename) { [spaceManager, persistenceStore, quickRenamePanel] in
            guard let activeId = spaceManager.activeSpaceId,
                  let space = spaceManager.getSpace(activeId) else { return }

            quickRenamePanel.show(
                currentName: space.customName,
                onRename: { newName in
                    spaceManager.updateSpaceName(activeId, newName: newName)
                    Task {
                        await persistenceStore.setSpaceName(newName, forUUID: activeId)
                    }
                },
                onDismiss: {}
            )
        }
    }
}
