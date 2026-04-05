import SwiftUI
import AppKit

@main
struct SpaceRenamerApp: App {
    @State private var spaceManager = SpaceManager()
    @State private var persistenceStore = PersistenceStore()
    @State private var shortcutManager = ShortcutManager()
    @State private var hudPanel: HUDPanel?
    @State private var hasSetupHUD = false

    var body: some Scene {
        MenuBarExtra("SpaceRenamer", systemImage: "desktopcomputer") {
            MenuBarUI(
                spaceManager: spaceManager,
                persistenceStore: persistenceStore,
                shortcutManager: shortcutManager
            )
            .task {
                await setupHUDIfNeeded()
                setupSpaceChangeNotifications()
            }
        }
        .defaultPosition(.trailing)
        .menuBarExtraStyle(.window)
    }

    private func setupHUDIfNeeded() async {
        guard !hasSetupHUD else { return }
        hasSetupHUD = true

        let settings = await persistenceStore.getHUDSettings()
        if settings.enabled {
            await MainActor.run {
                let panel = HUDPanel(spaceManager: spaceManager, position: settings.position)
                panel.orderFrontRegardless()
                hudPanel = panel
            }
        }
    }

    private func setupSpaceChangeNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            spaceManager.updateSpaces()
            if let activeSpaceId = spaceManager.activeSpaceId,
               let space = spaceManager.getSpace(activeSpaceId) {
                hudPanel?.updateSpaceName(space.customName)
            }
        }
    }
}
