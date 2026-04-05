import Foundation
import ServiceManagement

/// Manages Launch at Login using SMAppService (macOS 13+)
final class LoginItemManager {
    static let shared = LoginItemManager()

    private let service = SMAppService.mainApp

    private init() {}

    /// Whether the app is currently registered as a login item
    var isEnabled: Bool {
        service.status == .enabled
    }

    /// Register or unregister the app as a login item
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            // Log but don't crash — user can retry from the toggle
            print("LoginItemManager: Failed to \(enabled ? "register" : "unregister") login item: \(error)")
        }
    }
}
