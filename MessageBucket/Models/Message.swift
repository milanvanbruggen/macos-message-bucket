import Foundation

struct Message: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let scheduledAt: Date
    let source: String?

    var isRead: Bool = false
    var receivedAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case id, title, body, source
        case scheduledAt = "scheduled_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        source = try container.decodeIfPresent(String.self, forKey: .source)

        let dateString = try container.decode(String.self, forKey: .scheduledAt)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            scheduledAt = date
        } else {
            formatter.formatOptions = [.withInternetDateTime]
            scheduledAt = formatter.date(from: dateString) ?? Date()
        }

        isRead = false
        receivedAt = Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encodeIfPresent(source, forKey: .source)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        try container.encode(formatter.string(from: scheduledAt), forKey: .scheduledAt)
    }
}
