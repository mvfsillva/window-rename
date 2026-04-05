import Foundation

/// Represents the complete app configuration
struct AppConfig: Codable {
    struct SpaceConfig: Codable {
        var name: String
        var shortcut: KeyCombo?
        var lastSeen: Date?
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

    /// How long to retain config for a removed Space (30 days).
    nonisolated private let retentionInterval: TimeInterval = 30 * 24 * 60 * 60
    
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
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let data = try? Data(contentsOf: configURL),
               let loaded = try? decoder.decode(AppConfig.self, from: data) {
                self.config = loaded
            } else {
                self.config = AppConfig()
            }
        } else {
            self.config = AppConfig()
            // Initial save deferred to first actor-isolated call
        }

        // Migrate: backfill lastSeen = now for any existing configs missing it
        Self.migrateLastSeenDates(config: &self.config, configURL: configURL)
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
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try? encoder.encode(config)
        if let data = data {
            try? data.write(to: configURL, options: .atomic)
        }
    }
    
    // MARK: - Last-Seen Tracking

    /// Update `lastSeen` to now for every Space UUID currently present on the system.
    /// Call this from SpaceManager whenever it refreshes the space list.
    func updateLastSeen(activeUUIDs: Set<String>) {
        let now = Date()
        for uuid in activeUUIDs {
            config.spaces[uuid]?.lastSeen = now
        }
        debouncedSave()
    }

    // MARK: - Cleanup

    /// Remove Space configs whose `lastSeen` is older than the retention interval (30 days).
    /// Safe to call at app launch and on topology changes.
    func cleanupRemovedSpaces(activeUUIDs: Set<String>) {
        let cutoff = Date().addingTimeInterval(-retentionInterval)
        let uuidsToRemove = config.spaces.keys.filter { uuid in
            // Never remove a Space that is currently active on the system
            guard !activeUUIDs.contains(uuid) else { return false }
            guard let lastSeen = config.spaces[uuid]?.lastSeen else {
                // No lastSeen means migration already set it; keep it
                return false
            }
            return lastSeen < cutoff
        }
        for uuid in uuidsToRemove {
            config.spaces.removeValue(forKey: uuid)
        }
        if !uuidsToRemove.isEmpty {
            debouncedSave()
        }
    }

    // MARK: - Migration

    /// Backfill `lastSeen = now` for any existing Space config that was saved
    /// before the lastSeen field was introduced. Static to allow calling from nonisolated init.
    private nonisolated static func migrateLastSeenDates(config: inout AppConfig, configURL: URL) {
        let now = Date()
        var didMigrate = false
        for uuid in config.spaces.keys {
            if config.spaces[uuid]?.lastSeen == nil {
                config.spaces[uuid]?.lastSeen = now
                didMigrate = true
            }
        }
        if didMigrate {
            // Synchronous save during init — config file is small
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(config) {
                try? data.write(to: configURL, options: .atomic)
            }
        }
    }
}
