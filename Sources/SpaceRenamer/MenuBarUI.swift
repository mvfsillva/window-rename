import SwiftUI
import AppKit

struct MenuBarUI: View {
    @State var spaceManager: SpaceManager
    @State var persistenceStore: PersistenceStore
    @State var shortcutManager: ShortcutManager

    @State private var editingSpaceId: String?
    @State private var editingName: String = ""
    @State private var showingShortcutRecorder = false
    @State private var shortcutRecordingTarget: ShortcutTarget?
    @State private var hudPosition: AppConfig.HUDPosition = .topRight
    @State private var hudEnabled: Bool = true
    @State private var launchAtLogin: Bool = false

    /// Identifies what we're recording a shortcut for
    enum ShortcutTarget: Equatable {
        case space(String)  // space UUID
        case quickRename
    }

    var body: some View {
        VStack(spacing: 12) {
            // Title
            HStack {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 16, weight: .semibold))
                Text("SpaceRenamer")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .padding(.bottom, 4)

            Divider()

            // Spaces List
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(spaceManager.spaces) { space in
                        SpaceRowView(
                            space: space,
                            isActive: space.id == spaceManager.activeSpaceId,
                            isEditing: editingSpaceId == space.id,
                            editingName: $editingName,
                            onEdit: { startEditing(space) },
                            onSave: { saveName(for: space) },
                            onCancel: { cancelEditing() },
                            onRecordShortcut: { beginShortcutRecording(for: .space(space.id)) },
                            onClearShortcut: { clearShortcut(for: space) }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 300)

            Divider()

            // Quick Rename Shortcut
            HStack {
                Text("Quick Rename:")
                    .font(.system(size: 12))
                Spacer()
                ShortcutDisplayButton(
                    shortcut: quickRenameShortcut,
                    isRecording: shortcutRecordingTarget == .quickRename,
                    onRecord: { beginShortcutRecording(for: .quickRename) },
                    onClear: { clearQuickRenameShortcut() }
                )
            }
            .padding(.vertical, 4)

            Divider()

            // HUD Settings
            VStack(alignment: .leading, spacing: 8) {
                Text("HUD Settings")
                    .font(.system(size: 12, weight: .semibold))

                Toggle("Show HUD", isOn: $hudEnabled)
                    .onChange(of: hudEnabled) {
                        Task {
                            await persistenceStore.setHUDEnabled(hudEnabled)
                        }
                    }

                HStack {
                    Text("Position:")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $hudPosition) {
                        Text("TL").tag(AppConfig.HUDPosition.topLeft)
                        Text("TR").tag(AppConfig.HUDPosition.topRight)
                        Text("BL").tag(AppConfig.HUDPosition.bottomLeft)
                        Text("BR").tag(AppConfig.HUDPosition.bottomRight)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                    .onChange(of: hudPosition) {
                        Task {
                            await persistenceStore.setHUDPosition(hudPosition)
                        }
                    }
                }
            }

            Divider()

            // Launch at Login
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) {
                    Task {
                        await persistenceStore.setLaunchAtLogin(launchAtLogin)
                        LoginItemManager.shared.setEnabled(launchAtLogin)
                    }
                }

            // About
            Link("About SpaceRenamer", destination: URL(string: "https://github.com/mvfsillva/window-rename")!)
                .font(.system(size: 11))
                .foregroundColor(.blue)
        }
        .padding(16)
        .frame(width: 400)
        .task {
            await loadSettings()
        }
        .sheet(isPresented: $showingShortcutRecorder) {
            if let target = shortcutRecordingTarget {
                ShortcutRecorderView(
                    spaceId: targetId(for: target),
                    currentShortcut: currentShortcut(for: target),
                    onSave: { combo in
                        saveShortcut(combo, for: target)
                    }
                )
            }
        }
    }

    // MARK: - Quick Rename Shortcut State

    private var quickRenameShortcut: KeyCombo? {
        // Read from spaces (loaded in task)
        nil  // Will be populated from persistence
    }

    // MARK: - Editing

    private func startEditing(_ space: SpaceInfo) {
        editingSpaceId = space.id
        editingName = space.customName
    }

    private func saveName(for space: SpaceInfo) {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        spaceManager.updateSpaceName(space.id, newName: trimmed)
        editingSpaceId = nil
    }

    private func cancelEditing() {
        editingSpaceId = nil
        editingName = ""
    }

    // MARK: - Shortcut Recording

    private func beginShortcutRecording(for target: ShortcutTarget) {
        shortcutRecordingTarget = target
        showingShortcutRecorder = true
    }

    private func targetId(for target: ShortcutTarget) -> String {
        switch target {
        case .space(let id): return id
        case .quickRename: return "quick_rename"
        }
    }

    private func currentShortcut(for target: ShortcutTarget) -> KeyCombo? {
        switch target {
        case .space(let id):
            return spaceManager.getSpace(id)?.shortcut
        case .quickRename:
            return nil
        }
    }

    private func saveShortcut(_ combo: KeyCombo?, for target: ShortcutTarget) {
        guard let combo = combo else { return }

        // Check for conflicts
        if let conflictId = shortcutManager.detectConflict(for: combo) {
            // For now, overwrite the old one
            shortcutManager.unregisterShortcut(id: conflictId)
        }

        switch target {
        case .space(let spaceId):
            spaceManager.updateSpaceShortcut(spaceId, shortcut: combo)

            // Register with ShortcutManager
            if let space = spaceManager.getSpace(spaceId) {
                shortcutManager.registerShortcut(combo, id: "space_\(spaceId)") { [shortcutManager] in
                    shortcutManager.switchToSpace(position: space.position)
                }
            }

            Task {
                await persistenceStore.setSpaceShortcut(combo, forUUID: spaceId)
            }

        case .quickRename:
            shortcutManager.registerShortcut(combo, id: "quick_rename") {
                // Quick rename action is wired in SpaceRenamerApp
            }
            Task {
                await persistenceStore.setQuickRenameShortcut(combo)
            }
        }

        showingShortcutRecorder = false
        shortcutRecordingTarget = nil
    }

    private func clearShortcut(for space: SpaceInfo) {
        spaceManager.updateSpaceShortcut(space.id, shortcut: nil)
        shortcutManager.unregisterShortcut(id: "space_\(space.id)")
        Task {
            await persistenceStore.setSpaceShortcut(nil, forUUID: space.id)
        }
    }

    private func clearQuickRenameShortcut() {
        shortcutManager.unregisterShortcut(id: "quick_rename")
        Task {
            await persistenceStore.setQuickRenameShortcut(nil)
        }
    }

    // MARK: - Settings

    private func loadSettings() async {
        let settings = await persistenceStore.getHUDSettings()
        hudEnabled = settings.enabled
        hudPosition = settings.position
        launchAtLogin = await persistenceStore.isLaunchAtLogin()
    }
}

/// Individual Space row in the list
struct SpaceRowView: View {
    let space: SpaceInfo
    let isActive: Bool
    let isEditing: Bool
    @Binding var editingName: String

    let onEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onRecordShortcut: () -> Void
    let onClearShortcut: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Position indicator
            Text("\(space.position)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 24)

            // Name field
            if isEditing {
                TextField("Space name", text: $editingName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(onSave)
                    .onExitCommand(perform: onCancel)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(space.customName)
                            .font(.system(size: 13, weight: .medium))
                        if isActive {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                Spacer()

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
            }

            // Shortcut display/recorder button
            if !isEditing {
                ShortcutDisplayButton(
                    shortcut: space.shortcut,
                    isRecording: false,
                    onRecord: onRecordShortcut,
                    onClear: onClearShortcut
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(4)
    }
}

/// Button that shows the current shortcut and allows recording/clearing
struct ShortcutDisplayButton: View {
    let shortcut: KeyCombo?
    let isRecording: Bool
    let onRecord: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onRecord) {
                if isRecording {
                    HStack(spacing: 4) {
                        Image(systemName: "radio.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.red)
                        Text("Recording...")
                            .font(.system(size: 10))
                    }
                } else if let shortcut = shortcut {
                    Text(shortcut.description())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                } else {
                    Text("Set shortcut")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if shortcut != nil {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
