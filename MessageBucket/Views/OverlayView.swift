import SwiftUI

// MARK: - Overlay view

struct OverlayView: View {
    let message: Message
    let onRead: () -> Void
    let onSnooze: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false

    // ── Grid constants ───────────────────────────────────────────────────────
    // All text uses .body monospaced (13 pt on macOS).
    // Natural line height ≈ 16 pt. Added lineSpacing = 8 → total pitch = 24 pt.
    // Font ascender above baseline ≈ 11 pt.
    // We want ruled lines to sit ~4 pt below each baseline:
    //   firstRuledY = topPadding + ascender + 4 = 32 + 11 + 4 = 47 ≈ 48 (2 × 24)
    private let linePitch:       CGFloat = 25
    private let lineSpacingBody: CGFloat = 9   // adds to the 16 pt natural height → total pitch = 25
    private let ruledStartY:     CGFloat = 47  // first ruled line y from card top
    private let topPadding:      CGFloat = 28
    private let hPadding:        CGFloat = 32
    private let bottomPadding:   CGFloat = 16

    private let bodyFont = Font.system(.body, design: .monospaced)

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            // Hidden ESC → Snooze (always captured regardless of focus)
            Button("") { onSnooze() }
                .keyboardShortcut(.escape, modifiers: [])
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)

            GeometryReader { geo in
                VStack(spacing: 20) {
                    let cardHeight = geo.size.height * 0.60
                    let cardWidth  = min(geo.size.width * 0.75, 960)

                    ZStack(alignment: .topLeading) {
                        // ── Paper surface ────────────────────────────────────
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white.opacity(0.93))

                        // ── Ruled lines ──────────────────────────────────────
                        RuledLinesView(linePitch: linePitch, startY: ruledStartY)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        // ── Card content ─────────────────────────────────────
                        VStack(alignment: .leading, spacing: 0) {

                            // Source header (bold, indigo)
                            if let source = message.source {
                                Text("# \(source)")
                                    .font(bodyFont)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color(hue: 0.62, saturation: 0.55, brightness: 0.52))
                                    .tracking(0.4)
                                    .lineSpacing(lineSpacingBody)
                                    .accessibilityLabel("From: \(source)")
                            }

                            // Title (semibold, near-black)
                            Text(message.title)
                                .font(bodyFont)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color(.black).opacity(0.85))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(lineSpacingBody)
                                .padding(.top, lineSpacingBody)

                            // Divider (single line of em-dashes)
                            Text(String(repeating: "─", count: 80))
                                .font(bodyFont)
                                .foregroundStyle(Color(.black).opacity(0.15))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .lineSpacing(lineSpacingBody)
                                .padding(.top, lineSpacingBody)

                            // Body
                            ScrollView {
                                Text(LocalizedStringKey(message.body))
                                    .font(bodyFont)
                                    .foregroundStyle(Color(.black).opacity(0.72))
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(lineSpacingBody)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.top, lineSpacingBody)

                        }
                        .padding(.horizontal, hPadding)
                        .padding(.top, topPadding)
                        .padding(.bottom, bottomPadding)

                        // ── Delete — top-right, separated from main actions ──
                        HStack {
                            Spacer()
                            VStack {
                                Button(role: .destructive) {
                                    showingDeleteConfirmation = true
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(OverlayButtonStyle(small: true, tint: .red))
                                .colorScheme(.light)
                                .help("Delete message")
                                .accessibilityLabel("Delete message")
                                Spacer()
                            }
                        }
                        .padding(14)
                    }
                    .frame(width: cardWidth, height: cardHeight)
                    // Layered Apple-HIG shadow
                    .shadow(color: .black.opacity(0.04), radius: 2,  x: 0, y: 1)
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                    .shadow(color: .black.opacity(0.10), radius: 32, x: 0, y: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.black).opacity(0.06), lineWidth: 0.5)
                    )

                    // ── Action buttons — below the card ──────────────────────
                    HStack(spacing: 12) {
                        Button {
                            onSnooze()
                        } label: {
                            Label("Snooze", systemImage: "moon.zzz")
                        }
                        .buttonStyle(OverlayButtonStyle())
                        .accessibilityLabel("Snooze message")
                        .accessibilityHint("Dismiss overlay, message stays unread")

                        Button {
                            onRead()
                        } label: {
                            Label("Mark as Read", systemImage: "checkmark")
                        }
                        .buttonStyle(OverlayButtonStyle(filled: true))
                        .keyboardShortcut(.return, modifiers: [])
                        .accessibilityLabel("Mark as read")
                        .accessibilityHint("Mark message as read and archive it")
                    }
                    .colorScheme(.light)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .confirmationDialog(
            "Delete \"\(message.title)\"?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This message will be permanently deleted and cannot be recovered.")
        }
    }
}

// MARK: - Button style

private struct OverlayButtonStyle: ButtonStyle {
    var filled: Bool = false
    var small: Bool = false
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: small ? 12 : 14, weight: filled ? .semibold : .medium))
            .padding(small ? 9 : 0)
            .padding(.horizontal, small ? 0 : 18)
            .padding(.vertical, small ? 0 : 10)
            .background { background }
            .foregroundStyle(foreground)
            .clipShape(small ? AnyShape(Circle()) : AnyShape(Capsule()))
            .shadow(
                color: shadowColor.opacity(configuration.isPressed ? 0.06 : shadowOpacity),
                radius: configuration.isPressed ? 2 : shadowRadius,
                x: 0, y: configuration.isPressed ? 1 : shadowY
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    @ViewBuilder private var background: some View {
        if small {
            Circle()
                .fill(Color.white.opacity(0.9))
                .overlay(Circle().strokeBorder(tint.opacity(0.5), lineWidth: 0.5))
        } else if filled {
            Capsule()
                .fill(tint)
                .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
        } else {
            Capsule()
                .fill(Color.white.opacity(0.9))
                .overlay(Capsule().strokeBorder(Color(.separatorColor), lineWidth: 0.5))
        }
    }

    private var foreground: Color {
        filled ? .white : (small ? tint : Color(.labelColor))
    }

    private var shadowColor: Color { filled ? tint : .black }
    private var shadowOpacity: Double { filled ? 0.30 : (small ? 0.08 : 0.14) }
    private var shadowRadius: CGFloat { filled ? 10 : (small ? 4 : 6) }
    private var shadowY: CGFloat { filled ? 5 : (small ? 2 : 3) }
}

// MARK: - Ruled lines

/// Draws horizontal lines starting at `startY`, spaced `linePitch` apart.
/// `startY` is computed from the typography constants so lines always sit
/// just below each text baseline without any runtime measurement.
struct RuledLinesView: View {
    let linePitch: CGFloat
    let startY: CGFloat

    var body: some View {
        Canvas { ctx, size in
            var y = startY
            while y <= size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(
                    path,
                    with: .color(Color(hue: 0.62, saturation: 0.22, brightness: 0.88)),
                    lineWidth: 0.5
                )
                y += linePitch
            }
        }
    }
}

// MARK: - Visual effect blur

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
