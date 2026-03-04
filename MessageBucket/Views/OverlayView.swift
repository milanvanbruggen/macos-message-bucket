import SwiftUI
import AppKit

// MARK: - Overlay view

struct OverlayView: View {
    let message: Message
    let onRead: () -> Void
    let onSnooze: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false

    // ── Grid constants ────────────────────────────────────────────────────────
    // The NSTextView enforces exactly 25 pt line height for every line.
    // Ruled lines are drawn at the actual baseline positions from the layout
    // manager, so there is no arithmetic to guess or tune.
    private let linePitch:    CGFloat = 25
    private let hPadding:     CGFloat = 32
    private let topPadding:   CGFloat = 28
    private let bottomPadding: CGFloat = 16

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            GeometryReader { geo in
                VStack(spacing: 20) {
                    let cardHeight = geo.size.height * 0.60
                    let cardWidth  = min(geo.size.width * 0.75, 960)

                    ZStack(alignment: .topLeading) {
                        // ── Paper surface ─────────────────────────────────────
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white.opacity(0.93))

                        // ── Scrollable ruled paper ────────────────────────────
                        PaperView(
                            message: message,
                            linePitch: linePitch,
                            hPadding: hPadding,
                            topPadding: topPadding,
                            bottomPadding: bottomPadding
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // ── Delete — top-right, separated from main actions ───
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

// MARK: - PaperView (NSScrollView + RuledTextView)

/// Wraps an NSScrollView whose document view is a RuledTextView.
/// The RuledTextView draws horizontal ruled lines at the actual baseline
/// of every text line — no arithmetic needed.
private struct PaperView: NSViewRepresentable {
    let message: Message
    let linePitch: CGFloat
    let hPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat

    func makeNSView(context: Context) -> NSScrollView {
        let textView = RuledTextView()
        textView.linePitch = linePitch
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: hPadding, height: topPadding)
        textView.textContainer?.lineFragmentPadding = 0
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)

        // Allow the text view to grow taller than its clip view so scrolling works
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        scrollView.contentView.postsBoundsChangedNotifications = false

        applyAttributedString(to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? RuledTextView else { return }
        applyAttributedString(to: textView)
    }

    // MARK: – Build attributed string

    private func applyAttributedString(to textView: RuledTextView) {
        let full = NSMutableAttributedString()

        // ── Shared paragraph style (25 pt locked line height) ─────────────────
        let para = NSMutableParagraphStyle()
        para.minimumLineHeight = linePitch
        para.maximumLineHeight = linePitch

        // ── Monospaced body font ───────────────────────────────────────────────
        let bodyFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .bold)
        let semiFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)

        let bodyColor   = NSColor.black.withAlphaComponent(0.72)
        let titleColor  = NSColor.black.withAlphaComponent(0.85)
        let sourceColor = NSColor(hue: 0.62, saturation: 0.55, brightness: 0.52, alpha: 1)
        let dividerColor = NSColor.black.withAlphaComponent(0.15)

        func attrs(_ font: NSFont, _ color: NSColor) -> [NSAttributedString.Key: Any] {
            [.font: font, .foregroundColor: color, .paragraphStyle: para, .baselineOffset: 4]
        }

        // Source header
        if let source = message.source {
            full.append(NSAttributedString(
                string: "# \(source)\n",
                attributes: attrs(boldFont, sourceColor)
            ))
        }

        // Title
        full.append(NSAttributedString(
            string: "\(message.title)\n",
            attributes: attrs(semiFont, titleColor)
        ))

        // Divider
        full.append(NSAttributedString(
            string: "\(String(repeating: "─", count: 80))\n",
            attributes: attrs(bodyFont, dividerColor)
        ))

        // Body — parse markdown, fall back to plain text
        let bodyAttr: NSAttributedString
        if let md = try? NSAttributedString(
            markdown: message.body,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            let mutableBody = NSMutableAttributedString(attributedString: md)
            // Apply our paragraph style and base font/color to the whole body,
            // but preserve bold/italic runs from markdown.
            mutableBody.enumerateAttributes(
                in: NSRange(location: 0, length: mutableBody.length)
            ) { existingAttrs, range, _ in
                var mergedAttrs = attrs(bodyFont, bodyColor)
                // Preserve bold/italic from markdown by checking the existing font's traits
                if let existingFont = existingAttrs[.font] as? NSFont {
                    let traits = existingFont.fontDescriptor.symbolicTraits
                    let isBold   = traits.contains(.bold)
                    let isItalic = traits.contains(.italic)
                    if isBold && isItalic {
                        mergedAttrs[.font] = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .bold)
                    } else if isBold {
                        mergedAttrs[.font] = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .bold)
                    } else if isItalic {
                        mergedAttrs[.font] = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
                    }
                }
                mutableBody.setAttributes(mergedAttrs, range: range)
            }
            bodyAttr = mutableBody
        } else {
            bodyAttr = NSAttributedString(string: message.body, attributes: attrs(bodyFont, bodyColor))
        }
        full.append(bodyAttr)

        // Bottom padding — add a few blank lines so text doesn't end flush at card bottom
        full.append(NSAttributedString(
            string: "\n",
            attributes: attrs(bodyFont, .clear)
        ))

        textView.textStorage?.setAttributedString(full)
    }
}

// MARK: - RuledTextView

/// NSTextView subclass that draws horizontal rules at each text baseline.
/// Lines are drawn BEFORE calling super.draw() so glyphs render on top.
final class RuledTextView: NSTextView {

    /// Must be set after init; matches the paragraph style's locked line height.
    var linePitch: CGFloat = 25

    private let ruleColor = NSColor(hue: 0.62, saturation: 0.22, brightness: 0.88, alpha: 1)

    override func draw(_ dirtyRect: NSRect) {
        // Draw ruled lines first — text glyphs render on top via super.draw()
        drawRuledLines(in: dirtyRect)
        super.draw(dirtyRect)
    }

    private func drawRuledLines(in dirtyRect: NSRect) {
        guard
            let layoutManager = self.layoutManager,
            let textContainer = self.textContainer
        else { return }

        // Make sure layout is complete before querying line fragments
        layoutManager.ensureLayout(for: textContainer)

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        let containerOrigin = self.textContainerOrigin  // accounts for textContainerInset

        ruleColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 0.5

        let font = self.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        var lastViewY: CGFloat = -1

        layoutManager.enumerateLineFragments(
            forGlyphRange: glyphRange
        ) { [weak self] (_, usedRect, _, _, _) in
            guard let self = self else { return }
            // usedRect is in text-container coordinates.
            // Baseline Y in container coords: bottom of usedRect + descender (descender is negative)
            let baselineY = usedRect.maxY + font.descender
            let viewY = baselineY + containerOrigin.y
            lastViewY = viewY

            if viewY >= dirtyRect.minY - 1 && viewY <= dirtyRect.maxY + 1 {
                path.move(to: NSPoint(x: 0, y: viewY))
                path.line(to: NSPoint(x: self.bounds.width, y: viewY))
            }
        }

        // Continue drawing lines below the last text line to fill the whole card.
        if lastViewY > 0 {
            var y = lastViewY + linePitch
            while y <= bounds.height {
                if y >= dirtyRect.minY - 1 && y <= dirtyRect.maxY + 1 {
                    path.move(to: NSPoint(x: 0, y: y))
                    path.line(to: NSPoint(x: bounds.width, y: y))
                }
                y += linePitch
            }
        }

        path.stroke()
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
