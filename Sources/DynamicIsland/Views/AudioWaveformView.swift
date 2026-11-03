import SwiftUI

/// Glitch-free, zero-layout-shift live audio waveform rendered via TimelineView + Canvas.
/// Unlike `.repeatForever` animations on `@State`, this never leaks animation transactions
/// into parent notch hover/expand animations and never freezes on view re-mounts.
public struct AudioWaveformView: View {
    public var isPlaying: Bool
    public var color: Color
    public var barCount: Int

    public init(isPlaying: Bool = true, color: Color = .green, barCount: Int = 4) {
        self.isPlaying = isPlaying
        self.color = color
        self.barCount = max(3, barCount)
    }

    // Distinct organic frequencies & phases per bar
    private let frequencies: [Double] = [4.4, 6.1, 5.2, 6.8, 4.9, 5.7]
    private let phases: [Double]      = [0.0, 1.3, 2.5, 0.8, 3.6, 2.1]
    // Acoustic envelope so middle bars reach higher peaks than outer bars
    private func envelope(for index: Int, total: Int) -> Double {
        guard total > 1 else { return 1.0 }
        let normalized = Double(index) / Double(total - 1) // 0 ... 1
        let distFromCenter = abs(normalized - 0.5) * 2.0   // 0 at center, 1 at edge
        return 1.0 - (distFromCenter * 0.28)
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let count = barCount
                let spacing: CGFloat = size.width >= 18 ? 2.2 : 1.8
                let totalSpacing = spacing * CGFloat(count - 1)
                let barWidth = max(1.8, (size.width - totalSpacing) / CGFloat(count))
                let midY = size.height / 2.0

                for i in 0..<count {
                    let ratio: Double
                    if isPlaying {
                        let f1 = frequencies[i % frequencies.count]
                        let f2 = f1 * 0.63
                        let p = phases[i % phases.count]
                        let wave1 = (sin(t * f1 + p) + 1.0) * 0.5
                        let wave2 = (sin(t * f2 + p * 1.7) + 1.0) * 0.5
                        let combined = (wave1 * 0.65 + wave2 * 0.35)
                        let env = envelope(for: i, total: count)
                        ratio = 0.22 + combined * 0.76 * env
                    } else {
                        ratio = 0.22
                    }

                    let barHeight = max(barWidth, size.height * CGFloat(ratio))
                    let x = CGFloat(i) * (barWidth + spacing)
                    let y = midY - barHeight / 2.0
                    let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                    let path = Path(roundedRect: rect, cornerRadius: barWidth / 2.0)

                    context.fill(
                        path,
                        with: .color(isPlaying ? color : color.opacity(0.45))
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}
