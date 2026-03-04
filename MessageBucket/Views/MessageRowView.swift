import SwiftUI

struct MessageRowView: View {
    let message: Message
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(message.title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundStyle(isHovered ? .white : .primary)

                    Text(message.scheduledAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(isHovered ? .white.opacity(0.8) : .secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.accentColor : Color.clear)
            )
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(message.title), \(message.scheduledAt, format: .relative(presentation: .named))")
        .accessibilityHint("Open message")
    }
}
