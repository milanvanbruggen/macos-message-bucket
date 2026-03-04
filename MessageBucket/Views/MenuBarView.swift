import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: MessageStore
    let onSelectMessage: (Message) -> Void
    let onSnoozeMessage: (Message) -> Void
    let onDeleteMessage: (Message) -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    @State private var showingArchive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showingArchive {
                archiveView
            } else {
                mainView
            }
        }
        .frame(width: 280)
        .padding(.vertical, 6)
    }

    // MARK: - Main View

    @ViewBuilder
    private var mainView: some View {
        if store.unread.isEmpty && store.snoozed.isEmpty {
            Text("No messages")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }

        if !store.unread.isEmpty {
            SectionHeader("Unread")
            ForEach(Array(store.unread.enumerated()), id: \.element.id) { index, message in
                MessageRowView(message: message) {
                    onSelectMessage(message)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        onDeleteMessage(message)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                if index < store.unread.count - 1 {
                    Divider().padding(.horizontal, 12)
                }
            }
        }

        if !store.snoozed.isEmpty {
            SectionHeader("Snoozed")
            ForEach(Array(store.snoozed.enumerated()), id: \.element.id) { index, message in
                MessageRowView(message: message) {
                    onSelectMessage(message)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        onDeleteMessage(message)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                if index < store.snoozed.count - 1 {
                    Divider().padding(.horizontal, 12)
                }
            }
        }

        Divider()

        MenuActionRow("Archive", systemImage: "archivebox", badge: store.archived.count) {
            showingArchive = true
        }
        MenuActionRow("Settings", systemImage: "gear", action: onOpenSettings)
        MenuActionRow("Quit Message Bucket", systemImage: "power", action: onQuit)
    }

    // MARK: - Archive View

    @ViewBuilder
    private var archiveView: some View {
        // Back button
        Button(action: { showingArchive = false }) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("Back")
                    .font(.callout)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        Divider().padding(.horizontal, 12)

        if store.archived.isEmpty {
            Text("No archived messages")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        } else {
            SectionHeader("Archive")
            ForEach(Array(store.archived.enumerated()), id: \.element.id) { index, message in
                MessageRowView(message: message) {
                    onSelectMessage(message)
                }
                .contextMenu {
                    Button {
                        onSnoozeMessage(message)
                    } label: {
                        Label("Snooze", systemImage: "moon")
                    }
                    Divider()
                    Button(role: .destructive) {
                        onDeleteMessage(message)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                if index < store.archived.count - 1 {
                    Divider().padding(.horizontal, 12)
                }
            }
            .padding(.bottom, 4)
        }
    }
}

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .tracking(0.8)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }
}

private struct MenuActionRow: View {
    let title: String
    let systemImage: String
    let badge: Int?
    let action: () -> Void

    @State private var isHovered = false

    init(_ title: String, systemImage: String, badge: Int? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.badge = badge
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 16)
                Text(title)
                Spacer()
                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(isHovered ? .white.opacity(0.8) : .secondary)
                }
            }
            .font(.callout)
            .foregroundStyle(isHovered ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.accentColor : Color.clear)
            )
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

