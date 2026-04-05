import Foundation

/// Represents the complete app configuration
struct AppConfig: Codable {
    struct SpaceConfig: Codable {
        var name: String
        var shortcut: KeyCombo?
    }
    
    var spaces: [String: SpaceConfig] = [:]
    var quickRenameShortcut: KeyCombo?
    var launchAtLogin: Bool = false
    var hudPosition: HUDPosition = .topRight
    var hudEnabled: Bool = true
    
    enum HUDPosition: String, Codable {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
}

/// Manages persistence of app configuration to disk
actor PersistenceStore {
    private let configURL: URL
    private var config: AppConfig
    private var saveTask: Task<Void, Never>?
    
    nonisolated private let saveDebounceInterval: TimeInterval = 0.5
    
    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let appDir = appSupport.appendingPathComponent("SpaceRenamer", isDirectory: true)
        self.configURL = appDir.appendingPathComponent("config.json")
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        // Load existing config or create new
        if FileManager.default.fileExists(atPath: configURL.path) {
            if let data = try? Data(contentsOf: configURL),
               let loaded = try? JSONDecoder().decode(AppConfig.self, from: data) {
                self.config = loaded
            } else {
                self.config = AppConfig()
            }
        } else {
            self.config = AppConfig()
            // Initial save deferred to first actor-isolated call
        }
    }
    
    // MARK: - Space Configuration

    /// Get all saved space configs for bulk loading into SpaceManager
    func getAllSpaceConfigs() -> [String: AppConfig.SpaceConfig] {
        config.spaces
    }

    func getSpaceConfig(forUUID uuid: String) -> AppConfig.SpaceConfig? {
        config.spaces[uuid]
    }
    
    func setSpaceName(_ name: String, forUUID uuid: String) {
        if config.spaces[uuid] == nil {
            config.spaces[uuid] = AppConfig.SpaceConfig(name: name)
        } else {
            config.spaces[uuid]?.name = name
        }
        debouncedSave()
    }
    
    func setSpaceShortcut(_ shortcut: KeyCombo?, forUUID uuid: String) {
        if config.spaces[uuid] == nil {
            config.spaces[uuid] = AppConfig.SpaceConfig(name: "Desktop", shortcut: shortcut)
        } else {
            config.spaces[uuid]?.shortcut = shortcut
        }
        debouncedSave()
    }
    
    // MARK: - Quick Rename Shortcut
    
    func getQuickRenameShortcut() -> KeyCombo? {
        config.quickRenameShortcut
    }
    
    func setQuickRenameShortcut(_ shortcut: KeyCombo?) {
        config.quickRenameShortcut = shortcut
        debouncedSave()
    }
    
    // MARK: - HUD Settings
    
    func getHUDSettings() -> (enabled: Bool, position: AppConfig.HUDPosition) {
        (config.hudEnabled, config.hudPosition)
    }
    
    func setHUDEnabled(_ enabled: Bool) {
        config.hudEnabled = enabled
        debouncedSave()
    }
    
    func setHUDPosition(_ position: AppConfig.HUDPosition) {
        config.hudPosition = position
        debouncedSave()
    }
    
    // MARK: - Launch at Login
    
    func isLaunchAtLogin() -> Bool {
        config.launchAtLogin
    }
    
    func setLaunchAtLogin(_ enabled: Bool) {
        config.launchAtLogin = enabled
        debouncedSave()
    }
    
    // MARK: - Private Helpers
    
    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(saveDebounceInterval * 1_000_000_000))
            await saveConfig()
        }
    }
    
    private func saveConfig() async -> Void {
        let data = try? JSONEncoder().encode(config)
        if let data = data {
            try? data.write(to: configURL, options: .atomic)
        }
    }
    
    // MARK: - Cleanup
    
    /// Remove Space config after 30 days of inactivity
    func cleanupRemovedSpaces() {
        // TODO: Implement cleanup logic for removed spaces
    }
}
