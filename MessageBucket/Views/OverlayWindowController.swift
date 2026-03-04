import AppKit
import SwiftUI

// Borderless NSWindows refuse key events by default; override to enable keyboard shortcuts.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class OverlayWindowController: NSWindowController {
    private let message: Message
    private let onRead: () -> Void
    private let onSnooze: () -> Void
    private let onDelete: () -> Void

    private var eventMonitor: Any?

    init(message: Message,
         onRead: @escaping () -> Void,
         onSnooze: @escaping () -> Void,
         onDelete: @escaping () -> Void) {
        self.message = message
        self.onRead = onRead
        self.onSnooze = onSnooze
        self.onDelete = onDelete

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let window = OverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.level = .modalPanel
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false

        super.init(window: window)

        let view = OverlayView(
            message: message,
            onRead: { [weak self] in self?.dismiss(); onRead() },
            onSnooze: { [weak self] in self?.dismiss(); onSnooze() },
            onDelete: { [weak self] in self?.dismiss(); onDelete() }
        )
        window.contentView = NSHostingView(rootView: view)
    }

    required init?(coder: NSCoder) { fatalError() }

    func present() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Local monitor handles ESC and Return reliably regardless of SwiftUI focus.
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 53: // ESC → snooze
                self.dismiss()
                self.onSnooze()
                return nil
            case 36: // Return → mark as read
                self.dismiss()
                self.onRead()
                return nil
            default:
                return event
            }
        }
    }

    func dismiss() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        window?.orderOut(nil)
    }
}
