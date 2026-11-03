import SwiftUI
import UniformTypeIdentifiers

/// Interactive Coucou-style 2D Capybara companion present in EVERY menu:
/// - Eyes & snout track your cursor live across the screen
/// - Grounded squish on click (1-2 happy, 3-4 ticklish, 5+ dizzy!) — NEVER jumps upward!
/// - Drag downward out of the Island to set Maki loose on your Desktop!
/// - Drop any file onto Maki to swallow it straight into Tray / PDF Studio!
public struct ContextualCapyView: View {
    public let tab: IslandTab

    @ObservedObject var capy = CapybaraService.shared
    @ObservedObject var music = MusicService.shared
    @ObservedObject var timer = TimerService.shared
    @ObservedObject var monitor = SystemMonitorService.shared

    @State private var isHoveringCard = false
    @State private var localDropTarget = false
    @State private var localHeart = false
    @State private var didPopOutDrag = false

    public init(tab: IslandTab) {
        self.tab = tab
    }

    private var role: CapyRole {
        CapyRole.from(tab: tab)
    }

    public var body: some View {
        VStack(spacing: 2) {
            // Role Title Pill — crisp high contrast & never truncates!
            Text(role.badgeLabel)
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
                .padding(.horizontal, 5.5)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity)
                .background(roleAccentColor.opacity(0.32))
                .overlay(
                    Capsule().stroke(roleAccentColor.opacity(0.55), lineWidth: 0.6)
                )
                .clipShape(Capsule())

            // Grounded 2D Interactive Maki (Click = Pet/Poke, Drag Down = Pop to Desktop, Drop File = Swallow!)
            ZStack {
                Capybara2DView(
                    role: role,
                    action: capy.currentAction,
                    orangesOnHead: capy.orangesOnHead,
                    isOnsen: false,
                    isListeningMusic: music.currentTrack.isPlaying,
                    isFocusing: timer.isRunning,
                    isDangling: false,
                    isMouthOpenForDrop: localDropTarget || capy.isMouthOpenForDrop,
                    lookVector: capy.lookVector,
                    lastSquishTime: capy.lastSquishTime,
                    facingRight: false,
                    mascotModel: capy.mascotModel
                )
                .frame(width: 74, height: 58)
                .contentShape(Rectangle())
                .onTapGesture {
                    capy.interactInTab(tab)
                    if capy.currentAction == .happyPet {
                        triggerHeart()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 16)
                        .onChanged { val in
                            if !didPopOutDrag && val.translation.height > 42 {
                                didPopOutDrag = true
                                capy.releaseToDesktop(at: NSEvent.mouseLocation)
                            }
                        }
                        .onEnded { _ in
                            didPopOutDrag = false
                        }
                )

                if tab == .monitor && monitor.cpuPercent >= 60 {
                    Text("💦")
                        .font(.system(size: 9))
                        .offset(x: 22, y: -14)
                        .allowsHitTesting(false)
                } else if tab == .makiLand && music.currentTrack.isPlaying {
                    Text("♪")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                        .offset(x: -24, y: -14)
                        .allowsHitTesting(false)
                }

                if localHeart {
                    HStack(spacing: 2) {
                        Text("❤️").font(.system(size: 9.5))
                        Text("✨").font(.system(size: 8.5))
                    }
                    .offset(y: -18)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: 76, height: 60)
            .help("Klik: Elus Maki (toel 5x bikin pusing!) • Tarik ke bawah: Lepas ke Desktop • Drop File: Masuk Tray")

            // Quick Mini Care + AI Chat Row
            HStack(spacing: 2.5) {
                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                        GeminiService.shared.openChatInNotch()
                    }
                } label: {
                    Text("💬")
                        .font(.system(size: 8.2))
                        .frame(width: 17.5, height: 16)
                        .background(Color.orange.opacity(0.24))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Tanya Maki (Gemini AI)")

                Button {
                    capy.interactInTab(tab)
                    if capy.currentAction == .happyPet {
                        triggerHeart()
                    }
                } label: {
                    Text("👋")
                        .font(.system(size: 8.2))
                        .frame(width: 17.5, height: 16)
                        .background(Color.white.opacity(0.09))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Elus Maki")

                Button {
                    capy.feed(.orange)
                    triggerHeart()
                } label: {
                    Text("🍊")
                        .font(.system(size: 8.2))
                        .frame(width: 17.5, height: 16)
                        .background(Color.orange.opacity(0.18))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Kasih Jeruk")

                Button {
                    capy.toggleDesktopMode()
                } label: {
                    Image(systemName: capy.isOnDesktop ? "arrow.uturn.up" : "macwindow.on.rectangle")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(capy.isOnDesktop ? .green : .cyan)
                        .frame(width: 17.5, height: 16)
                        .background((capy.isOnDesktop ? Color.green : Color.cyan).opacity(0.18))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(capy.isOnDesktop ? "Panggil Maki kembali ke Notch" : "Lepas Maki ke Desktop (ala Coucou!)")
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .frame(width: 86)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(localDropTarget ? Color.orange.opacity(0.22) : Color.white.opacity(isHoveringCard ? 0.08 : 0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    localDropTarget ? Color.orange : roleAccentColor.opacity(isHoveringCard ? 0.42 : 0.14),
                    lineWidth: localDropTarget ? 1.2 : 0.7
                )
        )
        .onHover { h in isHoveringCard = h }
        .onDrop(of: DropZoneService.supportedDropUTTypes, isTargeted: $localDropTarget) { providers in
            capy.handleDroppedProviders(providers)
        }
    }

    private var roleAccentColor: Color {
        switch role {
        case .djMusic:            return .green
        case .habitat:            return .orange
        case .scholarNotes:       return .yellow
        case .pilotLauncher:      return .cyan
        case .builderTray:        return .orange
        case .mechanicSystem:     return .blue
        case .detectiveClipboard: return .purple
        case .senseiTimer:        return .orange
        }
    }

    private func triggerHeart() {
        localHeart = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            localHeart = false
        }
    }
}
