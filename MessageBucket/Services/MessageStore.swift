import Foundation
import Combine

@MainActor
final class MessageStore: ObservableObject {
    @Published private(set) var unread: [Message] = []
    @Published private(set) var snoozed: [Message] = []
    @Published private(set) var archived: [Message] = []

    var badgeCount: Int { unread.count + snoozed.count }

    func add(_ message: Message) {
        guard !unread.contains(where: { $0.id == message.id }),
              !snoozed.contains(where: { $0.id == message.id }),
              !archived.contains(where: { $0.id == message.id }) else { return }
        unread.append(message)
    }

    func addSnoozed(_ message: Message) {
        guard !snoozed.contains(where: { $0.id == message.id }),
              !unread.contains(where: { $0.id == message.id }),
              !archived.contains(where: { $0.id == message.id }) else { return }
        snoozed.append(message)
    }

    func addArchived(_ message: Message) {
        guard !archived.contains(where: { $0.id == message.id }) else { return }
        var updated = message
        updated.isRead = true
        archived.append(updated)
    }

    func markAsRead(_ message: Message) {
        if let index = unread.firstIndex(where: { $0.id == message.id }) {
            unread.remove(at: index)
        } else if let index = snoozed.firstIndex(where: { $0.id == message.id }) {
            snoozed.remove(at: index)
        }
        guard !archived.contains(where: { $0.id == message.id }) else { return }
        var updated = message
        updated.isRead = true
        archived.insert(updated, at: 0)
    }

    func snooze(_ message: Message) {
        if let index = unread.firstIndex(where: { $0.id == message.id }) {
            unread.remove(at: index)
        } else if let index = archived.firstIndex(where: { $0.id == message.id }) {
            archived.remove(at: index)
        } else {
            // already snoozed — no-op
            return
        }
        snoozed.insert(message, at: 0)
    }

    func delete(_ message: Message) {
        unread.removeAll   { $0.id == message.id }
        snoozed.removeAll  { $0.id == message.id }
        archived.removeAll { $0.id == message.id }
    }
}
