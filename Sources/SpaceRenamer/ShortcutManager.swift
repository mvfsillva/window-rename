import Foundation
import AppKit
import Carbon

/// Manages global keyboard shortcuts via CGEvent tap
final class ShortcutManager: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var shortcuts: [String: (KeyCombo, () -> Void)] = [:]
    private(set) var isAccessibilityEnabled: Bool = false

    private let shortcutQueue = DispatchQueue(label: "com.spacerenamer.shortcuts", qos: .userInitiated)

    init() {
        checkAccessibilityPermission()
    }

    deinit {
        stopListening()
    }

    // MARK: - Setup

    private func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            promptAccessibilityPermission()
        } else {
            setupEventTap()
        }
    }

    private func promptAccessibilityPermission() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "SpaceRenamer needs Accessibility permission to use global keyboard shortcuts for switching between named Spaces and quick renaming.\n\nPlease enable it in System Settings > Privacy & Security > Accessibility."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")

            let response = alert.runModal()
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }

        // Poll for permission grant
        pollForAccessibilityPermission()
    }

    private func pollForAccessibilityPermission() {
        shortcutQueue.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if AXIsProcessTrusted() {
                DispatchQueue.main.async {
                    self.setupEventTap()
                }
            } else {
                self.pollForAccessibilityPermission()
            }
        }
    }

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                       (1 << CGEventType.keyUp.rawValue) |
                       (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let manager = Unmanaged<ShortcutManager>.fromOpaque(refcon!).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        self.eventTap = tap
        self.runLoopSource = source
        self.isAccessibilityEnabled = true
    }

    private func stopListening() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
        isAccessibilityEnabled = false
    }

    // MARK: - Event Handling

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))

        // Strip device-independent modifier flags for matching
        let relevantFlags = flags.intersection([.control, .option, .shift, .command])

        for (_, (combo, action)) in shortcuts {
            let comboFlags = combo.modifiers.intersection([.control, .option, .shift, .command])
            if keyCode == combo.keyCode && relevantFlags == comboFlags {
                DispatchQueue.main.async {
                    action()
                }
                // Consume the event
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - Shortcut Registration

    func registerShortcut(_ combo: KeyCombo, id: String, action: @escaping () -> Void) {
        shortcuts[id] = (combo, action)
    }

    func unregisterShortcut(id: String) {
        shortcuts.removeValue(forKey: id)
    }

    func isShortcutAvailable(_ combo: KeyCombo) -> Bool {
        return !shortcuts.values.contains { $0.0 == combo }
    }

    // MARK: - Switch to Space

    func switchToSpace(position: Int) {
        guard let keyCode = keyCodeForNumber(position) else { return }

        let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        event?.flags = .maskControl
        event?.post(tap: .cghidEventTap)

        let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        upEvent?.flags = .maskControl
        upEvent?.post(tap: .cghidEventTap)
    }

    private func keyCodeForNumber(_ number: Int) -> CGKeyCode? {
        let keyCodes: [Int: CGKeyCode] = [
            1: 18,   // 1
            2: 19,   // 2
            3: 20,   // 3
            4: 21,   // 4
            5: 23,   // 5
            6: 22,   // 6
            7: 26,   // 7
            8: 28,   // 8
            9: 25    // 9
        ]
        return keyCodes[number]
    }

    // MARK: - Conflict Detection

    func detectConflict(for combo: KeyCombo) -> String? {
        for (id, (existingCombo, _)) in shortcuts {
            if existingCombo == combo {
                return id
            }
        }
        return nil
    }
}

// MARK: - Extensions for KeyCombo from NSEvent

extension KeyCombo {
    init?(from event: NSEvent) {
        guard event.type == .keyDown else { return nil }

        self.modifiers = event.modifierFlags
        self.keyCode = UInt16(event.keyCode)
        self.characters = event.charactersIgnoringModifiers ?? ""
    }
}
