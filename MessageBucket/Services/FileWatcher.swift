import Foundation

@MainActor
final class FileWatcher {
    private let inboxURL: URL
    private let queueURL: URL
    private let snoozedURL: URL
    private let archiveURL: URL
    private var pollTimer: Timer?

    /// Tracks filenames already handed off, to avoid re-processing on every poll tick.
    private var seenFiles: Set<String> = []

    /// Called for each new JSON file found in the inbox.
    var onNewFile: ((URL) -> Void)?

    /// Called for each existing JSON file found in the queue folder on startup.
    var onQueuedFile: ((URL) -> Void)?

    /// Called for each existing JSON file found in the snoozed folder on startup.
    var onSnoozedFile: ((URL) -> Void)?

    /// Called for each existing JSON file found in the archive folder on startup.
    var onArchivedFile: ((URL) -> Void)?

    init(inboxURL: URL, queueURL: URL, snoozedURL: URL, archiveURL: URL) {
        self.inboxURL = inboxURL
        self.queueURL = queueURL
        self.snoozedURL = snoozedURL
        self.archiveURL = archiveURL
    }

    func start() {
        createDirectoriesIfNeeded()
        restoreState()
        scanInbox()
        startPollTimer()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - File Movement

    /// Move a file from inbox to the queue folder.
    func moveToQueue(_ fileURL: URL) -> URL {
        let destination = queueURL.appendingPathComponent(fileURL.lastPathComponent)
        try? FileManager.default.moveItem(at: fileURL, to: destination)
        return destination
    }

    /// Move a file to the snoozed folder.
    func moveToSnoozed(_ fileURL: URL) -> URL {
        let destination = snoozedURL.appendingPathComponent(fileURL.lastPathComponent)
        try? FileManager.default.moveItem(at: fileURL, to: destination)
        return destination
    }

    /// Move a file to the archive folder.
    func moveToArchive(_ fileURL: URL) {
        let destination = archiveURL.appendingPathComponent(fileURL.lastPathComponent)
        try? FileManager.default.moveItem(at: fileURL, to: destination)
    }

    // MARK: - Private

    private func createDirectoriesIfNeeded() {
        for url in [inboxURL, queueURL, snoozedURL, archiveURL] {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// On startup, restore queued, snoozed, and archived messages from their folders.
    private func restoreState() {
        for url in jsonFiles(in: queueURL) {
            onQueuedFile?(url)
        }
        for url in jsonFiles(in: snoozedURL) {
            seenFiles.insert(url.lastPathComponent)
            onSnoozedFile?(url)
        }
        for url in jsonFiles(in: archiveURL) {
            onArchivedFile?(url)
        }
    }

    private func startPollTimer() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scanInbox()
            }
        }
    }

    private func scanInbox() {
        for url in jsonFiles(in: inboxURL) {
            let filename = url.lastPathComponent
            guard !seenFiles.contains(filename) else { continue }
            seenFiles.insert(filename)
            onNewFile?(url)
        }
    }

    private func jsonFiles(in directory: URL) -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return [] }
        return contents.filter { $0.pathExtension == "json" }
    }
}
