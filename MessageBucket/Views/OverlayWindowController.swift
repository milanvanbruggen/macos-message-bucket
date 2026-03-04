import AppKit
import SwiftUI

final class OverlayWindowController: NSWindowController {
    private let message: Message
    private let onRead: () -> Void
    private let onSnooze: () -> Void
    private let onDelete: () -> Void

    init(message: Message,
         onRead: @escaping () -> Void,
         onSnooze: @escaping () -> Void,
         onDelete: @escaping () -> Void) {
        self.message = message
        self.onRead = onRead
        self.onSnooze = onSnooze
        self.onDelete = onDelete

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let window = NSWindow(
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
    }

    private func dismiss() {
        window?.orderOut(nil)
    }
}
