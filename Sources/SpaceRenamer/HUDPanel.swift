import Foundation
import AppKit
import SwiftUI

/// Floating HUD panel that displays the current Space name
class HUDPanel: NSPanel {
    private var hostingView: NSHostingView<HUDContentView>?
    private let screenRect: NSRect

    init(spaceManager: SpaceManager, position: AppConfig.HUDPosition) {
        self.screenRect = NSScreen.main?.frame ?? .zero

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 50),
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

        // Create the SwiftUI content
        let spaceName = spaceManager.getSpace(spaceManager.activeSpaceId ?? "")?.customName ?? "Desktop"
        let content = HUDContentView(spaceName: spaceName)
        let hosting = NSHostingView(rootView: content)
        self.hostingView = hosting

        self.contentView = hosting

        updatePosition(position)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updatePosition(_ position: AppConfig.HUDPosition) {
        let padding: CGFloat = 12
        let width: CGFloat = 180
        let height: CGFloat = 50

        let x: CGFloat
        let y: CGFloat

        switch position {
        case .topLeft:
            x = padding
            y = screenRect.height - height - padding
        case .topRight:
            x = screenRect.width - width - padding
            y = screenRect.height - height - padding
        case .bottomLeft:
            x = padding
            y = padding
        case .bottomRight:
            x = screenRect.width - width - padding
            y = padding
        }

        setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    func updateSpaceName(_ name: String) {
        if let hosting = hostingView {
            let newContent = HUDContentView(spaceName: name)
            hosting.rootView = newContent
        }
    }
}

/// SwiftUI view for the HUD content
struct HUDContentView: View {
    let spaceName: String
    @State private var showContent = true

    var body: some View {
        ZStack {
            // Background with vibrancy
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .cornerRadius(8)

            // Content
            Text(spaceName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
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
    HUDContentView(spaceName: "Project Workspace")
}
