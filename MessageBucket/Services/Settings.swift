import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var showProminentOverlay: Bool {
        didSet { UserDefaults.standard.set(showProminentOverlay, forKey: "showProminentOverlay") }
    }

    @Published var followFocusModes: Bool {
        didSet { UserDefaults.standard.set(followFocusModes, forKey: "followFocusModes") }
    }

    @Published var basePath: String {
        didSet { UserDefaults.standard.set(basePath, forKey: "basePath") }
    }

    var baseURL: URL { URL(fileURLWithPath: (basePath as NSString).expandingTildeInPath) }
    var inboxURL: URL { baseURL.appendingPathComponent("inbox") }
    var queueURL: URL { baseURL.appendingPathComponent("queue") }
    var snoozedURL: URL { baseURL.appendingPathComponent("snoozed") }
    var archiveURL: URL { baseURL.appendingPathComponent("archive") }

    private init() {
        let defaults = UserDefaults.standard
        self.showProminentOverlay = defaults.object(forKey: "showProminentOverlay") as? Bool ?? true
        self.followFocusModes = defaults.object(forKey: "followFocusModes") as? Bool ?? false

        // Migrate from old "inboxPath" key if present
        if let oldInbox = defaults.string(forKey: "inboxPath") {
            let parent = (oldInbox as NSString).deletingLastPathComponent
            self.basePath = parent
            defaults.removeObject(forKey: "inboxPath")
            defaults.set(parent, forKey: "basePath")
        } else {
            self.basePath = defaults.string(forKey: "basePath") ?? "~/Message Bucket"
        }
    }
}
