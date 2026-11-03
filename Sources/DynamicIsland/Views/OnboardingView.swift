import SwiftUI
import AppKit

public struct OnboardingView: View {
    @ObservedObject var state = IslandState.shared
    @ObservedObject var geminiService = GeminiService.shared
    @State private var currentStep: Int = 1
    private let totalSteps: Int = 4

    public init() {}

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Main Step Content
                Group {
                    switch currentStep {
                    case 1:
                        stepWelcome
                    case 2:
                        stepDesktopCapy
                    case 3:
                        stepAISetup
                    case 4:
                        stepFinalReady
                    default:
                        stepWelcome
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Footer: Stepper Dots & Navigation Buttons
                HStack(spacing: 12) {
                    // Step Indicator Dots
                    HStack(spacing: 5) {
                        ForEach(1...totalSteps, id: \.self) { step in
                            Circle()
                                .fill(step == currentStep ? Color.orange : Color.white.opacity(0.25))
                                .frame(width: step == currentStep ? 7.5 : 5.5, height: step == currentStep ? 7.5 : 5.5)
                                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: currentStep)
                        }
                    }

                    Spacer()

                    // Previous Button
                    if currentStep > 1 {
                        Button {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                                currentStep -= 1
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Kembali")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white.opacity(0.85))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    // Next / Finish Button
                    Button {
                        if currentStep < totalSteps {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                                currentStep += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(currentStep < totalSteps ? "Lanjut" : "Mulai Sekarang! 🚀")
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            if currentStep < totalSteps {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
                        .padding(.horizontal, currentStep < totalSteps ? 12 : 16)
                        .padding(.vertical, 5.5)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.orange.opacity(0.35), radius: 4, y: 1)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Close button (Top Right)
            Button {
                completeOnboarding()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.40))
                    .padding(8)
            }
            .buttonStyle(.plain)
            .help("Tutup panduan")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding_v1")
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            state.isShowingOnboarding = false
        }
    }

    // MARK: - Slide 1: Welcome to maki-land
    private var stepWelcome: some View {
        HStack(spacing: 16) {
            // Left Hero Badge
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.18))
                        .frame(width: 64, height: 64)
                    Text("🏝️")
                        .font(.system(size: 32))
                }
                Text("maki-land")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
            }
            .frame(width: 95)

            // Right Narrative
            VStack(alignment: .leading, spacing: 6) {
                Text("Selamat Datang di maki-land! 👋")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text("Aplikasi Dynamic Island interaktif & maskot capybara hidup di layarmu. Gratis dan open-source.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white.opacity(0.80))
                    .lineSpacing(2)

                VStack(alignment: .leading, spacing: 4) {
                    featureBullet(icon: "cursorarrow.click.2", text: "Klik atau hover notch di atas layar untuk membuka panel ringkasan")
                    featureBullet(icon: "music.note", text: "Kontrol musik (Spotify, YouTube, Music) & intip kalender harimu")
                    featureBullet(icon: "note.text", text: "Scratchpad cepat, To-Do list, file Drop Tray, serta PDF Studio")
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Slide 2: Desktop Capybara Companion
    private var stepDesktopCapy: some View {
        HStack(spacing: 16) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.18))
                        .frame(width: 64, height: 64)
                    Text("🐾")
                        .font(.system(size: 32))
                }
                Text("Maki Temanmu")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
            }
            .frame(width: 95)

            VStack(alignment: .leading, spacing: 5) {
                Text("Ajak Maki Bermain di Desktop! 🐾")
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text("Tarik Maki keluar dari notch atau klik tombol 'Keluar ke Desktop'. Di desktop, dekatkan kursor untuk membuka Quick Dock:")
                    .font(.system(size: 9.8, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
                    .lineSpacing(1.5)

                VStack(alignment: .leading, spacing: 4) {
                    featureBullet(icon: "bubble.left.and.bubble.right.fill", text: "💬 Tanya Maki: Ngobrol cerdas dengan AI serbaguna")
                    featureBullet(icon: "camera.fill", text: "📸 Ambil screenshot layar langsung tersimpan ke Tray")
                    featureBullet(icon: "sparkles", text: "🍊 Kasih makan jeruk, atraksi sirkus, & berendam onsen hangat ♨️")
                    featureBullet(icon: "trash.circle.fill", text: "🧹 Sapu Cache Aman: Bersihkan sampah Mac ke Tong Sampah tanpa rm -rf")
                }
                .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Slide 3: Super Easy AI API Setup Guide
    private var stepAISetup: some View {
        HStack(spacing: 16) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.18))
                        .frame(width: 64, height: 64)
                    Text("🔑")
                        .font(.system(size: 30))
                }
                Text("Setup AI Cepat")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
            }
            .frame(width: 95)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("Cara Setup Kunci API AI (100% Gratis!) 🌿")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("Mudah")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Color.green.opacity(0.25))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }

                Text("Tanya Maki ditenagai AI pintar. Dapatkan kunci gratis dalam 3 langkah mudah:")
                    .font(.system(size: 9.6, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))

                VStack(alignment: .leading, spacing: 3) {
                    guideNumber(num: "1", text: "Klik tombol 'Buka Google AI Studio' di bawah (login dengan akun Google)")
                    guideNumber(num: "2", text: "Klik tombol biru 'Create API Key' (Buat Kunci API)")
                    guideNumber(num: "3", text: "Salin kuncinya, lalu tempel di Pengaturan API Key Maki")
                }
                .padding(.vertical, 1)

                // Quick Action Buttons
                HStack(spacing: 8) {
                    Button {
                        if let url = URL(string: "https://aistudio.google.com/app/apikey") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 9, weight: .bold))
                            Text("Buka Google AI Studio (Gratis)")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(Color.blue.opacity(0.35))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        geminiService.isShowingSettings = true
                        state.selectedTab = .capy
                        completeOnboarding()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 9))
                            Text("Buka Pengaturan Key Maki")
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4.5)
                        .background(Color.white.opacity(0.12))
                        .foregroundColor(.white.opacity(0.9))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 1)

                Text("💡 Bisa juga pakai Groq (console.groq.com) atau Ollama (100% lokal tanpa kunci API).")
                    .font(.system(size: 8.2, design: .rounded))
                    .foregroundColor(.white.opacity(0.48))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Slide 4: All Ready!
    private var stepFinalReady: some View {
        HStack(spacing: 16) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.20))
                        .frame(width: 64, height: 64)
                    Text("✨")
                        .font(.system(size: 32))
                }
                Text("Semua Siap!")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
            }
            .frame(width: 95)

            VStack(alignment: .leading, spacing: 5) {
                Text("Kamu Siap Menggunakan maki-land! 🚀")
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text("Tips penting untuk produktivitas harianmu:")
                    .font(.system(size: 9.8, design: .rounded))
                    .foregroundColor(.white.opacity(0.80))

                VStack(alignment: .leading, spacing: 4) {
                    featureBullet(icon: "command", text: "Tekan ⌘N di tab Notes untuk menambah tugas To-Do kilat")
                    featureBullet(icon: "arrow.right.circle", text: "Tekan ⌘↩ di Scratchpad untuk mengubah baris catatan jadi To-Do")
                    featureBullet(icon: "arrow.down.doc", text: "Tarik file gambar atau PDF apa saja ke mulut Maki untuk diolah di Tray")
                    featureBullet(icon: "questionmark.circle", text: "Buka panduan ini lagi kapan saja lewat ikon '❓' di notch atau klik kanan Maki")
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - UI Helpers
    private func featureBullet(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(.orange)
                .frame(width: 14)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 9.3, design: .rounded))
                .foregroundColor(.white.opacity(0.88))
                .lineLimit(2)
        }
    }

    private func guideNumber(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(num)
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 14, height: 14)
                .background(Color.cyan)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 9.2, design: .rounded))
                .foregroundColor(.white.opacity(0.88))
        }
    }
}
