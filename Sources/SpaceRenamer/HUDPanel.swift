import Foundation
import AppKit
import SwiftUI

/// Observable model for HUD state, enabling animated SwiftUI updates
@Observable
final class HUDState {
    var spaceName: String = "Desktop"
    var position: AppConfig.HUDPosition = .topRight
}

/// Floating HUD panel that displays the current Space name
class HUDPanel: NSPanel {
    private var hostingView: NSHostingView<HUDContentView>?
    private let hudState = HUDState()
    private let padding: CGFloat = 12

    init(spaceManager: SpaceManager, position: AppConfig.HUDPosition) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 44),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .managed]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true

        // Set initial state
        hudState.spaceName = spaceManager.getSpace(spaceManager.activeSpaceId ?? "")?.customName ?? "Desktop"
        hudState.position = position

        // Create the SwiftUI content with observable state
        let content = HUDContentView(state: hudState)
        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        self.hostingView = hosting
        self.contentView = hosting

        // Observe size changes from SwiftUI for dynamic sizing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.resizeToFitContent()
            self?.repositionOnScreen()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateSpaceName(_ name: String) {
        hudState.spaceName = name

        // Resize after the SwiftUI content updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.resizeToFitContent()
            self?.repositionOnScreen()
        }
    }

    func updatePosition(_ position: AppConfig.HUDPosition) {
        hudState.position = position
        repositionOnScreen()
    }

    /// Resize the panel to fit the SwiftUI content's intrinsic size
    private func resizeToFitContent() {
        guard let hosting = hostingView else { return }
        let fittingSize = hosting.fittingSize
        let width = max(fittingSize.width, 60)  // minimum width
        let height = max(fittingSize.height, 36)

        let currentFrame = frame
        setContentSize(NSSize(width: width, height: height))

        // Keep the position stable after resize
        if currentFrame.origin != .zero {
            repositionOnScreen()
        }
    }

    /// Position the panel in the correct corner of the main screen
    private func repositionOnScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = frame.size

        let x: CGFloat
        let y: CGFloat

        switch hudState.position {
        case .topLeft:
            x = screenFrame.minX + padding
            y = screenFrame.maxY - panelSize.height - padding
        case .topRight:
            x = screenFrame.maxX - panelSize.width - padding
            y = screenFrame.maxY - panelSize.height - padding
        case .bottomLeft:
            x = screenFrame.minX + padding
            y = screenFrame.minY + padding
        case .bottomRight:
            x = screenFrame.maxX - panelSize.width - padding
            y = screenFrame.minY + padding
        }

        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// SwiftUI view for the HUD content with crossfade animation
struct HUDContentView: View {
    @Bindable var state: HUDState

    var body: some View {
        ZStack {
            // Background with vibrancy
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .cornerRadius(8)

            // Content with crossfade animation
            Text(state.spaceName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .id(state.spaceName)  // Force view identity change for transition
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: state.spaceName)
        }
        .fixedSize()  // Auto-size to text content
    }
}

/// Wrapper for NSVisualEffectView
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    HUDContentView(state: {
        let s = HUDState()
        s.spaceName = "Project Workspace"
        return s
    }())
}
