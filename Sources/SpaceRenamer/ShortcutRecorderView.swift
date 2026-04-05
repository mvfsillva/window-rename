import SwiftUI
import AppKit

/// Modal view for recording keyboard shortcuts
struct ShortcutRecorderView: View {
    @Environment(\.dismiss) var dismiss
    
    let spaceId: String
    let currentShortcut: KeyCombo?
    let onSave: (KeyCombo?) -> Void
    
    @State private var recordedCombo: KeyCombo?
    @State private var isRecording = false
    @State private var displayText = ""
    @State private var eventMonitor: Any?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Record Keyboard Shortcut")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                if isRecording {
                    VStack(spacing: 12) {
                        Text("Press any key combination...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "radio.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.red)
                            
                            Text("Recording")
                                .font(.system(size: 13, weight: .semibold))
                            
                            Spacer()
                        }
                        .padding(8)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(4)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Shortcut:")
                            .font(.system(size: 12, weight: .semibold))
                        
                        if let combo = recordedCombo ?? currentShortcut {
                            HStack {
                                Text(combo.description())
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.controlBackgroundColor))
                                    .cornerRadius(4)
                                
                                Spacer()
                                
                                Button(action: { recordedCombo = nil; displayText = "" }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        } else {
                            Text("No shortcut assigned")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(6)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: { save() }) {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isRecording && recordedCombo == nil)
            }
        }
        .padding(16)
        .frame(width: 320, height: 280)
        .onAppear { startRecording() }
        .onDisappear { stopRecording() }
    }
    
    private func startRecording() {
        isRecording = true
        recordedCombo = nil
        
        // Monitor keyboard events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if self.isRecording {
                if let combo = KeyCombo(from: event) {
                    self.recordedCombo = combo
                    self.isRecording = false
                }
            }
            return event
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func save() {
        onSave(recordedCombo ?? currentShortcut)
        dismiss()
    }
}

#Preview {
    ShortcutRecorderView(
        spaceId: "test",
        currentShortcut: KeyCombo(modifiers: .control, keyCode: 18, characters: "1"),
        onSave: { _ in }
    )
}
