import Foundation

/// Schedules messages to be delivered at their `scheduledAt` time.
@MainActor
final class NotificationScheduler {
    private var timers: [String: Timer] = [:]

    var onDeliver: ((Message) -> Void)?

    func schedule(_ message: Message) {
        cancel(message.id)

        let delay = message.scheduledAt.timeIntervalSinceNow
        if delay <= 0 {
            onDeliver?(message)
            return
        }

        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.timers.removeValue(forKey: message.id)
                self?.onDeliver?(message)
            }
        }
        timers[message.id] = timer
    }

    func cancel(_ id: String) {
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
    }
}
