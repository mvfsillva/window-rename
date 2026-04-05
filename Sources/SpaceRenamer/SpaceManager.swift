import Foundation
import AppKit
import Observation
import CGSPrivate

/// Represents a single macOS Space
struct SpaceInfo: Identifiable, Codable {
    let id: String  // ManagedSpaceID (UUID)
    let numericId: UInt64  // id64
    let displayUUID: String
    var position: Int  // 1-based index

    var customName: String
    var shortcut: KeyCombo?
    var isActive: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, numericId, displayUUID, position, customName, shortcut, isActive
    }
}

/// Keyboard shortcut combination
struct KeyCombo: Equatable {
    let modifiers: NSEvent.ModifierFlags  // ctrl, alt, shift, cmd
    let keyCode: UInt16
    let characters: String

    static func == (lhs: KeyCombo, rhs: KeyCombo) -> Bool {
        lhs.modifiers.rawValue == rhs.modifiers.rawValue
            && lhs.keyCode == rhs.keyCode
            && lhs.characters == rhs.characters
    }

    func description() -> String {
        var parts: [String] = []

        if modifiers.contains(.control) { parts.append("ctrl") }
        if modifiers.contains(.option) { parts.append("opt") }
        if modifiers.contains(.shift) { parts.append("shift") }
        if modifiers.contains(.command) { parts.append("cmd") }

        parts.append(characters.uppercased())
        return parts.joined(separator: "+")
    }
}

// MARK: - Hashable Conformance
extension KeyCombo: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(modifiers.rawValue)
        hasher.combine(keyCode)
        hasher.combine(characters)
    }
}

// MARK: - Codable Conformance
extension KeyCombo: Codable {
    enum CodingKeys: String, CodingKey {
        case modifiersMask
        case keyCode
        case characters
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modifiers.rawValue, forKey: .modifiersMask)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(characters, forKey: .characters)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let modifiersMask = try container.decode(UInt.self, forKey: .modifiersMask)
        let keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        let characters = try container.decode(String.self, forKey: .characters)

        self.modifiers = NSEvent.ModifierFlags(rawValue: modifiersMask)
        self.keyCode = keyCode
        self.characters = characters
    }
}

/// Manages all macOS Space state and detection
@Observable
final class SpaceManager {
    private let cgsConnection: CGSConnectionID
    private var cachedSpaces: [String: SpaceInfo] = [:]
    private var pollTimer: Timer?
    private let dispatchQueue = DispatchQueue(label: "com.spacerenamer.space-manager", qos: .userInitiated)

    /// Callback invoked on the main thread whenever the active Space changes.
    /// Passes the new active SpaceInfo (or nil if unknown).
    @ObservationIgnored
    var onActiveSpaceChanged: ((SpaceInfo?) -> Void)?

    /// Callback invoked when a space name or shortcut changes, for persistence.
    @ObservationIgnored
    var onSpaceUpdated: ((SpaceInfo) -> Void)?

    /// Callback invoked after every space list refresh with the set of currently active UUIDs.
    /// Used by PersistenceStore to update lastSeen timestamps and run cleanup.
    @ObservationIgnored
    var onSpacesRefreshed: ((Set<String>) -> Void)?

    @ObservationIgnored
    private var activeSpaceObserver: NSObjectProtocol?

    @ObservationIgnored
    private var wakeObserver: NSObjectProtocol?

    var spaces: [SpaceInfo] = []
    var activeSpaceId: String?

    /// Saved space configs loaded from persistence (uuid -> SpaceConfig)
    @ObservationIgnored
    private var savedConfigs: [String: AppConfig.SpaceConfig] = [:]

    init() {
        self.cgsConnection = CGSMainConnectionID()
        setupNotifications()
        updateSpaces()
        startPolling()
    }

    deinit {
        stopPolling()
        if let observer = activeSpaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    /// Load saved space configs from PersistenceStore and apply them.
    /// Call this once after init and after PersistenceStore is available.
    func loadSavedConfigs(_ configs: [String: AppConfig.SpaceConfig]) {
        savedConfigs = configs

        // Apply saved names/shortcuts to already-discovered spaces
        for (uuid, config) in configs {
            if let index = spaces.firstIndex(where: { $0.id == uuid }) {
                spaces[index].customName = config.name
                spaces[index].shortcut = config.shortcut
                cachedSpaces[uuid]?.customName = config.name
                cachedSpaces[uuid]?.shortcut = config.shortcut
            }
        }
    }

    private func setupNotifications() {
        activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateSpaces()
        }

        // Re-read spaces on wake from sleep
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateSpaces()
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: 3.0,
            repeats: true
        ) { [weak self] _ in
            self?.updateSpaces()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Fetch and update all Spaces from the system
    func updateSpaces() {
        let spaceArray = fetchSpacesFromSystem()
        let activeId = detectActiveSpaceId(in: spaceArray)
        let previousActiveId = activeSpaceId

        spaces = spaceArray
        activeSpaceId = activeId

        // Mark active space
        if let activeId = activeId {
            if let index = spaces.firstIndex(where: { $0.id == activeId }) {
                spaces[index].isActive = true
            }
        }

        // Notify if active space changed
        if activeId != previousActiveId {
            let activeSpace = activeId.flatMap { id in spaces.first { $0.id == id } }
            onActiveSpaceChanged?(activeSpace)
        }

        // Report all currently active Space UUIDs for lastSeen tracking
        let activeUUIDs = Set(spaceArray.map(\.id))
        onSpacesRefreshed?(activeUUIDs)
    }

    /// Fetch spaces using private CGS APIs
    private func fetchSpacesFromSystem() -> [SpaceInfo] {
        guard let unmanagedSpaces = CGSCopyManagedDisplaySpaces(cgsConnection) else {
            return []
        }
        let cfArray = unmanagedSpaces.takeRetainedValue()
        guard let displaySpaces = cfArray as? [[String: Any]] else {
            return []
        }

        var allSpaces: [SpaceInfo] = []

        for displayDict in displaySpaces {
            guard let spacesList = displayDict["Spaces"] as? [[String: Any]] else { continue }
            guard let displayUUID = displayDict["Display UUID"] as? String else { continue }

            for (index, spaceDict) in spacesList.enumerated() {
                guard let uuid = spaceDict["ManagedSpaceID"] as? String else { continue }
                guard let numericId = spaceDict["id64"] as? NSNumber else { continue }

                let defaultName = "Desktop \(index + 1)"

                var spaceInfo = SpaceInfo(
                    id: uuid,
                    numericId: numericId.uint64Value,
                    displayUUID: displayUUID,
                    position: index + 1,
                    customName: defaultName,
                    shortcut: nil
                )

                // Restore from saved config (persistence) first, then in-memory cache
                if let saved = savedConfigs[uuid] {
                    spaceInfo.customName = saved.name
                    spaceInfo.shortcut = saved.shortcut
                } else if let cached = cachedSpaces[uuid] {
                    spaceInfo.customName = cached.customName
                    spaceInfo.shortcut = cached.shortcut
                }

                cachedSpaces[uuid] = spaceInfo
                allSpaces.append(spaceInfo)
            }
        }

        return allSpaces
    }

    /// Detect the currently active Space ID from a list of spaces
    private func detectActiveSpaceId(in spaceList: [SpaceInfo]) -> String? {
        let activeSpaceNumericId = CGSGetActiveSpace(cgsConnection)
        return spaceList.first { $0.numericId == activeSpaceNumericId }?.id
    }

    /// Update a Space's custom name
    func updateSpaceName(_ spaceId: String, newName: String) {
        if let index = spaces.firstIndex(where: { $0.id == spaceId }) {
            spaces[index].customName = newName
            cachedSpaces[spaceId]?.customName = newName

            // Update saved config
            if savedConfigs[spaceId] != nil {
                savedConfigs[spaceId]?.name = newName
            } else {
                savedConfigs[spaceId] = AppConfig.SpaceConfig(name: newName)
            }

            onSpaceUpdated?(spaces[index])
        }
    }

    /// Update a Space's shortcut
    func updateSpaceShortcut(_ spaceId: String, shortcut: KeyCombo?) {
        if let index = spaces.firstIndex(where: { $0.id == spaceId }) {
            spaces[index].shortcut = shortcut
            cachedSpaces[spaceId]?.shortcut = shortcut

            // Update saved config
            if savedConfigs[spaceId] != nil {
                savedConfigs[spaceId]?.shortcut = shortcut
            } else {
                savedConfigs[spaceId] = AppConfig.SpaceConfig(
                    name: spaces[index].customName,
                    shortcut: shortcut
                )
            }

            onSpaceUpdated?(spaces[index])
        }
    }

    /// Get Space by ID
    func getSpace(_ id: String) -> SpaceInfo? {
        spaces.first { $0.id == id }
    }

    /// Get Space by position on a display
    func getSpace(position: Int, displayUUID: String) -> SpaceInfo? {
        spaces.first { $0.position == position && $0.displayUUID == displayUUID }
    }

    /// Get all unique display UUIDs
    var displayUUIDs: [String] {
        Array(Set(spaces.map(\.displayUUID)))
    }

    /// Get spaces for a specific display
    func spaces(forDisplay displayUUID: String) -> [SpaceInfo] {
        spaces.filter { $0.displayUUID == displayUUID }.sorted { $0.position < $1.position }
    }
}
