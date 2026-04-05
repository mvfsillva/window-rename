import Foundation
import AppKit
import Observation

/// Represents a single macOS Space
@Codable
struct SpaceInfo: Identifiable {
    let id: String  // ManagedSpaceID (UUID)
    let numericId: UInt64  // id64
    let displayUUID: String
    let position: Int  // 1-based index
    
    var customName: String
    var shortcut: KeyCombo?
    var isActive: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, numericId, displayUUID, position, customName, shortcut, isActive
    }
}

/// Keyboard shortcut combination
struct KeyCombo: Codable, Hashable {
    let modifiers: NSEvent.ModifierFlags  // ctrl, alt, shift, cmd
    let keyCode: UInt16
    let characters: String
    
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

/// Manages all macOS Space state and detection
@Observable
final class SpaceManager {
    private let cgsConnection: CGSConnectionID
    private var cachedSpaces: [String: SpaceInfo] = [:]
    private var pollTimer: Timer?
    private let dispatchQueue = DispatchQueue(label: "com.spacerenamer.space-manager", qos: .userInitiated)
    
    @ObservationIgnored
    private var activeSpaceObserver: NSObjectProtocol?
    
    var spaces: [SpaceInfo] = []
    var activeSpaceId: String?
    
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
    }
    
    private func setupNotifications() {
        activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateSpaces()
        }
    }
    
    private func startPolling() {
        dispatchQueue.async { [weak self] in
            self?.pollTimer = Timer.scheduledTimer(
                withTimeInterval: 3.0,
                repeats: true
            ) { [weak self] _ in
                self?.updateSpaces()
            }
        }
    }
    
    private func stopPolling() {
        dispatchQueue.async { [weak self] in
            self?.pollTimer?.invalidate()
            self?.pollTimer = nil
        }
    }
    
    /// Fetch and update all Spaces from the system
    func updateSpaces() {
        dispatchQueue.async { [weak self] in
            guard let self = self else { return }
            
            let spaceArray = self.fetchSpacesFromSystem()
            let activeSpaceId = self.getActiveSpaceId()
            
            DispatchQueue.main.async {
                self.spaces = spaceArray
                self.activeSpaceId = activeSpaceId
            }
        }
    }
    
    /// Fetch spaces using private CGS APIs
    private func fetchSpacesFromSystem() -> [SpaceInfo] {
        guard let displaySpaces = CGSCopyManagedDisplaySpaces(cgsConnection) as? [[String: Any]] else {
            return []
        }
        
        var allSpaces: [SpaceInfo] = []
        
        for displayDict in displaySpaces {
            guard let spaces = displayDict["Spaces"] as? [[String: Any]] else { continue }
            guard let displayUUID = displayDict["Display UUID"] as? String else { continue }
            
            for (index, spaceDict) in spaces.enumerated() {
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
                
                // Restore any previously saved customization
                if let cached = cachedSpaces[uuid] {
                    spaceInfo.customName = cached.customName
                    spaceInfo.shortcut = cached.shortcut
                }
                
                cachedSpaces[uuid] = spaceInfo
                allSpaces.append(spaceInfo)
            }
        }
        
        return allSpaces
    }
    
    /// Get the currently active Space ID
    private func getActiveSpaceId() -> String? {
        let activeSpaceNumericId = CGSGetActiveSpace(cgsConnection)
        return spaces.first { $0.numericId == activeSpaceNumericId }?.id
    }
    
    /// Update a Space's custom name
    func updateSpaceName(_ spaceId: String, newName: String) {
        if let index = spaces.firstIndex(where: { $0.id == spaceId }) {
            spaces[index].customName = newName
            cachedSpaces[spaceId]?.customName = newName
        }
    }
    
    /// Update a Space's shortcut
    func updateSpaceShortcut(_ spaceId: String, shortcut: KeyCombo?) {
        if let index = spaces.firstIndex(where: { $0.id == spaceId }) {
            spaces[index].shortcut = shortcut
            cachedSpaces[spaceId]?.shortcut = shortcut
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
}
