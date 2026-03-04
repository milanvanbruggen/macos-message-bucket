import SwiftUI

struct OverlayView: View {
    let message: Message
    let onRead: () -> Void
    let onSnooze: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false

    var body: some View {
        ZStack {
            // Blur background
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    if let source = message.source {
                        Text(source.uppercased())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .tracking(1.2)
                            .accessibilityLabel("From: \(source)")
                    }

                    Text(message.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                }

                ScrollView {
                    Text(LocalizedStringKey(message.body))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 480)
                }
                .frame(maxHeight: 300)

                HStack(spacing: 12) {
                    Button("Snooze") {
                        onSnooze()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape, modifiers: [])
                    .accessibilityLabel("Snooze message")
                    .accessibilityHint("Dismiss overlay, message stays unread")

                    Button("Read") {
                        onRead()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                    .accessibilityLabel("Mark as read")
                    .accessibilityHint("Mark message as read and archive it")

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Delete message")
                    .accessibilityHint("Permanently delete this message")
                }
            }
            .padding(48)
            .frame(maxWidth: 600)
        }
        .confirmationDialog(
            "Delete \"\(message.title)\"?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This message will be permanently deleted and cannot be recovered.")
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
