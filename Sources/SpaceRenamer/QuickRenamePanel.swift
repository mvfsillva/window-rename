import Foundation
import AppKit
import SwiftUI

/// Spotlight-style floating panel for quick renaming the current Space
class QuickRenamePanel: NSPanel {
    private var hostingView: NSHostingView<QuickRenameContentView>?
    private var onRename: ((String) -> Void)?
    private var onDismiss: (() -> Void)?

    init() {
        let width: CGFloat = 400
        let height: CGFloat = 60

        // Center on main screen
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let x = screenFrame.midX - width / 2
        let y = screenFrame.midY + 100  // Slightly above center, like Spotlight

        super.init(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .transient]

        // Close on focus loss
        self.hidesOnDeactivate = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Show the rename panel with the current space name pre-filled
    func show(currentName: String, onRename: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        self.onRename = onRename
        self.onDismiss = onDismiss

        let content = QuickRenameContentView(
            initialName: currentName,
            onSubmit: { [weak self] newName in
                self?.onRename?(newName)
                self?.dismiss()
            },
            onCancel: { [weak self] in
                self?.dismiss()
            }
        )

        let hosting = NSHostingView(rootView: content)
        self.hostingView = hosting
        self.contentView = hosting

        // Re-center in case screen changed
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - frame.width / 2
            let y = screen.visibleFrame.midY + 100
            setFrameOrigin(NSPoint(x: x, y: y))
        }

        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        orderOut(nil)
        onDismiss?()
        onDismiss = nil
        onRename = nil
    }

    override func cancelOperation(_ sender: Any?) {
        dismiss()
    }
}

/// SwiftUI content for the quick rename panel
struct QuickRenameContentView: View {
    let initialName: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .cornerRadius(12)

            HStack(spacing: 12) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)

                TextField("Space name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .medium))
                    .focused($isFocused)
                    .onSubmit {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            onSubmit(trimmed)
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(height: 60)
        .onAppear {
            name = initialName
            // Delay focus to ensure the view is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
                // Select all text
                if let window = NSApp.keyWindow,
                   let fieldEditor = window.fieldEditor(false, for: nil) {
                    fieldEditor.selectAll(nil)
                }
            }
        }
        .onExitCommand {
            onCancel()
        }
    }
}
