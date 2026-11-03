import SwiftUI

public enum SpeechTailDirection: Sendable {
    case bottom
    case trailing
    case none
}

/// Hand-crafted comic speech bubble shape that matches Maki's warm 2D vector outline.
public struct CapySpeechBubbleShape: Shape {
    public var tail: SpeechTailDirection
    public var cornerRadius: CGFloat

    public init(tail: SpeechTailDirection = .bottom, cornerRadius: CGFloat = 11) {
        self.tail = tail
        self.cornerRadius = cornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        var p = Path()

        switch tail {
        case .bottom:
            let tailH: CGFloat = 5.5
            let tailHalfW: CGFloat = 5.0
            let b = CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: max(12, rect.height - tailH)
            )
            let r = min(cornerRadius, min(b.width, b.height) * 0.46)
            let cx = b.midX

            p.move(to: CGPoint(x: b.minX + r, y: b.minY))
            p.addLine(to: CGPoint(x: b.maxX - r, y: b.minY))
            p.addArc(center: CGPoint(x: b.maxX - r, y: b.minY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: CGPoint(x: b.maxX, y: b.maxY - r))
            p.addArc(center: CGPoint(x: b.maxX - r, y: b.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)

            // Bottom edge with organic little pointer tail down to Maki
            let rightBase = min(b.maxX - r - 2, cx + tailHalfW)
            let leftBase = max(b.minX + r + 2, cx - tailHalfW)
            p.addLine(to: CGPoint(x: rightBase, y: b.maxY))
            p.addQuadCurve(
                to: CGPoint(x: cx - 1.0, y: rect.maxY),
                control: CGPoint(x: cx + 2.5, y: b.maxY + tailH * 0.55)
            )
            p.addQuadCurve(
                to: CGPoint(x: leftBase, y: b.maxY),
                control: CGPoint(x: cx - 2.5, y: b.maxY + tailH * 0.45)
            )

            p.addLine(to: CGPoint(x: b.minX + r, y: b.maxY))
            p.addArc(center: CGPoint(x: b.minX + r, y: b.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            p.addLine(to: CGPoint(x: b.minX, y: b.minY + r))
            p.addArc(center: CGPoint(x: b.minX + r, y: b.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.closeSubpath()

        case .trailing:
            let tailW: CGFloat = 5.5
            let tailHalfH: CGFloat = 4.2
            let b = CGRect(
                x: rect.minX,
                y: rect.minY,
                width: max(12, rect.width - tailW),
                height: rect.height
            )
            let r = min(cornerRadius, min(b.width, b.height) * 0.46)
            let cy = b.midY

            p.move(to: CGPoint(x: b.minX + r, y: b.minY))
            p.addLine(to: CGPoint(x: b.maxX - r, y: b.minY))
            p.addArc(center: CGPoint(x: b.maxX - r, y: b.minY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)

            let topBase = max(b.minY + r + 1.5, cy - tailHalfH)
            let botBase = min(b.maxY - r - 1.5, cy + tailHalfH)
            p.addLine(to: CGPoint(x: b.maxX, y: topBase))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: cy + 1.0),
                control: CGPoint(x: b.maxX + tailW * 0.55, y: cy - 1.5)
            )
            p.addQuadCurve(
                to: CGPoint(x: b.maxX, y: botBase),
                control: CGPoint(x: b.maxX + tailW * 0.55, y: cy + 2.5)
            )

            p.addLine(to: CGPoint(x: b.maxX, y: b.maxY - r))
            p.addArc(center: CGPoint(x: b.maxX - r, y: b.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: CGPoint(x: b.minX + r, y: b.maxY))
            p.addArc(center: CGPoint(x: b.minX + r, y: b.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            p.addLine(to: CGPoint(x: b.minX, y: b.minY + r))
            p.addArc(center: CGPoint(x: b.minX + r, y: b.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.closeSubpath()

        case .none:
            p.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        }

        return p
    }
}

/// Natural, snug-fitting comic speech bubble matching Maki's warm capybara palette.
/// Hugs short phrases tightly (never stretches into a wide artificial bar) while wrapping longer lines cleanly.
public struct CapySpeechBubbleView: View {
    public let text: String
    public var tail: SpeechTailDirection = .bottom
    public var fontSize: CGFloat = 10.5
    public var maxBubbleWidth: CGFloat = 188

    private let creamPaper = Color(red: 1.0, green: 0.985, blue: 0.945)
    private let espressoOutline = Color(red: 0.23, green: 0.13, blue: 0.06)
    private let espressoInk = Color(red: 0.20, green: 0.11, blue: 0.05)

    public init(
        text: String,
        tail: SpeechTailDirection = .bottom,
        fontSize: CGFloat = 10.5,
        maxBubbleWidth: CGFloat = 188
    ) {
        self.text = text
        self.tail = tail
        self.fontSize = fontSize
        self.maxBubbleWidth = maxBubbleWidth
    }

    public var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .medium, design: .rounded))
            .foregroundColor(espressoInk)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, 10)
            .padding(.top, 5)
            .padding(.bottom, tail == .bottom ? 10.5 : 5)
            .padding(.trailing, tail == .trailing ? 5.5 : 0)
            .background(
                CapySpeechBubbleShape(tail: tail, cornerRadius: 11)
                    .fill(creamPaper)
                    .shadow(color: .black.opacity(0.18), radius: 3.5, x: 0, y: 1.5)
            )
            .overlay(
                CapySpeechBubbleShape(tail: tail, cornerRadius: 11)
                    .stroke(
                        espressoOutline,
                        style: StrokeStyle(lineWidth: 1.55, lineCap: .round, lineJoin: .round)
                    )
            )
            // Placed AFTER background/overlay so the bubble hugs intrinsic text width up to maxBubbleWidth!
            .frame(maxWidth: maxBubbleWidth, alignment: tail == .trailing ? .trailing : .center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
