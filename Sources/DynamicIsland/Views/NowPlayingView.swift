import SwiftUI

public struct NowPlayingView: View {
    @ObservedObject var musicService = MusicService.shared

    public init() {}

    private var gradientColors: [Color] {
        let name = musicService.currentTrack.displayAppName
        switch name {
        case "Spotify": return [Color.green.opacity(0.75), Color.black]
        case "Music", "Apple Music": return [Color.pink.opacity(0.75), Color.purple.opacity(0.55)]
        case "Chrome", "Google Chrome", "YouTube": return [Color.red.opacity(0.75), Color.black]
        case "Safari": return [Color.blue.opacity(0.75), Color.cyan.opacity(0.55)]
        default: return [Color.gray.opacity(0.5), Color.black]
        }
    }

    private var badgeColor: Color {
        let name = musicService.currentTrack.displayAppName
        switch name {
        case "Spotify": return .green
        case "Music", "Apple Music": return .pink
        case "Chrome", "Google Chrome", "YouTube": return .red
        case "Safari": return .cyan
        default: return .green
        }
    }

    private var badgeIcon: String {
        let name = musicService.currentTrack.displayAppName
        switch name {
        case "Spotify": return "music.note"
        case "Music", "Apple Music": return "music.note"
        case "Chrome", "Google Chrome", "YouTube": return "play.rectangle.fill"
        case "Safari": return "safari"
        default: return "music.note"
        }
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Album Art / App Cover
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                    .overlay(
                        Group {
                            if musicService.hasActiveMedia {
                                AudioWaveformView(
                                    isPlaying: musicService.currentTrack.isPlaying,
                                    color: .white.opacity(0.85),
                                    barCount: 5
                                )
                                .frame(width: 24, height: 18)
                            } else {
                                Image(systemName: "music.quarternote.3")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                        }
                    )
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)

                // Small App Badge
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(badgeColor)
                        .frame(width: 16, height: 16)

                    Image(systemName: badgeIcon)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 3, y: 3)
            }
            .frame(width: 62, height: 62)

            // Track Info & Playback Controls
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(musicService.currentTrack.title.isEmpty ? "Tidak Ada Musik" : musicService.currentTrack.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if musicService.currentTrack.isPlaying {
                        AudioWaveformView(
                            isPlaying: true,
                            color: badgeColor,
                            barCount: 4
                        )
                        .frame(width: 14, height: 11)
                    }
                }

                Text(musicService.currentTrack.artist.isEmpty ? "Buka Spotify / YouTube" : musicService.currentTrack.artist)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)

                // Controls Row
                HStack(spacing: 16) {
                    Button {
                        musicService.previousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)

                    Button {
                        musicService.togglePlayPause()
                    } label: {
                        Image(systemName: musicService.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        musicService.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}
