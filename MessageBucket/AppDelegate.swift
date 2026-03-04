import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
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
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateStatusItemButton() {
        guard let button = statusItem.button else { return }
        let count = store.badgeCount
        button.image = NSImage(systemSymbolName: "tray", accessibilityDescription: "Message Bucket")
        button.title = count > 0 ? " \(count)" : ""
        button.imagePosition = .imageLeft
        button.action = #selector(togglePopover)
        button.target = self
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
                    if let fileURL = self.messageFileURLs.removeValue(forKey: message.id) {
                        let newURL = self.fileWatcher.moveToSnoozed(fileURL)
                        self.messageFileURLs[message.id] = newURL
                    }
                }
            }
        )
        overlayController?.present()
    }

    // MARK: - Settings

    private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Message Bucket Settings"
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView(settings: settings))
        window.isReleasedWhenClosed = false
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
