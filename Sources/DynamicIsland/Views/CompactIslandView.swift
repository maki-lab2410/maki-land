import SwiftUI
import Combine

public struct CompactIslandView: View {
    @ObservedObject var musicService = MusicService.shared
    @ObservedObject var batteryService = BatteryService.shared
    @ObservedObject var timerService = TimerService.shared
    @ObservedObject var dropService = DropZoneService.shared
    @ObservedObject var micService = MicService.shared
    @ObservedObject var capyService = CapybaraService.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 7) {
            // Left Indicator
            if timerService.isTimeUpAlert {
                HStack(spacing: 5) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)

                    Text("WAKTU HABIS!")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.orange)
                }
            } else if timerService.totalSeconds > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)

                    Text(timerService.formattedTime)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
            } else if musicService.currentTrack.isPlaying {
                HStack(spacing: 5) {
                    Image(systemName: compactMusicIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(compactMusicColor)

                    Text(musicService.currentTrack.title)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: 102, alignment: .leading)
                }
            } else if !dropService.droppedItems.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "tray.full.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)

                    Text("\(dropService.droppedItems.count) file")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
            } else {
                // Default Battery & Status
                HStack(spacing: 5) {
                    if batteryService.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: batteryIconName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(batteryService.level <= 20 ? .red : .white.opacity(0.85))
                    }

                    Text("\(batteryService.level)%")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
            }

            Spacer(minLength: 4)

            // Center simulated camera notch lens dot + Mic mute indicator
            HStack(spacing: 4) {
                CameraLensDot()
                    .opacity(musicService.currentTrack.isPlaying ? 0.35 : 0.8)

                if micService.isMuted {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.red)
                }
            }

            Spacer(minLength: 4)

            // Right Indicator (+ Mini 2D Interactive Capybara Companion in Notch!)
            HStack(spacing: 6) {
                if capyService.showInCompactNotch && !capyService.isOnDesktop {
                    Capybara2DView(
                        role: musicService.currentTrack.isPlaying ? .djMusic : (timerService.isRunning ? .senseiTimer : .habitat),
                        action: capyService.currentAction,
                        orangesOnHead: capyService.orangesOnHead,
                        isOnsen: false,
                        isListeningMusic: musicService.currentTrack.isPlaying,
                        isFocusing: timerService.isRunning,
                        isDangling: false,
                        isMouthOpenForDrop: capyService.isMouthOpenForDrop,
                        lookVector: capyService.lookVector,
                        lastSquishTime: capyService.lastSquishTime,
                        facingRight: false,
                        mascotModel: capyService.mascotModel
                    )
                    .frame(width: 24, height: 22)
                    .allowsHitTesting(false)
                }

                if timerService.isTimeUpAlert {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                } else if timerService.totalSeconds > 0 {
                    Circle()
                        .trim(from: 0.0, to: CGFloat(timerService.progress))
                        .stroke(Color.orange, lineWidth: 2)
                        .frame(width: 12, height: 12)
                        .rotationEffect(.degrees(-90))
                } else if musicService.currentTrack.isPlaying {
                    AudioWaveformView(
                        isPlaying: true,
                        color: compactMusicColor,
                        barCount: 4
                    )
                    .frame(width: 15, height: 12)
                } else {
                    CurrentTimeLabel()
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
    }

    private var batteryIconName: String {
        if batteryService.level >= 90 { return "battery.100" }
        if batteryService.level >= 60 { return "battery.75" }
        if batteryService.level >= 40 { return "battery.50" }
        if batteryService.level >= 15 { return "battery.25" }
        return "battery.0"
    }

    private var compactMusicIcon: String {
        let name = musicService.currentTrack.displayAppName
        switch name {
        case "Spotify": return "music.note"
        case "Music", "Apple Music": return "music.note.list"
        case "Chrome", "Google Chrome", "YouTube": return "play.rectangle.fill"
        case "Safari": return "safari"
        default: return "music.note"
        }
    }

    private var compactMusicColor: Color {
        let name = musicService.currentTrack.displayAppName
        switch name {
        case "Spotify": return .green
        case "Music", "Apple Music": return .pink
        case "Chrome", "Google Chrome", "YouTube": return .red
        case "Safari": return .cyan
        default: return .green
        }
    }
}

// Simulated MacBook Camera Lens Dot
public struct CameraLensDot: View {
    public init() {}
    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                .frame(width: 9, height: 9)
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 5, height: 5)
            Circle()
                .fill(Color.cyan.opacity(0.2))
                .frame(width: 2, height: 2)
        }
    }
}

// Subtle live clock
public struct CurrentTimeLabel: View {
    @State private var timeString: String = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        Text(timeString)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.6))
            .onReceive(timer) { _ in updateTime() }
            .onAppear { updateTime() }
    }

    private func updateTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        timeString = formatter.string(from: Date())
    }
}
