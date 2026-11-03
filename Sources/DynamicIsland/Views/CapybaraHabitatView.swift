import SwiftUI
import UniformTypeIdentifiers

public struct CapybaraHabitatView: View {
    @ObservedObject var capy = CapybaraService.shared
    @ObservedObject var music = MusicService.shared
    @ObservedObject var timer = TimerService.shared
    @ObservedObject var gemini = GeminiService.shared

    @State private var showHeartParticle = false
    @State private var isDropTargeted = false
    @State private var didPopOutDrag = false

    public init() {}

    private var stageGradientColors: [Color] {
        if isDropTargeted {
            return [Color.orange.opacity(0.28), Color.black.opacity(0.45)]
        } else if capy.isOnsenMode {
            return [Color.cyan.opacity(0.20), Color.orange.opacity(0.10), Color.black.opacity(0.45)]
        } else {
            return [Color.green.opacity(0.18), Color.mint.opacity(0.08), Color.black.opacity(0.45)]
        }
    }

    public var body: some View {
        HStack(spacing: 12) {
            stageView

            // MARK: - Right: Either Gemini AI Chat OR Care & Desktop Companion Controls!
            if gemini.isNotchChatMode {
                MakiNotchChatPanelView()
            } else {
                habitatControlsColumn
            }
        }
        .padding(.vertical, 5)
    }

    // MARK: - Left: Interactive 2D Capybara Stage (Coucou-Style!)
    private var stageView: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: stageGradientColors, startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isDropTargeted ? Color.orange : Color.white.opacity(0.12), lineWidth: isDropTargeted ? 1.2 : 0.7)
                )

            // Soft meadow / pond floor glow
            Ellipse()
                .fill(capy.isOnsenMode ? Color.cyan.opacity(0.18) : Color.green.opacity(0.20))
                .frame(width: gemini.isNotchChatMode ? 114 : 148, height: 22)
                .padding(.bottom, 7)

            stageSpeechHeader

            stageCharacterView
                .padding(.bottom, gemini.isNotchChatMode ? 8 : 3)
                .offset(x: gemini.isNotchChatMode ? 0 : capy.posX * 0.45)
                .animation(.spring(response: 0.70, dampingFraction: 0.82), value: capy.posX)
        }
        .frame(width: gemini.isNotchChatMode ? 144 : 226)
        .frame(maxHeight: .infinity)
        .onDrop(of: DropZoneService.supportedDropUTTypes, isTargeted: $isDropTargeted) { providers in
            if gemini.isNotchChatMode {
                return handleChatDropProviders(providers)
            }
            return capy.handleDroppedProviders(providers)
        }
    }

    private var stageSpeechHeader: some View {
        VStack(spacing: 0) {
            if let bubble = capy.speechBubble {
                CapySpeechBubbleView(
                    text: bubble,
                    tail: .bottom,
                    fontSize: gemini.isNotchChatMode ? 9.0 : 9.8,
                    maxBubbleWidth: gemini.isNotchChatMode ? 132 : 196
                )
                .transition(.scale(scale: 0.88, anchor: .bottom).combined(with: .opacity))
            } else {
                Text(statusHintText)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .lineLimit(gemini.isNotchChatMode ? 2 : 1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 8)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 5)
        .animation(.spring(response: 0.28, dampingFraction: 0.80), value: capy.speechBubble)
        .allowsHitTesting(false)
        .zIndex(20)
    }

    private var stageCharacterView: some View {
        ZStack {
            Capybara2DView(
                role: .habitat,
                action: capy.currentAction,
                orangesOnHead: capy.orangesOnHead,
                isOnsen: capy.isOnsenMode && !gemini.isNotchChatMode,
                isListeningMusic: music.currentTrack.isPlaying,
                isFocusing: timer.isRunning,
                isDangling: false,
                isMouthOpenForDrop: isDropTargeted || capy.isMouthOpenForDrop,
                lookVector: capy.lookVector,
                lastSquishTime: capy.lastSquishTime,
                facingRight: gemini.isNotchChatMode ? true : capy.facingRight,
                mascotModel: capy.mascotModel
            )
            .frame(width: gemini.isNotchChatMode ? 98 : 108, height: gemini.isNotchChatMode ? 84 : 92)
            .contentShape(Rectangle())
            .onTapGesture {
                capy.pet()
                if capy.currentAction == .happyPet {
                    triggerHeartBurst()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 16)
                    .onChanged { val in
                        if !didPopOutDrag && val.translation.height > 40 {
                            didPopOutDrag = true
                            capy.releaseToDesktop(at: NSEvent.mouseLocation)
                        }
                    }
                    .onEnded { val in
                        if !didPopOutDrag && abs(val.translation.width) > 16 {
                            capy.walkTo(offsetX: capy.posX + val.translation.width * 0.6)
                        }
                        didPopOutDrag = false
                    }
            )

            if capy.currentAction == .sleeping {
                Text("zZz")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan.opacity(0.85))
                    .offset(x: 34, y: -26)
                    .allowsHitTesting(false)
            }

            if music.currentTrack.isPlaying {
                Text("♪ ♫")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green)
                    .offset(x: -38, y: -24)
                    .allowsHitTesting(false)
            }

            if showHeartParticle {
                HStack(spacing: 5) {
                    Text("❤️").font(.system(size: 12))
                    Text("✨").font(.system(size: 10))
                }
                .offset(y: -32)
                .allowsHitTesting(false)
            }
        }
    }

    private var habitatControlsColumn: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text("🐾 Maki Capybara")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Lv.\(capy.level)")
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.25))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                        gemini.openChatInNotch()
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8.5, weight: .bold))
                        Text("💬 Tanya AI")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.26))
                    .foregroundColor(.orange)
                    .overlay(Capsule().stroke(Color.orange.opacity(0.48), lineWidth: 0.6))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Ngobrol & tanya jawab langsung dengan Maki (Gemini AI)")

                Button {
                    capy.showInCompactNotch.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: capy.showInCompactNotch ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 9))
                        Text("Di Notch")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(capy.showInCompactNotch ? Color.green.opacity(0.22) : Color.white.opacity(0.08))
                    .foregroundColor(capy.showInCompactNotch ? .green : .white.opacity(0.5))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                miniStatBar(label: "Mood", icon: "heart.fill", value: capy.mood, color: .pink)
                miniStatBar(label: "Kenyang", icon: "leaf.fill", value: capy.fullness, color: .orange)
            }

            HStack(spacing: 5) {
                actionChip(title: "💬 Ngobrol", tint: .orange, active: true) {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                        gemini.openChatInNotch()
                    }
                }
                actionChip(title: "🎪 Atraksi", tint: .purple) {
                    capy.triggerRandomFunActivity()
                }
                actionChip(title: "👋 Elus", tint: .pink) {
                    capy.pet()
                    if capy.currentAction == .happyPet {
                        triggerHeartBurst()
                    }
                }
                ForEach(CapyFood.allCases) { food in
                    actionChip(title: "\(food.emoji) \(food.rawValue)", tint: .orange) {
                        capy.feed(food)
                        triggerHeartBurst()
                    }
                }
            }

            HStack(spacing: 5) {
                actionChip(
                    title: "🍊 Jeruk (\(capy.orangesOnHead)/3)",
                    tint: .yellow,
                    active: capy.orangesOnHead > 0
                ) {
                    capy.cycleOrangeOnHead()
                }

                actionChip(
                    title: capy.isOnsenMode ? "♨️ Selesai" : "♨️ Onsen",
                    tint: .cyan,
                    active: capy.isOnsenMode
                ) {
                    capy.toggleOnsen()
                }

                actionChip(
                    title: capy.isOnDesktop ? "🏠 Panggil ke Notch" : "🖥️ Lepas ke Desktop",
                    tint: .green,
                    active: capy.isOnDesktop
                ) {
                    capy.toggleDesktopMode()
                }

                actionChip(
                    title: capy.mascotModel == .plushie ? "🧸 Boneka" : "🐾 Klasik",
                    tint: capy.mascotModel == .plushie ? .cyan : .orange,
                    active: capy.mascotModel == .plushie
                ) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        capy.mascotModel = (capy.mascotModel == .classic) ? .plushie : .classic
                        capy.speechBubble = (capy.mascotModel == .plushie) ? "Aku pakai kaos 'maki' boneka! 🧸" : "Maki klasik pakai kaos coffee latte! 🐾"
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusHintText: String {
        if isDropTargeted {
            return gemini.isNotchChatMode ? "lepas gambar buat ditanyakan.." : "sini kasih filenya.."
        }
        if gemini.isThinking { return "bentar lagi mikir.." }
        if gemini.isNotchChatMode { return "drop gambar ke aku buat tanya isi gambarnya" }
        if capy.isReturningToNotch { return "lagi jalan balik ke atas.." }
        if capy.isOnDesktop { return "lagi main di desktop • klik panggil" }
        return "klik elus • tarik bawah ke desktop • kasih screenshot"
    }

    private func handleChatDropProviders(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var url: URL?
                    if let d = item as? Data {
                        url = URL(dataRepresentation: d, relativeTo: nil)
                    } else if let u = item as? URL {
                        url = u
                    }
                    if let resolved = url {
                        DispatchQueue.main.async {
                            if !GeminiService.shared.attachImage(from: resolved) {
                                _ = CapybaraService.shared.handleDroppedProviders(providers)
                            }
                        }
                    }
                }
                return true
            }
        }
        return capy.handleDroppedProviders(providers)
    }

    private func triggerHeartBurst() {
        showHeartParticle = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            showHeartParticle = false
        }
    }

    @ViewBuilder
    private func miniStatBar(label: String, icon: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8.5))
                    .foregroundColor(color)
                Text("\(label) \(value)%")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(max(0, min(100, value))) / 100.0)
                }
            }
            .frame(height: 4.5)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func actionChip(title: String, tint: Color, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .padding(.horizontal, 7.5)
                .padding(.vertical, 4.5)
                .background(active ? tint.opacity(0.26) : Color.white.opacity(0.09))
                .foregroundColor(active ? tint : .white.opacity(0.9))
                .overlay(
                    Capsule()
                        .stroke(active ? tint.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
