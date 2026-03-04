import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var overlayController: OverlayWindowController?

    private let store = MessageStore()
    private let settings = AppSettings.shared
    private var fileWatcher: FileWatcher!
    private var scheduler: NotificationScheduler!
    private var processedIDs: Set<String> = []
    private var messageFileURLs: [String: URL] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        setupScheduler()
        setupFileWatcher()
        fileWatcher.start()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusItemButton()

        store.$unread
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusItemButton() }
            .store(in: &cancellables)

        store.$snoozed
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusItemButton() }
            .store(in: &cancellables)

        // Re-render when the user switches between light and dark mode
        NSApp.publisher(for: \.effectiveAppearance)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusItemButton() }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateStatusItemButton() {
        guard let button = statusItem.button else { return }
        let count = store.badgeCount

        // Pure template icon — larger size to match other menu bar icons
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let icon = NSImage(systemSymbolName: "tray", accessibilityDescription: nil)!
            .withSymbolConfiguration(config)!
        icon.isTemplate = true
        button.image = icon
        button.title = ""
        button.imagePosition = .imageOnly
        button.action = #selector(togglePopover)
        button.target = self
        button.setAccessibilityLabel(count > 0
            ? "Message Bucket \u{2014} \(count) unread"
            : "Message Bucket")

        // Allow badge to draw outside the button bounds
        button.wantsLayer = true
        button.layer?.masksToBounds = false

        // Remove any existing badge overlay
        button.subviews.filter { $0 is BadgeView }.forEach { $0.removeFromSuperview() }

        guard count > 0 else { return }

        let badgeView = BadgeView(count: count)
        button.addSubview(badgeView)
        // BadgeView positions itself in its own layout() once the button is laid out
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let view = MenuBarView(
            store: store,
            onSelectMessage: { [weak self] message in
                self?.popover.performClose(nil)
                self?.showOverlay(for: message)
            },
            onSnoozeMessage: { [weak self] message in
                guard let self else { return }
                self.store.snooze(message)
                let knownURL = self.messageFileURLs.removeValue(forKey: message.id)
                let sourceURL = knownURL ?? self.settings.archiveURL
                    .appendingPathComponent(message.id).appendingPathExtension("json")
                let newURL = self.fileWatcher.moveToSnoozed(sourceURL)
                self.messageFileURLs[message.id] = newURL
            },
            onDeleteMessage: { [weak self] message in
                guard let self else { return }
                self.store.delete(message)
                if let fileURL = self.messageFileURLs.removeValue(forKey: message.id) {
                    self.fileWatcher.deleteFile(fileURL)
                } else {
                    let archiveURL = self.settings.archiveURL
                        .appendingPathComponent(message.id).appendingPathExtension("json")
                    self.fileWatcher.deleteFile(archiveURL)
                }
            },
            onOpenSettings: { [weak self] in
                self?.popover.performClose(nil)
                self?.openSettings()
            },
            onQuit: { NSApp.terminate(nil) }
        )
        popover.contentViewController = NSHostingController(rootView: view)
    }

    // MARK: - Overlay

    private func showOverlay(for message: Message) {
        guard settings.showProminentOverlay else { return }

        // If another overlay is visible, close it silently (no status change).
        overlayController?.dismiss()
        overlayController = nil

        overlayController = OverlayWindowController(
            message: message,
            onRead: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.store.markAsRead(message)
                    if let fileURL = self.messageFileURLs.removeValue(forKey: message.id) {
                        self.fileWatcher.moveToArchive(fileURL)
                    }
                }
            },
            onSnooze: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.store.snooze(message)
                    // File may already be tracked (unread path) or may live in archiveURL (archived path)
                    let knownURL = self.messageFileURLs.removeValue(forKey: message.id)
                    let sourceURL = knownURL ?? self.settings.archiveURL
                        .appendingPathComponent(message.id).appendingPathExtension("json")
                    let newURL = self.fileWatcher.moveToSnoozed(sourceURL)
                    self.messageFileURLs[message.id] = newURL
                }
            },
            onDelete: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.store.delete(message)
                    if let fileURL = self.messageFileURLs.removeValue(forKey: message.id) {
                        self.fileWatcher.deleteFile(fileURL)
                    } else {
                        // Try archive folder (messages restored from disk have no tracked URL)
                        let archiveURL = self.settings.archiveURL
                            .appendingPathComponent(message.id).appendingPathExtension("json")
                        self.fileWatcher.deleteFile(archiveURL)
                    }
                }
            }
        )
        overlayController?.present()
    }

    // MARK: - Settings

    private var settingsWindow: NSWindow?

    private func openSettings() {
        if let w = settingsWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(settings: AppSettings.shared)
        let hosting = NSHostingController(rootView: view)

        // Force a layout pass so fittingSize is correct
        hosting.view.layoutSubtreeIfNeeded()
        let contentSize = NSSize(
            width:  max(hosting.view.fittingSize.width,  440),
            height: max(hosting.view.fittingSize.height, 260)
        )

        let window = NSWindow(contentViewController: hosting)
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(contentSize)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    // MARK: - File Watcher & Scheduler

    private func setupFileWatcher() {
        fileWatcher = FileWatcher(
            inboxURL: settings.inboxURL,
            queueURL: settings.queueURL,
            snoozedURL: settings.snoozedURL,
            archiveURL: settings.archiveURL
        )

        // New file dropped in inbox
        fileWatcher.onNewFile = { [weak self] url in
            self?.handleNewFile(at: url)
        }

        // Existing queued file found on startup — reschedule
        fileWatcher.onQueuedFile = { [weak self] url in
            self?.handleQueuedFile(at: url)
        }

        // Existing snoozed file found on startup — restore to snoozed list
        fileWatcher.onSnoozedFile = { [weak self] url in
            self?.handleSnoozedFile(at: url)
        }

        // Existing archived file found on startup — restore to archive list
        fileWatcher.onArchivedFile = { [weak self] url in
            self?.handleArchivedFile(at: url)
        }
    }

    private func setupScheduler() {
        scheduler = NotificationScheduler()
        scheduler.onDeliver = { [weak self] message in
            self?.deliver(message)
        }
    }

    // MARK: - Message Handling

    /// A new file was found in the inbox. Move to queue and schedule, or deliver immediately.
    private func handleNewFile(at url: URL) {
        guard let message = loadMessage(from: url) else { return }

        let delay = message.scheduledAt.timeIntervalSinceNow
        if delay > 0 {
            // Future message: move to queue and schedule
            let queuedURL = fileWatcher.moveToQueue(url)
            messageFileURLs[message.id] = queuedURL
            scheduler.schedule(message)
        } else {
            // Past message: deliver immediately
            messageFileURLs[message.id] = url
            deliver(message)
        }
    }

    /// A queued file found on startup. Reschedule it.
    private func handleQueuedFile(at url: URL) {
        guard let message = loadMessage(from: url) else { return }
        messageFileURLs[message.id] = url

        let delay = message.scheduledAt.timeIntervalSinceNow
        if delay > 0 {
            scheduler.schedule(message)
        } else {
            deliver(message)
        }
    }

    /// A snoozed file found on startup. Restore to snoozed list.
    private func handleSnoozedFile(at url: URL) {
        guard let message = loadMessage(from: url) else { return }
        messageFileURLs[message.id] = url
        store.addSnoozed(message)
    }

    /// An archived file found on startup. Restore to archive list.
    private func handleArchivedFile(at url: URL) {
        guard let message = loadMessage(from: url) else { return }
        messageFileURLs[message.id] = url
        store.addArchived(message)
    }

    /// Decode a message from a JSON file. Returns nil if already processed or invalid.
    private func loadMessage(from url: URL) -> Message? {
        guard let data = try? Data(contentsOf: url),
              let message = try? JSONDecoder().decode(Message.self, from: data),
              !processedIDs.contains(message.id) else { return nil }
        processedIDs.insert(message.id)
        return message
    }

    private func deliver(_ message: Message) {
        store.add(message)
        showOverlay(for: message)
    }
}

import Combine

// MARK: - BadgeView

/// Red circle badge overlaid on the status bar button.
/// Self-positions in layout() so it always reads the correct post-layout bounds,
/// avoiding the zero-bounds problem that occurs if placed during app startup.
private final class BadgeView: NSView {
    private let count: Int
    private let size: CGFloat = 15

    init(count: Int) {
        self.count = count
        super.init(frame: CGRect(x: 0, y: 0, width: 15, height: 15))
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        guard let sv = superview, sv.bounds.width > 0 else { return }
        let sb = sv.bounds
        // top-right corner, partially outside the button on the right
        let x = sb.maxX - size - 1   // slightly inside right edge
        let y = sv.isFlipped
            ? sb.minY + 2              // flipped: a little below the top
            : sb.maxY - size - 1       // non-flipped: a little below the top edge
        frame = CGRect(x: x, y: y, width: size, height: size)
    }

    override func draw(_ dirtyRect: NSRect) {
        let label = count < 100 ? "\(count)" : "99+"
        let font  = NSFont.systemFont(ofSize: 9, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]

        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: bounds).fill()

        let textSize   = label.size(withAttributes: attrs)
        let textOrigin = CGPoint(
            x: bounds.midX - textSize.width  / 2,
            y: bounds.midY - textSize.height / 2
        )
        label.draw(at: textOrigin, withAttributes: attrs)
    }
}
