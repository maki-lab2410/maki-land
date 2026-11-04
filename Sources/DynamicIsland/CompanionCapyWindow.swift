import Cocoa
import SwiftUI

public class CompanionCapyPanel: NSPanel {
    private var dragStartMouse: CGPoint = .zero
    private var dragStartOrigin: CGPoint = .zero
    private var lastDragMouse: CGPoint = .zero
    private var lastDragTime: TimeInterval = 0
    private var dragVelocity: CGPoint = .zero
    private var isDraggingWindow: Bool = false

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }

    public override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            let loc = event.locationInWindow
            // Click on Moko's body / dock area
            if loc.y < 165 && loc.x > 18 && loc.x < frame.width - 18 {
                isDraggingWindow = true
                dragStartMouse = NSEvent.mouseLocation
                dragStartOrigin = frame.origin
                lastDragMouse = dragStartMouse
                lastDragTime = ProcessInfo.processInfo.systemUptime
                dragVelocity = .zero
                CompanionCapyController.shared.isDangling = true
                CompanionCapyController.shared.stopCurrentWalk()
                return
            }
            super.sendEvent(event)

        case .leftMouseDragged:
            if isDraggingWindow {
                let cur = NSEvent.mouseLocation
                let now = ProcessInfo.processInfo.systemUptime
                let dt = now - lastDragTime
                if dt > 0.005 {
                    let vx = (cur.x - lastDragMouse.x) / CGFloat(dt)
                    let vy = (cur.y - lastDragMouse.y) / CGFloat(dt)
                    dragVelocity = CGPoint(x: dragVelocity.x * 0.4 + vx * 0.6, y: dragVelocity.y * 0.4 + vy * 0.6)
                    lastDragMouse = cur
                    lastDragTime = now
                }
                let rawOrigin = CGPoint(
                    x: dragStartOrigin.x + (cur.x - dragStartMouse.x),
                    y: dragStartOrigin.y + (cur.y - dragStartMouse.y)
                )
                let allScreens = NSScreen.screens
                let minX = (allScreens.map { $0.frame.minX }.min() ?? 0) - frame.width + 48
                let maxX = (allScreens.map { $0.frame.maxX }.max() ?? 1920) - 48
                let minY = (allScreens.map { $0.frame.minY }.min() ?? 0) - frame.height + 48
                let maxY = (allScreens.map { $0.frame.maxY }.max() ?? 1080)
                let clampedOrigin = CGPoint(
                    x: max(minX, min(maxX, rawOrigin.x)),
                    y: max(minY, min(maxY, rawOrigin.y))
                )
                setFrameOrigin(clampedOrigin)
                return
            }
            super.sendEvent(event)

        case .leftMouseUp:
            if isDraggingWindow {
                isDraggingWindow = false
                CompanionCapyController.shared.isDangling = false
                let cur = NSEvent.mouseLocation

                // Check notch return on the screen that actually has the Notch!
                let notchScreen = IslandController.shared.panel?.screen ?? NSScreen.screens.first!
                if notchScreen.frame.contains(cur),
                   cur.y >= notchScreen.frame.maxY - 58,
                   abs(cur.x - notchScreen.frame.midX) < 200 {
                    CompanionCapyController.shared.showBubble("moko masuk notch dulu ya~", duration: 2.0)
                    CapybaraService.shared.returnToNotch()
                    return
                }

                let dropScreen = NSScreen.screens.first(where: { $0.frame.contains(cur) })
                    ?? NSScreen.screens.first(where: { $0.frame.intersects(frame) })
                    ?? screen ?? NSScreen.main ?? NSScreen.screens.first!
                let vf = dropScreen.visibleFrame
                let safeX = max(vf.minX + 4, min(vf.maxX - frame.width - 4, frame.origin.x))
                let safeY = max(vf.minY + 4, min(vf.maxY - frame.height - 4, frame.origin.y))
                setFrameOrigin(CGPoint(x: safeX, y: safeY))

                CompanionCapyController.shared.companionOrigin = CGPoint(x: safeX, y: safeY)
                CompanionCapyController.shared.registerSquish()
                CompanionCapyController.shared.showBubble("moko duduk sini ya~", duration: 2.0)
                CompanionCapyController.shared.checkProximityWithMaki()
                return
            } else {
                CompanionCapyController.shared.pet()
                return
            }

        case .rightMouseDown:
            if let cv = self.contentView {
                CompanionCapyController.shared.presentContextMenu(with: event, in: cv)
            }
            return

        default:
            super.sendEvent(event)
        }
    }
}

// MARK: - Companion View
struct CompanionCapyRootView: View {
    @ObservedObject var companion = CompanionCapyController.shared
    @ObservedObject var capy = CapybaraService.shared

    var body: some View {
        VStack(spacing: 2) {
            // Speech Bubble
            ZStack(alignment: .bottom) {
                if let msg = companion.speechBubble {
                    CapySpeechBubbleView(
                        text: msg,
                        tail: .bottom,
                        fontSize: 10.5,
                        maxBubbleWidth: 196
                    )
                    .transition(.scale(scale: 0.86, anchor: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: 248, height: 46, alignment: .bottom)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: companion.speechBubble)
            .zIndex(10)

            // 2D Vector Moko (Friendly companion with embroidered "moko" shirt!)
            ZStack {
                Capybara2DView(
                    role: .habitat,
                    action: companion.action,
                    orangesOnHead: companion.orangesOnHead,
                    isOnsen: companion.isOnsen,
                    isListeningMusic: MusicService.shared.currentTrack.isPlaying,
                    isFocusing: TimerService.shared.isRunning,
                    isDangling: companion.isDangling,
                    isMouthOpenForDrop: false,
                    lookVector: companion.lookVector,
                    lastSquishTime: companion.lastSquishTime,
                    facingRight: companion.facingRight,
                    mascotModel: .plushie,
                    nameBadge: "moko"
                )
                .frame(width: 122, height: 114)
            }

            // Quick Interaction Dock for Moko
            HStack(spacing: 4) {
                companionDockBtn("💬", help: "Ajak Ngobrol Maki") {
                    companion.triggerBanterWithMaki()
                }
                companionDockBtn("🍊", help: "Lempar Jeruk ke Maki") {
                    companion.tossOrangeToMaki()
                }
                companionDockBtn("♨️", active: companion.isOnsen, help: companion.isOnsen ? "Selesai Berendam" : "Berendam Onsen Bersama") {
                    companion.toggleOnsen()
                }
                companionDockBtn(companion.desktopRoamEnabled ? "🚶" : "📌", active: !companion.desktopRoamEnabled, help: companion.desktopRoamEnabled ? "Kunci Posisi Moko" : "Bebas Jalan-Jalan") {
                    companion.desktopRoamEnabled.toggle()
                    if companion.desktopRoamEnabled {
                        companion.showBubble("moko mau jalan-jalan!", duration: 2.0)
                        companion.startAutonomousStroll()
                    } else {
                        companion.stopCurrentWalk()
                        companion.showBubble("moko diam di sini ya", duration: 2.0)
                    }
                }
                companionDockBtn("🐾", help: "Tos dengan Maki!") {
                    companion.triggerHighFive()
                }
                companionDockBtn("🏠", help: "Jalan Pulang ke Notch bersama Maki") {
                    CapybaraService.shared.returnToNotch()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(Color(red: 1.0, green: 0.985, blue: 0.95).opacity(0.95))
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
            )
            .overlay(
                Capsule()
                    .stroke(Color(red: 0.23, green: 0.13, blue: 0.06).opacity(0.24), lineWidth: 1.0)
            )
            .scaleEffect(companion.isHovering ? 1.0 : 0.88)
            .opacity(companion.isHovering ? 1.0 : 0.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: companion.isHovering)
        }
        .frame(width: 264, height: 194)
        .contentShape(Rectangle())
        .onHover { h in
            companion.isHovering = h
        }
    }

    private func companionDockBtn(_ icon: String, active: Bool = false, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(icon)
                .font(.system(size: 11.5))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(active ? Color(red: 1.0, green: 0.86, blue: 0.68) : Color.white.opacity(0.6))
                )
                .overlay(
                    Circle()
                        .stroke(active ? Color(red: 0.88, green: 0.42, blue: 0.14) : Color.clear, lineWidth: 1.2)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Companion Controller
public class CompanionCapyController: NSObject, ObservableObject {
    public static let shared = CompanionCapyController()

    public var panel: CompanionCapyPanel?
    public let panelSize = CGSize(width: 264, height: 194)

    @Published public var action: CapyAction = .chill
    @Published public var orangesOnHead: Int = 1
    @Published public var isOnsen: Bool = false
    @Published public var facingRight: Bool = false
    @Published public var speechBubble: String? = nil
    @Published public var isDangling: Bool = false
    @Published public var isHovering: Bool = false
    @Published public var desktopRoamEnabled: Bool = true
    @Published public var companionOrigin: CGPoint = .zero
    @Published public var lastSquishTime: TimeInterval = 0
    @Published public var lookVector: CGPoint = .zero

    public var interactiveScreenRect: NSRect? {
        guard let panel = panel, panel.isVisible else { return nil }
        let f = panel.frame
        return NSRect(x: f.midX - 110, y: f.minY, width: 220, height: 150)
    }

    private var bubbleDismissTimer: Timer?
    private var banterTimer: Timer?
    private var motionTimer: Timer?
    private var strollTimer: Timer?
    private var walkTarget: CGPoint?
    private var currentDialogueIndex = 0

    private let dialogues: [(maki: String, moko: String)] = [
        ("Moko, monitor sebelah adem ya?", "Iya Maki, adem dan lega banget di sini! ✨"),
        ("Maki, bagi satu jeruk dong! 🍊", "Nih tangkap! 🍊💨"),
        ("Semangat ya nemenin bos kerja! 💻", "Pasti! Jangan lupa istirahat mata ya! 👀"),
        ("Moko, jangan ketiduran ya!", "Gak kok, aku cuma merem merem ayam hehe 💤"),
        ("Enaknya nanti kita berendam onsen bareng ya ♨️", "Setuju! Air hangat sama jeruk rebus mantap!"),
        ("Layar kamu ada file apa aja tuh?", "Banyak kerjaan beres, bos kita rajin banget! 👍")
    ]

    private override init() {
        super.init()
    }

    public func showBubble(_ text: String, duration: TimeInterval = 3.5) {
        bubbleDismissTimer?.invalidate()
        speechBubble = text
        bubbleDismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.speechBubble = nil
        }
    }

    public func registerSquish() {
        lastSquishTime = ProcessInfo.processInfo.systemUptime
    }

    public func pet() {
        registerSquish()
        let quips = [
            "Moko senang dielus! ✨",
            "Hehe geli kak~",
            "Moko teman setia Maki!",
            "Semangat kerjanya ya bos!"
        ]
        showBubble(quips.randomElement() ?? "Hehe makasih!", duration: 2.5)
    }

    public func toggleOnsen() {
        isOnsen.toggle()
        registerSquish()
        if isOnsen {
            showBubble("Wah segernya air hangat onsen~ ♨️", duration: 2.8)
        } else {
            showBubble("Selesai berendam, badan enteng!", duration: 2.2)
        }
    }

    public func triggerBanterWithMaki() {
        let pair = dialogues[currentDialogueIndex % dialogues.count]
        currentDialogueIndex += 1

        let maki = CapybaraService.shared
        maki.showDesktopBubble(pair.maki, duration: 3.5)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.panel != nil else { return }
            self.showBubble(pair.moko, duration: 3.8)
            self.registerSquish()
        }
    }

    public func tossOrangeToMaki() {
        showBubble("Maki, tangkap jeruk ini! 🍊💨", duration: 2.5)
        facingRight = (companionOrigin.x < CapybaraService.shared.desktopOrigin.x)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let maki = CapybaraService.shared
            maki.registerSquish()
            maki.orangesOnHead = min(3, maki.orangesOnHead + 1)
            maki.showDesktopBubble("Hup! Ketangkap! Seger banget, makasih Moko! 😋", duration: 3.0)
        }
    }

    public func checkProximityWithMaki() {
        guard let p = panel, let makiPanel = DesktopCapyController.shared.panel else { return }
        if p.screen == makiPanel.screen {
            let dist = hypot(p.frame.midX - makiPanel.frame.midX, p.frame.midY - makiPanel.frame.midY)
            if dist < 140 {
                triggerHighFive()
            }
        }
    }

    public func triggerHighFive() {
        registerSquish()
        CapybaraService.shared.registerSquish()
        showBubble("🐾 High-Five Maki! Sahabat selamanya! ❤️", duration: 3.2)
        CapybaraService.shared.showDesktopBubble("🐾 Tos Moko! Asik banget kumpul bareng!", duration: 3.2)
    }

    public func syncWithScreens() {
        let screens = NSScreen.screens
        let isOnDesktop = CapybaraService.shared.isOnDesktop

        if screens.count >= 2 && isOnDesktop {
            if panel == nil {
                // Spawn Moko on the extended screen!
                let primary = NSScreen.main ?? screens.first!
                let extScreen = screens.first(where: { $0 != primary }) ?? screens[1]
                let vf = extScreen.visibleFrame
                let spawnX = round(vf.midX - panelSize.width / 2)
                let spawnY = round(vf.minY + 28)
                let initialOrigin = CGPoint(x: spawnX, y: spawnY)
                self.companionOrigin = initialOrigin

                let p = CompanionCapyPanel(contentRect: NSRect(origin: initialOrigin, size: panelSize))
                MainActor.assumeIsolated {
                    let hosting = NSHostingView(rootView: CompanionCapyRootView())
                    hosting.frame = NSRect(origin: .zero, size: panelSize)
                    hosting.autoresizingMask = [.width, .height]
                    hosting.wantsLayer = true
                    hosting.layer?.backgroundColor = CGColor(gray: 0, alpha: 0)
                    p.contentView = hosting
                }
                p.orderFrontRegardless()
                self.panel = p

                // Spawn greeting!
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    self?.showBubble("👋 Halo Maki! Aku nemenin di monitor sebelah ya!", duration: 3.5)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        CapybaraService.shared.showDesktopBubble("🍊 Asik! Selamat datang Moko, santai bareng ya!", duration: 3.5)
                    }
                }

                startBanterTimer()
                startAutonomousStroll()
            }
        } else {
            if panel != nil {
                stopBanterTimer()
                stopCurrentWalk()
                showBubble("Dadaah Maki, sampai ketemu lagi ya! 👋", duration: 1.5)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                    self?.panel?.orderOut(nil)
                    self?.panel = nil
                }
            }
        }
    }

    private func startBanterTimer() {
        stopBanterTimer()
        banterTimer = Timer.scheduledTimer(withTimeInterval: 55.0, repeats: true) { [weak self] _ in
            guard let self = self, self.panel != nil else { return }
            if self.speechBubble == nil && CapybaraService.shared.desktopBubble == nil {
                self.triggerBanterWithMaki()
            }
        }
    }

    private func stopBanterTimer() {
        banterTimer?.invalidate()
        banterTimer = nil
    }

    public func stopCurrentWalk() {
        walkTarget = nil
        motionTimer?.invalidate()
        motionTimer = nil
        if action == .walking {
            action = .chill
        }
    }

    public func startAutonomousStroll() {
        strollTimer?.invalidate()
        strollTimer = Timer.scheduledTimer(withTimeInterval: 28.0, repeats: true) { [weak self] _ in
            guard let self = self, self.panel != nil, self.desktopRoamEnabled, !self.isDangling, !self.isOnsen else { return }
            self.chooseRandomStrollTarget()
        }
    }

    private func chooseRandomStrollTarget() {
        guard let p = panel, let sc = p.screen ?? NSScreen.screens.last else { return }
        let vf = sc.visibleFrame
        let targetX = CGFloat.random(in: (vf.minX + 20)...(vf.maxX - panelSize.width - 20))
        let targetY = min(vf.maxY - panelSize.height - 20, max(vf.minY + 20, p.frame.origin.y + CGFloat.random(in: -30...30)))
        walkTo(CGPoint(x: targetX, y: targetY))
    }

    public func walkTo(_ target: CGPoint) {
        guard let p = panel else { return }
        walkTarget = target
        action = .walking
        facingRight = target.x > p.frame.origin.x

        motionTimer?.invalidate()
        motionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] t in
            self?.stepMotion(timer: t)
        }
    }

    private func stepMotion(timer: Timer) {
        guard let p = panel, let target = walkTarget else {
            stopCurrentWalk()
            return
        }
        let cur = p.frame.origin
        let dx = target.x - cur.x
        let dy = target.y - cur.y
        let dist = hypot(dx, dy)
        let step: CGFloat = 2.4

        if dist <= step {
            p.setFrameOrigin(target)
            companionOrigin = target
            stopCurrentWalk()
            checkProximityWithMaki()
        } else {
            let nextOrigin = CGPoint(x: cur.x + (dx / dist) * step, y: cur.y + (dy / dist) * step)
            p.setFrameOrigin(nextOrigin)
            companionOrigin = nextOrigin
        }
    }

    public func presentContextMenu(with event: NSEvent, in view: NSView) {
        let menu = NSMenu(title: "Moko Companion")
        let itemChat = NSMenuItem(title: "💬 Ajak Ngobrol Maki", action: #selector(menuBanter), keyEquivalent: "")
        itemChat.target = self
        menu.addItem(itemChat)

        let itemOrange = NSMenuItem(title: "🍊 Lempar Jeruk ke Maki", action: #selector(menuOrange), keyEquivalent: "")
        itemOrange.target = self
        menu.addItem(itemOrange)

        let itemOnsen = NSMenuItem(title: isOnsen ? "♨️ Selesai Berendam Onsen" : "♨️ Berendam Onsen", action: #selector(menuOnsen), keyEquivalent: "")
        itemOnsen.target = self
        menu.addItem(itemOnsen)

        let itemHighFive = NSMenuItem(title: "🐾 Tos / High-Five dengan Maki", action: #selector(menuHighFive), keyEquivalent: "")
        itemHighFive.target = self
        menu.addItem(itemHighFive)

        menu.addItem(NSMenuItem.separator())
        let itemReturn = NSMenuItem(title: "🏠 Pulang ke Notch bersama Maki", action: #selector(menuReturnHome), keyEquivalent: "")
        itemReturn.target = self
        menu.addItem(itemReturn)

        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    @objc private func menuBanter() { triggerBanterWithMaki() }
    @objc private func menuOrange() { tossOrangeToMaki() }
    @objc private func menuOnsen() { toggleOnsen() }
    @objc private func menuHighFive() { triggerHighFive() }
    @objc private func menuReturnHome() { CapybaraService.shared.returnToNotch() }

    public func walkHomeToNotch() {
        guard let p = panel, p.isVisible else { return }
        stopBanterTimer()
        stopCurrentWalk()
        strollTimer?.invalidate()
        strollTimer = nil

        let sc = IslandController.shared.panel?.screen ?? NSScreen.screens.first!
        let doorstepX = round(sc.frame.midX - panelSize.width * 0.5) + 32
        let notchHeight: CGFloat = IslandState.shared.isExpanded ? IslandState.shared.expandedTargetSize.height : 32
        let notchBottomY = sc.frame.maxY - notchHeight
        let doorstepY = notchBottomY - 118
        let insideNotchY = sc.frame.maxY - 68

        let cur = p.frame.origin
        showBubble("Tungguin aku Maki, ikut masuk! 🏃", duration: 2.2)
        action = .walking
        facingRight = (doorstepX >= cur.x)

        let totalDist = hypot(doorstepX - cur.x, doorstepY - cur.y)
        let speed = max(320.0, min(700.0, totalDist / 1.15))
        var logicalOrigin = cur

        motionTimer?.invalidate()
        let dt: CGFloat = 1.0 / 60.0
        motionTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(dt), repeats: true) { [weak self] t in
            guard let self = self, let cp = self.panel else {
                t.invalidate()
                return
            }
            let dx = doorstepX - logicalOrigin.x
            let dy = doorstepY - logicalOrigin.y
            let dist = hypot(dx, dy)

            if dist < 6.0 {
                t.invalidate()
                cp.setFrameOrigin(CGPoint(x: doorstepX, y: doorstepY))
                self.action = .walking

                var climbProg: CGFloat = 0
                self.motionTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(dt), repeats: true) { [weak self] ct in
                    guard let self = self, let panelToHide = self.panel else {
                        ct.invalidate()
                        return
                    }
                    climbProg += dt / 0.36
                    let ease = climbProg * climbProg * (3.0 - 2.0 * climbProg)
                    let curY = doorstepY + (insideNotchY - doorstepY) * ease
                    panelToHide.setFrameOrigin(CGPoint(x: doorstepX, y: curY))
                    panelToHide.alphaValue = max(0.0, 1.0 - max(0, (climbProg - 0.58) / 0.42))

                    if climbProg >= 1.0 {
                        ct.invalidate()
                        self.motionTimer = nil
                        panelToHide.orderOut(nil)
                        self.panel = nil
                        self.action = .chill
                    }
                }
                return
            }

            let step = min(dist, speed * dt)
            logicalOrigin.x += (dx / dist) * step
            logicalOrigin.y += (dy / dist) * step
            self.facingRight = dx >= 0
            cp.setFrameOrigin(logicalOrigin)
        }
    }

    public func dismissImmediately() {
        stopBanterTimer()
        stopCurrentWalk()
        strollTimer?.invalidate()
        strollTimer = nil
        motionTimer?.invalidate()
        motionTimer = nil
        panel?.orderOut(nil)
        panel = nil
        action = .chill
    }
}
