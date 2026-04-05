import SwiftUI
import AppKit

struct MenuBarUI: View {
    @State var spaceManager: SpaceManager
    @State var persistenceStore: PersistenceStore
    @State var shortcutManager: ShortcutManager
    
    @State private var editingSpaceId: String?
    @State private var editingName: String = ""
    @State private var recordingShortcutId: String?
    @State private var hudPosition: AppConfig.HUDPosition = .topRight
    @State private var hudEnabled: Bool = true
    @State private var launchAtLogin: Bool = false
    
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
                            recordingShortcutId: $recordingShortcutId,
                            onEdit: { startEditing(space) },
                            onSave: { saveName(for: space) },
                            onCancel: { cancelEditing() },
                            onRecordShortcut: { recordShortcut(for: space) }
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
                ShortcutButton(
                    isRecording: recordingShortcutId == "quick_rename",
                    onRecord: { recordQuickRenameShortcut() }
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
                        Text("Top Left").tag(AppConfig.HUDPosition.topLeft)
                        Text("Top Right").tag(AppConfig.HUDPosition.topRight)
                        Text("Bottom Left").tag(AppConfig.HUDPosition.bottomLeft)
                        Text("Bottom Right").tag(AppConfig.HUDPosition.bottomRight)
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
                    }
                }
            
            // About
            Link("About SpaceRenamer", destination: URL(string: "https://github.com")!)
                .font(.system(size: 11))
                .foregroundColor(.blue)
        }
        .padding(16)
        .frame(width: 400)
        .task {
            await loadSettings()
        }
    }
    
    private func startEditing(_ space: SpaceInfo) {
        editingSpaceId = space.id
        editingName = space.customName
    }
    
    private func saveName(for space: SpaceInfo) {
        spaceManager.updateSpaceName(space.id, newName: editingName)
        Task {
            await persistenceStore.setSpaceName(editingName, forUUID: space.id)
        }
        editingSpaceId = nil
    }
    
    private func cancelEditing() {
        editingSpaceId = nil
        editingName = ""
    }
    
    private func recordShortcut(for space: SpaceInfo) {
        recordingShortcutId = space.id
        // TODO: Show shortcut recorder dialog
    }
    
    private func recordQuickRenameShortcut() {
        recordingShortcutId = "quick_rename"
        // TODO: Show shortcut recorder dialog
    }
    
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
    @Binding var recordingShortcutId: String?
    
    let onEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onRecordShortcut: () -> Void
    
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
                    if let shortcut = space.shortcut {
                        Text(shortcut.description())
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
            }
            
            // Shortcut recorder button
            if !isEditing {
                ShortcutButton(
                    isRecording: recordingShortcutId == space.id,
                    onRecord: onRecordShortcut
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(4)
    }
}

/// Shortcut recorder button
struct ShortcutButton: View {
    let isRecording: Bool
    let onRecord: () -> Void
    
    var body: some View {
        Button(action: onRecord) {
            Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                .font(.system(size: 12))
                .foregroundColor(isRecording ? .red : .blue)
        }
        .buttonStyle(.borderless)
        .help(isRecording ? "Recording..." : "Record shortcut")
    }
}

#Preview {
    MenuBarUI(
        spaceManager: SpaceManager(),
        persistenceStore: PersistenceStore(),
        shortcutManager: ShortcutManager()
    )
}
