import SwiftUI
import AppKit

@main
struct SpaceRenamerApp: App {
    @State private var spaceManager: SpaceManager?
    @State private var persistenceStore: PersistenceStore?
    @State private var shortcutManager: ShortcutManager?
    @State private var hudPanel: HUDPanel?
    
    var body: some Scene {
        MenuBarExtra("SpaceRenamer", systemImage: "desktopcomputer") {
            if let spaceManager = spaceManager,
               let persistenceStore = persistenceStore,
               let shortcutManager = shortcutManager {
                MenuBarUI(
                    spaceManager: spaceManager,
                    persistenceStore: persistenceStore,
                    shortcutManager: shortcutManager
                )
            }
        }
        .defaultPosition(.trailing)
        .menuBarExtraStyle(.window)
    }
    
    init() {
        // Disable dock icon (LSUIElement is set in Info.plist)
        setupApp()
    }
    
    private func setupApp() {
        // Initialize core managers
        let spaceManager = SpaceManager()
        let persistenceStore = PersistenceStore()
        let shortcutManager = ShortcutManager()
        
        self._spaceManager = State(initialValue: spaceManager)
        self._persistenceStore = State(initialValue: persistenceStore)
        self._shortcutManager = State(initialValue: shortcutManager)
        
        // Create HUD panel
        let (hudEnabled, hudPosition) = Task {
            await persistenceStore.getHUDSettings()
        }
        
        // Note: HUD creation should happen on main thread
        DispatchQueue.main.async {
            if hudEnabled.enabled {
                let hudPanel = HUDPanel(spaceManager: spaceManager, position: hudEnabled.position)
                hudPanel.makeKeyAndOrderFront(nil)
                self._hudPanel = State(initialValue: hudPanel)
            }
        }
        
        // Setup notifications for Space changes
        setupSpaceChangeNotifications(spaceManager: spaceManager)
    }
    
    private func setupSpaceChangeNotifications(spaceManager: SpaceManager) {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self,
                  let spaceManager = self.spaceManager,
                  let hudPanel = self.hudPanel else { return }
            
            if let activeSpaceId = spaceManager.activeSpaceId,
               let space = spaceManager.getSpace(activeSpaceId) {
                hudPanel.updateSpaceName(space.customName)
            }
        }
    }
}

// MARK: - App Info Plist Configuration

/*
 The app requires the following Info.plist settings:
 
 - LSUIElement = true (to hide from dock)
 - NSRequiresIPhoneOS = false
 - UIApplicationSupportsIndependentWindowScenes = false
 
 Required permissions:
 - NSAccessibilityUsageDescription: "SpaceRenamer needs Accessibility access to intercept global keyboard shortcuts for switching between named Spaces and quick renaming."
 */
