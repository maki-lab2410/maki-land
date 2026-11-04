import SwiftUI

public struct VoiceRecorderView: View {
    @ObservedObject private var service = VoiceRecorderService.shared
    @ObservedObject private var state = IslandState.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            // Header Bar
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text("🎙️")
                        .font(.system(size: 13))
                    Text("Perekam Memo Suara")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                if service.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("Merekam...")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.red.opacity(0.95))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.18))
                    .clipShape(Capsule())
                }

                Spacer()

                // Close / Cancel Button
                Button {
                    service.cancel()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        state.isShowingVoiceRecorder = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)

            // Central Recording Card
            VStack(spacing: 10) {
                if let err = service.errorMessage {
                    VStack(spacing: 6) {
                        Image(systemName: "mic.slash.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                        Text(err)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .frame(height: 70)
                } else {
                    // Duration Counter
                    Text(service.formattedDuration)
                        .font(.system(size: 26, weight: .heavy, design: .monospaced))
                        .foregroundColor(service.isRecording ? .white : .white.opacity(0.6))
                        .shadow(color: service.isRecording ? Color.red.opacity(0.4) : Color.clear, radius: 8)

                    // Dynamic Waveform Visualizer
                    HStack(spacing: 3) {
                        ForEach(Array(service.audioLevels.enumerated()), id: \.offset) { _, level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearGradient(
                                    colors: [Color.pink.opacity(0.9), Color.red.opacity(0.95)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                ))
                                .frame(width: 4, height: max(4, level * 36))
                                .animation(.easeOut(duration: 0.08), value: level)
                        }
                    }
                    .frame(height: 40)

                    Text("Bicara ke mikrofon. Hasil rekaman langsung masuk ke Tray & Clipboard.")
                        .font(.system(size: 9.2, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 105)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)

            // Bottom Action Controls
            HStack(spacing: 10) {
                // Cancel Button
                Button {
                    service.cancel()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        state.isShowingVoiceRecorder = false
                    }
                } label: {
                    Text("✕ Batal")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white.opacity(0.65))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                if service.isRecording {
                    // Stop and Save Button
                    Button {
                        service.stopAndSave()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            state.isShowingVoiceRecorder = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.fill")
                                .font(.system(size: 9))
                            Text("Selesai & Simpan ke Tray")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(LinearGradient(colors: [Color.red, Color.pink], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.red.opacity(0.35), radius: 5, x: 0, y: 1.5)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Start Recording Button
                    Button {
                        service.startRecording()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "record.circle.fill")
                                .font(.system(size: 10))
                            Text("Mulai Merekam")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)

            // Saved Banner
            if let banner = service.lastSavedBanner {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(banner)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.25))
                .clipShape(Capsule())
                .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            service.startRecording()
        }
    }
}
