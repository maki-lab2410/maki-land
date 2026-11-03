import SwiftUI
import UniformTypeIdentifiers

public enum IslandTab: String, CaseIterable, Identifiable {
    case makiLand  = "maki-land"
    case capy      = "Capy"
    case notes     = "Notes"
    case launcher  = "Launch"
    case tray      = "Tray"
    case monitor   = "System"
    case clipboard = "Clipboard"
    case timer     = "Timer"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .makiLand:  return "sparkles"
        case .capy:      return "pawprint.fill"
        case .notes:     return "note.text"
        case .launcher:  return "square.grid.2x2.fill"
        case .tray:      return "tray.fill"
        case .monitor:   return "chart.bar.fill"
        case .clipboard: return "doc.on.clipboard"
        case .timer:     return "timer"
        }
    }
}

public class IslandState: ObservableObject {
    public static let shared = IslandState()

    @Published public var isExpanded: Bool = false
    @Published public var selectedTab: IslandTab = .makiLand {
        didSet {
            if oldValue != selectedTab && isExpanded {
                notifySize()
            }
        }
    }
    @Published public var isPinned: Bool = false
    @Published public var isModalOpen: Bool = false
    @Published public var forceClearHoverTrigger: Int = 0

    public var onSizeChange: ((CGSize) -> Void)?
    public private(set) var collapseCooldownUntil: Date = .distantPast

    public init() {}

    public var expandedTargetSize: CGSize {
        switch selectedTab {
        case .tray:
            if let studioItem = DropZoneService.shared.activeStudioItem {
                switch studioItem.kind {
                case .pdf:
                    return CGSize(width: 680, height: 294)
                case .image:
                    return CGSize(width: 660, height: 242)
                case .other:
                    return CGSize(width: 660, height: 198)
                }
            }
            return CGSize(width: 660, height: 162)
        case .makiLand:
            return CalendarService.shared.isShowingSettings
                ? CGSize(width: 660, height: 174)
                : CGSize(width: 660, height: 156)
        case .notes:
            return CGSize(width: 660, height: 198)
        case .capy:
            return GeminiService.shared.isNotchChatMode
                ? CGSize(width: 668, height: 258)
                : CGSize(width: 660, height: 184)
        case .launcher:
            return CGSize(width: 660, height: 164)
        case .clipboard:
            return CGSize(width: 660, height: 184)
        case .timer:
            return CGSize(width: 660, height: 158)
        case .monitor:
            return CGSize(width: 660, height: 198)
        }
    }

    public var currentTargetSize: CGSize {
        guard isExpanded else {
            let showMini = CapybaraService.shared.showInCompactNotch && !CapybaraService.shared.isOnDesktop
            let baseW: CGFloat = showMini ? 238 : 210
            return CGSize(width: baseW, height: 32)
        }
        return expandedTargetSize
    }

    public func toggleExpand() {
        setExpanded(!isExpanded)
    }

    public func setExpanded(_ v: Bool) {
        guard isExpanded != v else { return }
        if !v {
            collapseCooldownUntil = Date().addingTimeInterval(0.42)
        }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            isExpanded = v
        }
        notifySize()
    }

    public func notifySize() {
        onSizeChange?(currentTargetSize)
    }
}

public struct IslandRootView: View {
    @ObservedObject var state = IslandState.shared
    @ObservedObject var micService = MicService.shared
    @ObservedObject var dropService = DropZoneService.shared
    @ObservedObject var capyService = CapybaraService.shared
    @ObservedObject var calService = CalendarService.shared
    @ObservedObject var geminiService = GeminiService.shared

    @State private var isCompactHovering = false
    @State private var hoverExitWork: DispatchWorkItem? = nil

    private var compactBaseW: CGFloat {
        (capyService.showInCompactNotch && !capyService.isOnDesktop) ? 238 : 210
    }

    private var notchW: CGFloat {
        if state.isExpanded {
            return state.expandedTargetSize.width
        }
        return isCompactHovering ? (compactBaseW + 16) : compactBaseW
    }

    private var notchH: CGFloat {
        if state.isExpanded {
            return state.expandedTargetSize.height
        }
        return isCompactHovering ? 35 : 32
    }

    private var bottomRadius: CGFloat {
        if state.isExpanded {
            return 22
        }
        return isCompactHovering ? 15 : 14
    }

    private var earRadius: CGFloat {
        state.isExpanded ? 10 : 8
    }

    public init() {}

    public var body: some View {
        ZStack(alignment: .top) {
            // Black Hardware Notch Shell — centered at x = 360, top-pinned at y = 0 inside fixed 720x330 canvas!
            ZStack(alignment: .top) {
                NotchShape(
                    bottomRadius: bottomRadius,
                    earRadius: earRadius
                )
                .fill(Color.black)
                .shadow(
                    color: Color.black.opacity(state.isExpanded ? 0.38 : (isCompactHovering ? 0.28 : 0.18)),
                    radius: state.isExpanded ? 12 : (isCompactHovering ? 7 : 4),
                    x: 0,
                    y: state.isExpanded ? 6 : (isCompactHovering ? 2 : 1)
                )

                // Symmetrically top-centered content (blooms smoothly downward & outward from center!)
                ZStack(alignment: .top) {
                    CompactIslandView()
                        .frame(width: compactBaseW + (isCompactHovering ? 16 : 0), height: 32)
                        .opacity(state.isExpanded ? 0 : 1)
                        .allowsHitTesting(!state.isExpanded)

                    if state.isExpanded {
                        expandedContent
                            .frame(
                                width: state.expandedTargetSize.width,
                                height: state.expandedTargetSize.height,
                                alignment: .top
                            )
                            .transition(
                                .opacity.combined(with: .scale(scale: 0.90, anchor: .top))
                            )
                    }
                }
                .frame(width: notchW, height: notchH, alignment: .top)
                .clipShape(NotchShape(
                    bottomRadius: bottomRadius,
                    earRadius: earRadius
                ))

                // Crisp Notch Rim Highlight
                NotchShape(
                    bottomRadius: bottomRadius,
                    earRadius: earRadius
                )
                .stroke(
                    Color.white.opacity((!state.isExpanded && isCompactHovering) ? 0.24 : 0.09),
                    lineWidth: (!state.isExpanded && isCompactHovering) ? 0.75 : 0.5
                )
                .allowsHitTesting(false)
            }
            .frame(width: notchW, height: notchH, alignment: .top)
            // Single unified spring so expand/collapse/tab-resize never fight or skew diagonally!
            .animation(.spring(response: 0.36, dampingFraction: 0.86), value: notchW)
            .animation(.spring(response: 0.36, dampingFraction: 0.86), value: notchH)

            // Stable rectangular hover, click & file-drop sensor ONLY when collapsed
            if !state.isExpanded {
                Color.clear
                    .frame(width: compactBaseW + 18, height: 36)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isCompactHovering = false
                        state.setExpanded(true)
                    }
                    .onHover { hovering in
                        handleCompactHover(hovering)
                    }
                    .onDrop(of: DropZoneService.supportedDropUTTypes, isTargeted: $capyService.isMouthOpenForDrop) { providers in
                        capyService.handleDroppedProviders(providers)
                    }
            }
        }
        .frame(
            width: IslandController.canvasSize.width,
            height: IslandController.canvasSize.height,
            alignment: .top
        )
        .onChange(of: state.isExpanded) { expanded in
            if expanded {
                hoverExitWork?.cancel()
                isCompactHovering = false
            }
        }
        .onChange(of: state.forceClearHoverTrigger) { _ in
            hoverExitWork?.cancel()
            if isCompactHovering {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    isCompactHovering = false
                }
            }
        }
    }

    private func handleCompactHover(_ hovering: Bool) {
        hoverExitWork?.cancel()
        if hovering {
            guard Date() >= state.collapseCooldownUntil else { return }
            if !isCompactHovering {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                    isCompactHovering = true
                }
            }
        } else {
            let work = DispatchWorkItem {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    isCompactHovering = false
                }
            }
            hoverExitWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.085, execute: work)
        }
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            // Scrollable Tab Bar
            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(IslandTab.allCases) { tab in
                            Button {
                                guard state.selectedTab != tab else { return }
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                    state.selectedTab = tab
                                }
                            } label: {
                                HStack(spacing: 3.5) {
                                    Image(systemName: tab.iconName)
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(tab.rawValue)
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4.5)
                                .background(state.selectedTab == tab ? Color.white.opacity(0.22) : Color.white.opacity(0.06))
                                .foregroundColor(state.selectedTab == tab ? .white : .white.opacity(0.58))
                                .clipShape(Capsule())
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Global Mic Mute Button
                Button {
                    micService.toggleMute()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: micService.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 11, weight: .bold))
                        if micService.isMuted {
                            Text("Muted")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                    }
                    .padding(.horizontal, micService.isMuted ? 7 : 5)
                    .padding(.vertical, 4)
                    .background(micService.isMuted ? Color.red.opacity(0.25) : Color.white.opacity(0.08))
                    .foregroundColor(micService.isMuted ? .red : .white.opacity(0.55))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Pin Button
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { state.isPinned.toggle() }
                } label: {
                    Image(systemName: state.isPinned ? "pin.fill" : "pin.slash")
                        .font(.system(size: 11))
                        .foregroundColor(state.isPinned ? .orange : .white.opacity(0.35))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Minimize chevron
                Button {
                    state.setExpanded(false)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
            .padding(.horizontal, 18)

            // Content Area + Contextual 2D Interactive Capybara in Every Menu!
            HStack(alignment: .center, spacing: 10) {
                Group {
                    switch state.selectedTab {
                    case .makiLand:
                        HStack(spacing: 0) {
                            NowPlayingView()
                                .frame(width: 222)

                            Color.white.opacity(0.08)
                                .frame(width: 0.5, height: 75)
                                .padding(.horizontal, 8)

                            CalendarGlanceView()
                                .frame(maxWidth: .infinity)
                        }
                    case .capy:
                        CapybaraHabitatView()
                    case .notes:
                        NotesView()
                    case .launcher:
                        LauncherView()
                    case .tray:
                        DropZoneView()
                    case .monitor:
                        SystemMonitorView()
                    case .clipboard:
                        ClipboardView()
                    case .timer:
                        TimerView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if state.selectedTab != .capy {
                    ContextualCapyView(tab: state.selectedTab)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 9)
            // Top-layer natural comic speech bubble beside Maki so AppKit NSViews (Notes/TextFields) NEVER cover it!
            .overlay(alignment: .topTrailing) {
                if state.selectedTab != .capy, let tip = capyService.contextualTip {
                    CapySpeechBubbleView(
                        text: tip,
                        tail: .trailing,
                        fontSize: 9.8,
                        maxBubbleWidth: 178
                    )
                    .padding(.trailing, 98)
                    .padding(.top, 14)
                    .transition(.scale(scale: 0.88, anchor: .trailing).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .zIndex(100)
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.80), value: capyService.contextualTip)

            Spacer(minLength: 0)
        }
    }
}
