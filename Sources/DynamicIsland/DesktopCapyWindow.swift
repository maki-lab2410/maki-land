import Cocoa
import SwiftUI
import UniformTypeIdentifiers

public class DesktopCapyPanel: NSPanel {
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

        // Accept macOS floating corner screenshots (NSFilePromiseReceiver), images, PDFs & Finder files natively!
        registerForDraggedTypes(DropZoneService.supportedDraggedTypes)
    }

    public override var canBecomeKey: Bool {
        GeminiService.shared.isDesktopChatOpen
    }
    public override var canBecomeMain: Bool { false }

    /// Allow Maki's panel to climb past the macOS Menu Bar ceiling right into the physical Notch!
    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard GeminiService.shared.isDesktopChatOpen else {
            return super.performKeyEquivalent(with: event)
        }

        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.numericPad, .function])
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        if event.keyCode == 53 && flags.isEmpty {
            if GeminiService.shared.isShowingSettings {
                GeminiService.shared.isShowingSettings = false
            } else {
                GeminiService.shared.isDesktopChatOpen = false
            }
            return true
        }

        if flags == [.command, .shift], key == "z" {
            if let um = firstResponder?.undoManager, um.canRedo {
                um.redo()
                return true
            }
            return NSApp.sendAction(Selector(("redo:")), to: nil, from: self)
        }

        if flags == .command {
            switch key {
            case "a":
                return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
            case "c":
                return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
            case "v":
                let pb = NSPasteboard.general
                if pb.string(forType: .string) == nil, let img = NSImage(pasteboard: pb), img.size.width > 4 {
                    _ = GeminiService.shared.attachNSImage(img, name: "Clipboard Image")
                    return true
                }
                return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
            case "x":
                return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
            case "z":
                if let um = firstResponder?.undoManager, um.canUndo {
                    um.undo()
                    return true
                }
                return NSApp.sendAction(Selector(("undo:")), to: nil, from: self)
            default:
                break
            }
        }

        return super.performKeyEquivalent(with: event)
    }

    // MARK: - Native AppKit Drag & Drop (Supports macOS ⌘⇧3 / ⌘⇧4 Floating Screenshot Thumbnails!)

    @objc public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        DesktopCapyController.shared.holdForDrop(seconds: 4.0)
        DispatchQueue.main.async {
            CapybaraService.shared.isMouthOpenForDrop = true
        }
        return .copy
    }

    @objc public func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        DesktopCapyController.shared.holdForDrop(seconds: 1.0)
        if !CapybaraService.shared.isMouthOpenForDrop {
            DispatchQueue.main.async {
                CapybaraService.shared.isMouthOpenForDrop = true
            }
        }
        return .copy
    }

    @objc public func draggingExited(_ sender: NSDraggingInfo?) {
        DesktopCapyController.shared.releaseDropHold(after: 0.6)
        DispatchQueue.main.async {
            CapybaraService.shared.isMouthOpenForDrop = false
        }
    }

    @objc public func draggingEnded(_ sender: NSDraggingInfo) {
        DesktopCapyController.shared.releaseDropHold(after: 0.6)
        DispatchQueue.main.async {
            CapybaraService.shared.isMouthOpenForDrop = false
        }
    }

    @objc public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        DesktopCapyController.shared.holdForDrop(seconds: 4.0)
        DispatchQueue.main.async {
            CapybaraService.shared.isMouthOpenForDrop = false
        }
        // If user drops an image onto Maki while Desktop AI Chat is open, attach it straight to Gemini Q&A!
        DropZoneService.shared.extractURLsFromDraggingInfo(sender) { urls in
            guard !urls.isEmpty else { return }
            if GeminiService.shared.isDesktopChatOpen,
               let first = urls.first,
               GeminiService.shared.attachImage(from: first) {
                CapybaraService.shared.registerSquish()
                return
            }
            CapybaraService.shared.completeSwallowIntoTray(urls: urls)
        }
        return true
    }

    // MARK: - Mouse, Drag, Bounce & Trackpad Fur Brushing

    public override func sendEvent(_ event: NSEvent) {
        // Keyboard events go straight to focused TextField when Desktop AI Chat is open
        if event.type == .keyDown || event.type == .keyUp || event.type == .flagsChanged {
            if event.type == .keyDown && event.keyCode == 53 && GeminiService.shared.isDesktopChatOpen {
                if GeminiService.shared.isShowingSettings {
                    GeminiService.shared.isShowingSettings = false
                } else {
                    GeminiService.shared.isDesktopChatOpen = false
                }
                return
            }
            super.sendEvent(event)
            return
        }

        // Let all mouse & scroll events inside the floating Desktop AI Chat Card (y > 144) go straight to SwiftUI!
        if GeminiService.shared.isDesktopChatOpen && !isDraggingWindow && event.locationInWindow.y > 144 {
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                if !NSApp.isActive {
                    NSApp.activate(ignoringOtherApps: true)
                }
                if !isKeyWindow {
                    makeKey()
                }
            }
            super.sendEvent(event)
            return
        }

        // Let clicks on the bottom Hover Quick-Play Pill Bar (y < 34) go straight to SwiftUI Buttons!
        if (event.type == .leftMouseDown || event.type == .leftMouseUp) && event.locationInWindow.y < 34 && !isDraggingWindow {
            super.sendEvent(event)
            return
        }

        switch event.type {
        case .scrollWheel:
            let delta = hypot(event.scrollingDeltaX, event.scrollingDeltaY)
            CapybaraService.shared.strokeFur(delta: delta)
            return

        case .leftMouseDown:
            if CapybaraService.shared.isReturningToNotch {
                DesktopCapyController.shared.cancelWalkHomeToNotch()
            }
            DesktopCapyController.shared.stopCurrentWalk()
            dragStartMouse = NSEvent.mouseLocation
            lastDragMouse = dragStartMouse
            lastDragTime = ProcessInfo.processInfo.systemUptime
            dragVelocity = .zero
            dragStartOrigin = frame.origin
            isDraggingWindow = false
            super.sendEvent(event)

        case .leftMouseDragged:
            let cur = NSEvent.mouseLocation
            let now = ProcessInfo.processInfo.systemUptime
            let dt = max(0.004, now - lastDragTime)
            dragVelocity = CGPoint(
                x: (cur.x - lastDragMouse.x) / CGFloat(dt),
                y: (cur.y - lastDragMouse.y) / CGFloat(dt)
            )
            lastDragMouse = cur
            lastDragTime = now

            let dx = cur.x - dragStartMouse.x
            let dy = cur.y - dragStartMouse.y
            if !isDraggingWindow && hypot(dx, dy) > 4.0 {
                isDraggingWindow = true
                CapybaraService.shared.isDraggingOnDesktop = true
                CapybaraService.shared.isChasingCursor = false
                CapybaraService.shared.showDesktopBubble("eh mau dibawa kemana..", duration: 2.0)
            }
            if isDraggingWindow {
                let rawOrigin = CGPoint(x: dragStartOrigin.x + dx, y: dragStartOrigin.y + dy)
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
                CapybaraService.shared.isDraggingOnDesktop = false
                let cur = NSEvent.mouseLocation

                // Check notch return only on the screen that actually has the Notch!
                let notchScreen = IslandController.shared.panel?.screen ?? NSScreen.screens.first!
                if notchScreen.frame.contains(cur),
                   cur.y >= notchScreen.frame.maxY - 58,
                   abs(cur.x - notchScreen.frame.midX) < 200 {
                    CapybaraService.shared.returnToNotch()
                    return
                }

                let speed = hypot(dragVelocity.x, dragVelocity.y)
                if speed > 180 {
                    DesktopCapyController.shared.applyThrowVelocity(dragVelocity)
                } else {
                    // Snap securely inside the visible area of whichever screen Maki was dropped on
                    let dropScreen = NSScreen.screens.first(where: { $0.frame.contains(cur) })
                        ?? NSScreen.screens.first(where: { $0.frame.intersects(frame) })
                        ?? screen ?? NSScreen.main ?? NSScreen.screens.first!
                    let vf = dropScreen.visibleFrame
                    let safeX = max(vf.minX + 4, min(vf.maxX - frame.width - 4, frame.origin.x))
                    let safeY = max(vf.minY + 4, min(vf.maxY - frame.height - 4, frame.origin.y))
                    setFrameOrigin(CGPoint(x: safeX, y: safeY))

                    CapybaraService.shared.desktopOrigin = CGPoint(x: safeX, y: safeY)
                    CapybaraService.shared.registerSquish()
                    CapybaraService.shared.showDesktopBubble("sip, duduk sini aja", duration: 2.0)
                    CompanionCapyController.shared.checkProximityWithMaki()
                }
                return
            } else {
                if event.clickCount >= 2 {
                    CapybaraService.shared.triggerRandomFunActivity()
                } else {
                    CapybaraService.shared.pet(fromDesktop: true)
                }
                return
            }

        case .rightMouseDown:
            DesktopCapyController.shared.presentContextMenu(with: event, in: self)
            return

        default:
            super.sendEvent(event)
        }
    }
}

class DesktopCapyHostingView: NSHostingView<DesktopCapyRootView> {
    @MainActor required init(rootView: DesktopCapyRootView) {
        super.init(rootView: rootView)
        registerForDraggedTypes(DropZoneService.supportedDraggedTypes)
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(DropZoneService.supportedDraggedTypes)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        DesktopCapyController.shared.holdForDrop(seconds: 4.0)
        DispatchQueue.main.async {
            CapybaraService.shared.isMouthOpenForDrop = true
        }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        DesktopCapyController.shared.holdForDrop(seconds: 1.0)
        if !CapybaraService.shared.isMouthOpenForDrop {
            DispatchQueue.main.async {
                CapybaraService.shared.isMouthOpenForDrop = true
            }
        }
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        DesktopCapyController.shared.releaseDropHold(after: 0.6)
        DispatchQueue.main.async {
            CapybaraService.shared.isMouthOpenForDrop = false
        }
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        DesktopCapyController.shared.releaseDropHold(after: 0.6)
        DispatchQueue.main.async {
            CapybaraService.shared.isMouthOpenForDrop = false
        }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        DesktopCapyController.shared.holdForDrop(seconds: 4.0)
        DispatchQueue.main.async {
            CapybaraService.shared.isMouthOpenForDrop = false
        }
        DropZoneService.shared.extractURLsFromDraggingInfo(sender) { urls in
            guard !urls.isEmpty else { return }
            if GeminiService.shared.isDesktopChatOpen,
               let first = urls.first,
               GeminiService.shared.attachImage(from: first) {
                CapybaraService.shared.registerSquish()
                return
            }
            CapybaraService.shared.completeSwallowIntoTray(urls: urls)
        }
        return true
    }
}

public class DesktopCapyController: NSObject {
    public static let shared = DesktopCapyController()

    public var panel: DesktopCapyPanel?
    public let normalPanelSize = CGSize(width: 264, height: 194)
    public let chatPanelSize   = CGSize(width: 336, height: 376)
    public var panelSize: CGSize {
        GeminiService.shared.isDesktopChatOpen ? chatPanelSize : normalPanelSize
    }
    public var isHoveringDesktopPet: Bool = false

    /// Screen rect where Maki actually grabs the mouse (body + dock, or whole panel while the chat card is open).
    public var interactiveScreenRect: NSRect? {
        guard let panel = panel, panel.isVisible else { return nil }
        let f = panel.frame
        if GeminiService.shared.isDesktopChatOpen { return f }
        return NSRect(x: f.midX - 110, y: f.minY, width: 220, height: 150)
    }

    private enum HomeReturnPhase {
        case none
        case walkingToDoorstep(doorstep: CGPoint, insideNotchY: CGFloat)
        case climbingIntoNotch(doorstep: CGPoint, insideNotchY: CGFloat, progress: CGFloat)
    }

    private var motionTimer: Timer?
    private var walkTarget: CGPoint? = nil
    private var homePhase: HomeReturnPhase = .none
    private var homeLogicalOrigin: CGPoint = .zero
    private var homeWalkSpeed: CGFloat = 340.0
    private var throwVel: CGPoint = .zero

    public var isCurrentlyWalking: Bool {
        if walkTarget != nil { return true }
        if case .none = homePhase { return false }
        return true
    }

    private override init() { super.init() }

    /// Maki must stay perfectly still while a file/screenshot is being dragged over him (and right after the drop),
    /// otherwise he wanders off from the drop point.
    private var dropHoldUntil: Date = .distantPast

    public var isHeldForDrop: Bool {
        CapybaraService.shared.isMouthOpenForDrop || Date() < dropHoldUntil
    }

    public func holdForDrop(seconds: TimeInterval = 3.0) {
        let until = Date().addingTimeInterval(seconds)
        if until > dropHoldUntil { dropHoldUntil = until }
        walkTarget = nil
        throwVel = .zero
        let capy = CapybaraService.shared
        if capy.isChasingCursor { capy.isChasingCursor = false }
        if case .none = homePhase, capy.currentAction == .walking {
            capy.currentAction = .chill
        }
    }

    public func releaseDropHold(after seconds: TimeInterval = 1.5) {
        dropHoldUntil = Date().addingTimeInterval(seconds)
    }

    public func restoreIfNeeded() {
        if CapybaraService.shared.isOnDesktop {
            show(at: CapybaraService.shared.desktopOrigin)
        }
    }

    public func show(at origin: CGPoint) {
        let curSize = panelSize
        if panel == nil {
            let rect = NSRect(origin: origin, size: curSize)
            let p = DesktopCapyPanel(contentRect: rect)
            MainActor.assumeIsolated {
                let hosting = DesktopCapyHostingView(rootView: DesktopCapyRootView())
                hosting.sizingOptions = []
                hosting.frame = NSRect(origin: .zero, size: curSize)
                hosting.autoresizingMask = [.width, .height]
                hosting.wantsLayer = true
                hosting.layer?.backgroundColor = CGColor(gray: 0, alpha: 0)
                hosting.layer?.isOpaque = false
                p.contentView = hosting
            }
            panel = p
        }

        homePhase = .none
        panel?.level = .statusBar
        panel?.alphaValue = 1.0
        let sc = NSScreen.screens.first(where: { $0.frame.contains(origin) })
            ?? NSScreen.main ?? NSScreen.screens.first!
        let clampedX = max(sc.visibleFrame.minX + 4, min(sc.visibleFrame.maxX - curSize.width - 4, origin.x))
        let clampedY = max(sc.visibleFrame.minY + 4, min(sc.visibleFrame.maxY - curSize.height - 6, origin.y))
        panel?.setFrame(NSRect(origin: CGPoint(x: clampedX, y: clampedY), size: curSize), display: true)
        panel?.orderFrontRegardless()
        startMotionLoopIfNeeded()
        startPassthroughTimerIfNeeded()
        CompanionCapyController.shared.syncWithScreens()
    }

    // MARK: - Precise Hit Area (only Maki's body grabs the mouse; the transparent rest passes clicks/drags to apps below!)

    private var passthroughTimer: Timer?

    private func startPassthroughTimerIfNeeded() {
        guard passthroughTimer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.updatePanelPassthrough()
        }
        RunLoop.main.add(t, forMode: .common)
        passthroughTimer = t
    }

    private func updatePanelPassthrough() {
        guard let panel = panel, panel.isVisible else { return }
        let capy = CapybaraService.shared
        let mouse = NSEvent.mouseLocation
        let f = panel.frame
        let leftHeld = (NSEvent.pressedMouseButtons & 1) != 0

        var accept: Bool
        var inside: Bool

        var walkingHome = false
        if case .none = homePhase {} else { walkingHome = true }

        if GeminiService.shared.isDesktopChatOpen {
            // Chat card needs the whole panel
            accept = true
            inside = f.contains(mouse)
        } else if capy.isDraggingOnDesktop || walkingHome {
            // Never lose Maki while he's being carried or walking home
            accept = true
            inside = true
        } else {
            // Maki's body (122x114 above the dock) + the quick dock pill when it is visible
            let body = NSRect(x: f.midX - 62, y: f.minY + 4, width: 124, height: 146)
            let dock = NSRect(x: f.midX - 110, y: f.minY, width: 220, height: 30)
            inside = body.contains(mouse) || (capy.desktopPointerInside && dock.contains(mouse))
            accept = inside

            // Mouse button held & we are already grabbing it (e.g. dragging Maki around fast): never let go mid-gesture
            if leftHeld && !panel.ignoresMouseEvents { accept = true }
        }

        if panel.ignoresMouseEvents == accept {
            panel.ignoresMouseEvents = !accept
        }
        if capy.desktopPointerInside != inside {
            capy.desktopPointerInside = inside
        }
        if isHoveringDesktopPet != inside {
            isHoveringDesktopPet = inside
        }
    }

    public func handleDesktopChatVisibilityChanged(_ isOpen: Bool) {
        guard let panel = panel, panel.isVisible else { return }
        stopCurrentWalk()

        let oldFrame = panel.frame
        let targetSize = isOpen ? chatPanelSize : normalPanelSize
        let sc = panel.screen ?? NSScreen.screens.first(where: { $0.frame.intersects(oldFrame) }) ?? NSScreen.main ?? NSScreen.screens.first!
        let vf = sc.visibleFrame

        var nextX = round(oldFrame.midX - targetSize.width * 0.5)
        var nextY = oldFrame.minY

        nextX = max(vf.minX + 4, min(vf.maxX - targetSize.width - 4, nextX))
        nextY = max(vf.minY + 4, min(vf.maxY - targetSize.height - 6, nextY))

        panel.setFrame(
            NSRect(origin: CGPoint(x: nextX, y: nextY), size: targetSize),
            display: true,
            animate: false
        )

        if isOpen {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
    }

    public func hide() {
        if GeminiService.shared.isDesktopChatOpen {
            GeminiService.shared.isDesktopChatOpen = false
        }
        homePhase = .none
        stopCurrentWalk()
        motionTimer?.invalidate()
        motionTimer = nil
        passthroughTimer?.invalidate()
        passthroughTimer = nil
        CapybaraService.shared.desktopPointerInside = false
        panel?.level = .statusBar
        panel?.alphaValue = 1.0
        panel?.orderOut(nil)
        CompanionCapyController.shared.syncWithScreens()
    }

    public func stopCurrentWalk() {
        walkTarget = nil
        throwVel = .zero
        if case .none = homePhase,
           CapybaraService.shared.currentAction == .walking,
           !CapybaraService.shared.isChasingCursor {
            CapybaraService.shared.currentAction = .chill
        }
    }

    /// Walks Maki smoothly from his current Desktop position up to the Notch lip, then hops & climbs right INSIDE the Notch!
    public func walkHomeToNotch() {
        if GeminiService.shared.isDesktopChatOpen {
            GeminiService.shared.isDesktopChatOpen = false
        }
        guard let panel = panel, panel.isVisible else {
            CapybaraService.shared.completeReturnToNotchArrival()
            return
        }
        walkTarget = nil
        throwVel = .zero
        panel.alphaValue = 1.0

        // Place Maki above the macOS Menu Bar and immediately behind the black Notch (`IslandPanel`) so he climbs right INSIDE it!
        panel.level = .statusBar
        if let islandWin = IslandController.shared.panel {
            panel.order(.below, relativeTo: islandWin.windowNumber)
        }

        let sc = IslandController.shared.panel?.screen ?? NSScreen.screens.first!
        let doorstepX = round(sc.frame.midX - panelSize.width * 0.5)
        let notchHeight: CGFloat = IslandState.shared.isExpanded ? IslandState.shared.expandedTargetSize.height : 32
        let notchBottomY = sc.frame.maxY - notchHeight

        // Doorstep: Maki's head touches the bottom edge of the black Notch
        let doorstepY = notchBottomY - 118
        // Inside Notch: Maki's body climbs all the way up behind the black Notch silhouette
        let insideNotchY = sc.frame.maxY - 68

        let cur = panel.frame.origin
        homeLogicalOrigin = cur
        let totalDist = hypot(doorstepX - cur.x, doorstepY - cur.y)
        homeWalkSpeed = max(300.0, min(680.0, totalDist / 1.15))
        homePhase = .walkingToDoorstep(
            doorstep: CGPoint(x: doorstepX, y: doorstepY),
            insideNotchY: insideNotchY
        )

        CapybaraService.shared.notchClimbProgress = 0
        CapybaraService.shared.facingRight = (doorstepX >= cur.x)
        CapybaraService.shared.currentAction = .walking
        startMotionLoopIfNeeded()
    }

    public func cancelWalkHomeToNotch() {
        homePhase = .none
        panel?.level = .statusBar
        panel?.alphaValue = 1.0
        CapybaraService.shared.notchClimbProgress = 0
        CapybaraService.shared.isReturningToNotch = false
        if CapybaraService.shared.currentAction == .walking {
            CapybaraService.shared.currentAction = .chill
        }
    }

    public func applyThrowVelocity(_ vel: CGPoint) {
        let maxSpeed: CGFloat = 1100
        let vx = max(-maxSpeed, min(maxSpeed, vel.x * 0.55))
        let vy = max(-maxSpeed, min(maxSpeed, vel.y * 0.55))
        throwVel = CGPoint(x: vx, y: vy)
        CapybaraService.shared.showDesktopBubble("whoa meluncur..", duration: 1.8)
        startMotionLoopIfNeeded()
    }

    public func startAutonomousStroll() {
        guard let panel = panel, panel.isVisible, !isHoveringDesktopPet, !isHeldForDrop else { return }
        guard !GeminiService.shared.isDesktopChatOpen && !GeminiService.shared.isThinking else { return }
        if case .none = homePhase {} else { return }
        let sc = panel.screen ?? NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) }) ?? NSScreen.main ?? NSScreen.screens.first!
        let vf = sc.visibleFrame
        let cur = panel.frame.origin

        let alongDock = Int.random(in: 0..<3) != 0
        let nextX = CGFloat.random(in: (vf.minX + 12)...max(vf.minX + 16, vf.maxX - panelSize.width - 12))
        let nextY: CGFloat
        if alongDock {
            nextY = vf.minY + CGFloat.random(in: 6...46)
        } else {
            nextY = max(vf.minY + 10, min(vf.maxY - panelSize.height - 16, cur.y + CGFloat.random(in: -130...130)))
        }

        if hypot(nextX - cur.x, nextY - cur.y) < 45 { return }

        walkTarget = CGPoint(x: nextX, y: nextY)
        CapybaraService.shared.facingRight = (nextX >= cur.x)
        CapybaraService.shared.currentAction = .walking
        if Int.random(in: 0..<4) == 0 {
            let strollLines = [
                "jalan-jalan bentar..",
                "pindah duduk sebelah ah",
                "cari tempat adem.."
            ]
            CapybaraService.shared.showDesktopBubble(strollLines.randomElement()!, duration: 2.3)
        }
        startMotionLoopIfNeeded()
    }

    private func startMotionLoopIfNeeded() {
        guard motionTimer == nil else { return }
        let dt = 1.0 / 60.0
        let t = Timer(timeInterval: dt, repeats: true) { [weak self] _ in
            self?.stepDesktopMotion(dt: CGFloat(dt))
        }
        RunLoop.main.add(t, forMode: .common)
        motionTimer = t
    }

    private func stepDesktopMotion(dt: CGFloat) {
        guard let panel = panel, panel.isVisible else { return }
        let capy = CapybaraService.shared
        guard !capy.isDraggingOnDesktop else { return }

        let sc = panel.screen ?? NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) }) ?? NSScreen.main ?? NSScreen.screens.first!
        let vf = sc.visibleFrame
        let minX = vf.minX + 4
        let maxX = vf.maxX - panelSize.width - 4
        let minY = vf.minY + 4
        let maxY = vf.maxY - panelSize.height - 6
        var origin = panel.frame.origin

        // 0. Two-Phase Walk Home -> Hop & Climb Right Inside the Physical Notch!
        switch homePhase {
        case .walkingToDoorstep(let doorstep, let insideNotchY):
            let dx = doorstep.x - homeLogicalOrigin.x
            let dy = doorstep.y - homeLogicalOrigin.y
            let dist = hypot(dx, dy)

            if dist < 64 && capy.desktopBubble != nil {
                capy.desktopBubble = nil
            }

            if dist < 5.5 {
                homeLogicalOrigin = doorstep
                panel.setFrameOrigin(doorstep)
                NSSound(named: "Pop")?.play()
                capy.registerSquish()
                homePhase = .climbingIntoNotch(doorstep: doorstep, insideNotchY: insideNotchY, progress: 0)
                return
            }

            let step = min(dist, homeWalkSpeed * dt)
            homeLogicalOrigin.x += (dx / dist) * step
            homeLogicalOrigin.y += (dy / dist) * step

            if abs(dx) > 3 {
                capy.facingRight = dx >= 0
            }
            if capy.currentAction != .walking {
                capy.currentAction = .walking
            }

            panel.setFrameOrigin(homeLogicalOrigin)
            return

        case .climbingIntoNotch(let doorstep, let insideNotchY, let prevProgress):
            let nextProg = min(1.0, prevProgress + dt / 0.36)
            capy.notchClimbProgress = nextProg

            // Smooth cubic ease-in-out as Maki hops up & tucks behind the black Notch silhouette
            let ease = nextProg * nextProg * (3.0 - 2.0 * nextProg)
            let curY = doorstep.y + (insideNotchY - doorstep.y) * ease
            panel.setFrameOrigin(CGPoint(x: doorstep.x, y: curY))
            panel.alphaValue = max(0.0, 1.0 - max(0, (nextProg - 0.58) / 0.42))

            if nextProg >= 1.0 {
                homePhase = .none
                panel.alphaValue = 1.0
                capy.completeReturnToNotchArrival()
            } else {
                homePhase = .climbingIntoNotch(doorstep: doorstep, insideNotchY: insideNotchY, progress: nextProg)
            }
            return

        case .none:
            break
        }

        // Freeze all autonomous motion (stroll / chase / glide) while a file is being dragged onto Maki
        if isHeldForDrop {
            throwVel = .zero
            walkTarget = nil
            if capy.currentAction == .walking { capy.currentAction = .chill }
            return
        }

        // 1. Throw / Glide Momentum with Bouncy Screen Edges!
        if hypot(throwVel.x, throwVel.y) > 12 {
            let damp = pow(0.89, dt * 30.0)
            origin.x += throwVel.x * dt
            origin.y += throwVel.y * dt
            throwVel.x *= damp
            throwVel.y *= damp

            var bounced = false
            if origin.x < minX {
                origin.x = minX
                throwVel.x = abs(throwVel.x) * 0.72
                bounced = true
            } else if origin.x > maxX {
                origin.x = maxX
                throwVel.x = -abs(throwVel.x) * 0.72
                bounced = true
            }
            if origin.y < minY {
                origin.y = minY
                throwVel.y = abs(throwVel.y) * 0.72
                bounced = true
            } else if origin.y > maxY {
                origin.y = maxY
                throwVel.y = -abs(throwVel.y) * 0.72
                bounced = true
            }
            if bounced {
                NSSound(named: "Pop")?.play()
                capy.registerSquish()
            }
            panel.setFrameOrigin(origin)
            if hypot(throwVel.x, throwVel.y) <= 12 {
                throwVel = .zero
                capy.desktopOrigin = origin
                capy.registerSquish()
            }
            return
        }

        // 2. Interactive "Chase Cursor!" Game Mode
        if capy.isChasingCursor {
            let mouse = NSEvent.mouseLocation
            let petCenter = CGPoint(x: origin.x + panelSize.width * 0.5, y: origin.y + panelSize.height * 0.44)
            let dx = mouse.x - petCenter.x
            let dy = mouse.y - petCenter.y
            let dist = hypot(dx, dy)

            if dist < 44 {
                capy.desktopOrigin = origin
                capy.stopChaseCursor(caught: true)
                return
            }

            let chaseSpeed: CGFloat = 245.0
            let step = min(dist, chaseSpeed * dt)
            origin.x = max(minX, min(maxX, origin.x + (dx / dist) * step))
            origin.y = max(minY, min(maxY, origin.y + (dy / dist) * step))
            capy.facingRight = dx >= 0
            if capy.currentAction != .walking {
                capy.currentAction = .walking
            }
            panel.setFrameOrigin(origin)
            return
        }

        // 3. Autonomous Cozy Desktop Stroll
        if let target = walkTarget {
            if isHoveringDesktopPet {
                if capy.currentAction == .walking {
                    capy.currentAction = .chill
                }
                return
            }
            let dx = target.x - origin.x
            let dy = target.y - origin.y
            let dist = hypot(dx, dy)
            if dist < 4 {
                origin = CGPoint(x: max(minX, min(maxX, target.x)), y: max(minY, min(maxY, target.y)))
                panel.setFrameOrigin(origin)
                capy.desktopOrigin = origin
                walkTarget = nil
                capy.currentAction = .chill
                return
            }

            let walkSpeed: CGFloat = 68.0
            let step = min(dist, walkSpeed * dt)
            origin.x = max(minX, min(maxX, origin.x + (dx / dist) * step))
            origin.y = max(minY, min(maxY, origin.y + (dy / dist) * step))
            capy.facingRight = dx >= 0
            if capy.currentAction != .walking {
                capy.currentAction = .walking
            }
            panel.setFrameOrigin(origin)
        }
    }

    // MARK: - Rich Right-Click Context Menu
    public func presentContextMenu(with event: NSEvent, in viewWindow: NSWindow) {
        let menu = NSMenu()
        let capy = CapybaraService.shared
        let gemini = GeminiService.shared

        let chatTitle = gemini.isDesktopChatOpen ? "💬 Tutup Obrolan Maki AI" : "💬 Tanya Jawab dengan Maki (AI)"
        let chatItem = NSMenuItem(title: chatTitle, action: #selector(ctxToggleAIChat), keyEquivalent: "")
        chatItem.target = self
        menu.addItem(chatItem)

        let askShotItem = NSMenuItem(title: "📸 Tanya Maki soal Screenshot Terakhir", action: #selector(ctxAskScreenshotAI), keyEquivalent: "")
        askShotItem.target = self
        menu.addItem(askShotItem)

        let snapItem = NSMenuItem(title: "📥 Kasih Screenshot ke Tray", action: #selector(ctxGrabScreenshot), keyEquivalent: "")
        snapItem.target = self
        menu.addItem(snapItem)

        let mirrorItem = NSMenuItem(title: "🪞 Buka Cermin Kamera (Mirror)", action: #selector(ctxOpenMirror), keyEquivalent: "")
        mirrorItem.target = self
        menu.addItem(mirrorItem)

        menu.addItem(NSMenuItem.separator())

        let trickItem = NSMenuItem(title: "🎪 Atraksi Acak", action: #selector(ctxTrick), keyEquivalent: "")
        trickItem.target = self
        menu.addItem(trickItem)

        let juggleItem = NSMenuItem(title: "🍊 Atraksi Sirkus 3 Jeruk", action: #selector(ctxJuggleOranges), keyEquivalent: "")
        juggleItem.target = self
        menu.addItem(juggleItem)

        let subMenu = NSMenu(title: "Pilih Atraksi")
        let specificList: [(String, Int)] = [
            ("🍊 Sirkus 3 Jeruk", 0),
            ("💻 Ngoding MacBook Mini", 1),
            ("🍵 Nyeruput Matcha Hangat", 2),
            ("🦋 Kejar Kupu-Kupu", 3),
            ("🫧 Tiup Gelembung Sabun", 4),
            ("📖 Baca Buku", 5),
            ("💪 Peregangan Badan", 6)
        ]
        for (title, tag) in specificList {
            let sItem = NSMenuItem(title: title, action: #selector(ctxSpecificTrick(_:)), keyEquivalent: "")
            sItem.tag = tag
            sItem.target = self
            subMenu.addItem(sItem)
        }
        let chooseParent = NSMenuItem(title: "🎭 Pilih Atraksi Spesifik", action: nil, keyEquivalent: "")
        chooseParent.submenu = subMenu
        menu.addItem(chooseParent)

        let chaseTitle = capy.isChasingCursor ? "⏹️ Berhenti Kejar Kursor" : "🐾 Main Kejar Kursor"
        let chaseItem = NSMenuItem(title: chaseTitle, action: #selector(ctxChase), keyEquivalent: "")
        chaseItem.target = self
        menu.addItem(chaseItem)

        let petItem = NSMenuItem(title: "👋 Elus Maki", action: #selector(ctxPet), keyEquivalent: "")
        petItem.target = self
        menu.addItem(petItem)

        menu.addItem(NSMenuItem.separator())

        for (idx, food) in CapyFood.allCases.enumerated() {
            let item = NSMenuItem(title: "\(food.emoji) Kasih \(food.rawValue)", action: #selector(ctxFeed(_:)), keyEquivalent: "")
            item.tag = idx
            item.target = self
            menu.addItem(item)
        }

        let onsenItem = NSMenuItem(title: "♨️ Berendam Onsen", action: #selector(ctxOnsen), keyEquivalent: "")
        onsenItem.state = capy.isOnsenMode ? .on : .off
        onsenItem.target = self
        menu.addItem(onsenItem)

        let orangeItem = NSMenuItem(title: "🍊 Tumpuk Jeruk (\(capy.orangesOnHead)/3)", action: #selector(ctxOranges), keyEquivalent: "")
        orangeItem.target = self
        menu.addItem(orangeItem)

        let cleanItem = NSMenuItem(title: "🧹 Bersihkan Cache Aman (Maki Clean)", action: #selector(ctxCleanCache), keyEquivalent: "")
        cleanItem.target = self
        menu.addItem(cleanItem)

        let modelMenu = NSMenu(title: "Model Tampilan")
        let classicItem = NSMenuItem(title: "🐾 Maki Klasik", action: #selector(ctxSwitchModel(_:)), keyEquivalent: "")
        classicItem.tag = 0
        classicItem.state = (capy.mascotModel == .classic) ? .on : .off
        classicItem.target = self
        modelMenu.addItem(classicItem)

        let plushieItem = NSMenuItem(title: "🧸 Maki Boneka (Kaos 'maki')", action: #selector(ctxSwitchModel(_:)), keyEquivalent: "")
        plushieItem.tag = 1
        plushieItem.state = (capy.mascotModel == .plushie) ? .on : .off
        plushieItem.target = self
        modelMenu.addItem(plushieItem)

        let modelParent = NSMenuItem(title: "🎨 Model Tampilan: \(capy.mascotModel.shortLabel)", action: nil, keyEquivalent: "")
        modelParent.submenu = modelMenu
        menu.addItem(modelParent)

        menu.addItem(NSMenuItem.separator())

        let roamItem = NSMenuItem(title: "🚶 Bebas Jalan-Jalan di Desktop", action: #selector(ctxToggleRoam), keyEquivalent: "")
        roamItem.state = capy.desktopRoamEnabled ? .on : .off
        roamItem.target = self
        menu.addItem(roamItem)

        let homeItem = NSMenuItem(title: "🏠 Jalan Pulang ke Notch", action: #selector(ctxReturnHome), keyEquivalent: "")
        homeItem.target = self
        menu.addItem(homeItem)

        menu.addItem(NSMenuItem.separator())

        let autoLaunchItem = NSMenuItem(
            title: "⚡ Buka Otomatis saat Booting / Nyala",
            action: #selector(ctxToggleAutoLaunch),
            keyEquivalent: ""
        )
        autoLaunchItem.state = AutoLaunchService.shared.isLaunchAtLoginEnabled ? .on : .off
        autoLaunchItem.target = self
        menu.addItem(autoLaunchItem)

        menu.addItem(NSMenuItem.separator())

        let helpItem = NSMenuItem(title: "❓ Panduan Penggunaan & Setup AI", action: #selector(ctxOpenHelpGuide), keyEquivalent: "")
        helpItem.target = self
        menu.addItem(helpItem)

        let updateTitle = UpdateService.shared.isUpdateAvailable
            ? "✨ Pembaruan Tersedia (v\(UpdateService.shared.latestVersion))"
            : "🔄 Periksa Pembaruan..."
        let updateItem = NSMenuItem(title: updateTitle, action: #selector(ctxCheckUpdate), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        if let cv = viewWindow.contentView {
            NSMenu.popUpContextMenu(menu, with: event, for: cv)
        }
    }

    @objc private func ctxToggleAIChat() {
        GeminiService.shared.toggleDesktopChat()
    }
    @objc private func ctxAskScreenshotAI() {
        _ = GeminiService.shared.attachLatestScreenshotOrClipboard()
        if !GeminiService.shared.isDesktopChatOpen {
            GeminiService.shared.toggleDesktopChat()
        }
    }
    @objc private func ctxGrabScreenshot() { CapybaraService.shared.catchClipboardOrRecentScreenshot() }
    @objc private func ctxOpenMirror() {
        IslandState.shared.isExpanded = true
        IslandState.shared.isShowingCameraMirror = true
        IslandController.shared.panel?.makeKeyAndOrderFront(nil)
    }
    @objc private func ctxTrick() { CapybaraService.shared.triggerRandomFunActivity() }
    @objc private func ctxJuggleOranges() {
        CapybaraService.shared.triggerSpecificActivity(.jugglingOranges, message: "satu.. dua.. tiga..", duration: 8.0)
    }
    @objc private func ctxSpecificTrick(_ sender: NSMenuItem) {
        let capy = CapybaraService.shared
        switch sender.tag {
        case 0: capy.triggerSpecificActivity(.jugglingOranges, message: "satu.. dua.. tiga..", duration: 8.0)
        case 1: capy.triggerSpecificActivity(.typingLaptop, message: "ikut ngetik ah..", duration: 7.5)
        case 2: capy.triggerSpecificActivity(.sippingTea, message: "anget tehnya..", duration: 7.0)
        case 3: capy.triggerSpecificActivity(.butterflyChase, message: "eh ada kupu-kupu", duration: 7.5)
        case 4: capy.triggerSpecificActivity(.blowingBubbles, message: "fuuhh..", duration: 7.0)
        case 5: capy.triggerSpecificActivity(.readingBook, message: "baca bentar..", duration: 7.0)
        case 6: capy.triggerSpecificActivity(.stretching, message: "pegel duduk terus..", duration: 6.0)
        default: break
        }
    }
    @objc private func ctxChase() { CapybaraService.shared.toggleChaseCursor() }
    @objc private func ctxPet() { CapybaraService.shared.pet(fromDesktop: true) }
    @objc private func ctxFeed(_ sender: NSMenuItem) {
        let all = CapyFood.allCases
        if sender.tag >= 0 && sender.tag < all.count {
            CapybaraService.shared.feed(all[sender.tag])
        }
    }
    @objc private func ctxOnsen() { CapybaraService.shared.toggleOnsen() }
    @objc private func ctxOranges() { CapybaraService.shared.cycleOrangeOnHead() }
    @objc public func ctxCleanCache() {
        let capy = CapybaraService.shared
        let cleaner = CacheCleanerManager.shared
        capy.showDesktopBubble("Hup! Tunggu bentar ya, Maki bersihkan sampah cache dulu~ 🧹", duration: 3.5)
        capy.currentAction = .happyPet

        Task {
            let result = await cleaner.cleanSafeItems()
            await MainActor.run {
                if result.totalBytesFreed > 0 {
                    NSSound(named: "Glass")?.play()
                    capy.xp += 10
                    capy.mood = min(100, capy.mood + 5)
                    capy.showDesktopBubble("Selesai! Berhasil memindahkan \(result.formattedTotalFreed) sampah ke Tong Sampah! 🐾✨", duration: 4.5)
                } else {
                    capy.showDesktopBubble("Laptopmu udah kinclong, nggak ada cache yang perlu dibuang! ✨", duration: 3.5)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if capy.currentAction == .happyPet {
                        capy.currentAction = .chill
                    }
                }
            }
        }
    }
    @objc private func ctxToggleRoam() {
        CapybaraService.shared.desktopRoamEnabled.toggle()
        if !CapybaraService.shared.desktopRoamEnabled {
            stopCurrentWalk()
            CapybaraService.shared.showDesktopBubble("oke duduk sini aja", duration: 2.2)
        } else {
            CapybaraService.shared.showDesktopBubble("jalan-jalan lagi ah", duration: 2.2)
            startAutonomousStroll()
        }
    }
    @objc private func ctxSwitchModel(_ sender: NSMenuItem) {
        if sender.tag == 1 {
            CapybaraService.shared.mascotModel = .plushie
            CapybaraService.shared.showDesktopBubble("pakai kaos 'maki' kesayangan 🧸✨", duration: 3.0)
        } else {
            CapybaraService.shared.mascotModel = .classic
            CapybaraService.shared.showDesktopBubble("kembali ke bulu cokelat klasik 🐾", duration: 3.0)
        }
    }
    @objc private func ctxToggleAutoLaunch() {
        AutoLaunchService.shared.toggle()
        let state = AutoLaunchService.shared.isLaunchAtLoginEnabled ? "aktif ⚡" : "dimatikan"
        CapybaraService.shared.showDesktopBubble("autorun booting \(state)", duration: 2.8)
    }
    @objc private func ctxReturnHome() { CapybaraService.shared.returnToNotch() }
    @objc private func ctxOpenHelpGuide() {
        let state = IslandState.shared
        state.isExpanded = true
        state.isShowingOnboarding = true
    }
    @objc private func ctxCheckUpdate() {
        let updater = UpdateService.shared
        if updater.isUpdateAvailable {
            let state = IslandState.shared
            state.isExpanded = true
            state.isShowingUpdateModal = true
        } else {
            updater.checkForUpdates(manual: true)
            CapybaraService.shared.showDesktopBubble("Maki cek pembaruan di GitHub bentar ya.. 🔍", duration: 3.5)
        }
    }
}

struct DesktopCapyRootView: View {
    @ObservedObject var capy = CapybaraService.shared
    @ObservedObject var music = MusicService.shared
    @ObservedObject var timer = TimerService.shared
    @ObservedObject var islandState = IslandState.shared
    @ObservedObject var gemini = GeminiService.shared

    /// Driven by the controller's precise cursor hit-test (only Maki's body counts, not the transparent panel area)
    private var isHovering: Bool { capy.desktopPointerInside }

    private var activeDesktopRole: CapyRole {
        if capy.isOnsenMode { return .habitat }
        if music.currentTrack.isPlaying { return .djMusic }
        if timer.isRunning { return .senseiTimer }
        if islandState.isExpanded && islandState.selectedTab != .capy {
            return CapyRole.from(tab: islandState.selectedTab)
        }
        return .habitat
    }

    private var displayedBubbleText: String? {
        if capy.isMouthOpenForDrop {
            return gemini.isDesktopChatOpen ? "lepas buat ditanyakan.." : "sini kasih ke aku.."
        }
        return capy.desktopBubble
    }

    var body: some View {
        VStack(spacing: 2) {
            if gemini.isDesktopChatOpen && !capy.isReturningToNotch {
                MakiDesktopChatCard()
                    .transition(.scale(scale: 0.92, anchor: .bottom).combined(with: .opacity))
                    .zIndex(20)
            } else {
                // Cozy, snug-fitting comic speech bubble with pointer tail (never stretches artificially!)
                ZStack(alignment: .bottom) {
                    if let msg = displayedBubbleText {
                        CapySpeechBubbleView(
                            text: msg,
                            tail: .bottom,
                            fontSize: 10.5,
                            maxBubbleWidth: 186
                        )
                        .transition(.scale(scale: 0.86, anchor: .bottom).combined(with: .opacity))
                    }
                }
                .frame(width: 248, height: 46, alignment: .bottom)
                .animation(.spring(response: 0.28, dampingFraction: 0.78), value: displayedBubbleText)
                .zIndex(10)
            }

            // 2D Interactive Maki Stage
            ZStack {
                Capybara2DView(
                    role: activeDesktopRole,
                    action: capy.currentAction,
                    orangesOnHead: capy.orangesOnHead,
                    isOnsen: capy.isOnsenMode && !gemini.isDesktopChatOpen,
                    isListeningMusic: music.currentTrack.isPlaying,
                    isFocusing: timer.isRunning,
                    isDangling: capy.isDraggingOnDesktop,
                    isMouthOpenForDrop: capy.isMouthOpenForDrop,
                    lookVector: capy.lookVector,
                    lastSquishTime: capy.lastSquishTime,
                    facingRight: capy.facingRight,
                    mascotModel: capy.mascotModel
                )
                .frame(width: 122, height: 114)
                .scaleEffect(1.0 - capy.notchClimbProgress * 0.72, anchor: .top)

                if music.currentTrack.isPlaying && !capy.isDraggingOnDesktop && !capy.isReturningToNotch {
                    Text("♪ ♫")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18))
                        .padding(.horizontal, 5.5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(red: 1.0, green: 0.985, blue: 0.95).opacity(0.95)))
                        .overlay(Capsule().stroke(Color(red: 0.23, green: 0.13, blue: 0.06).opacity(0.24), lineWidth: 0.8))
                        .offset(x: -44, y: -32)
                        .allowsHitTesting(false)
                }
            }

            // Handcrafted Quick-Play Pill Dock (harmonized cream glass matching speech bubble, appears smoothly on hover or chat)
            HStack(spacing: 3.5) {
                quickDockBtn("💬", active: gemini.isDesktopChatOpen, help: "Tanya Jawab dengan Maki (Gemini AI)") {
                    gemini.toggleDesktopChat()
                }
                quickDockBtn("📸", help: "Kasih Screenshot dari Clipboard / Terakhir ke Tray") {
                    capy.catchClipboardOrRecentScreenshot()
                }
                quickDockBtn("🎪", help: "Atraksi Acak") {
                    capy.triggerRandomFunActivity()
                }
                quickDockBtn(capy.isChasingCursor ? "⏹️" : "🐾", active: capy.isChasingCursor, help: "Main Kejar Kursor") {
                    capy.toggleChaseCursor()
                }
                quickDockBtn("🍊", help: "Kasih Jeruk") {
                    capy.feed(.orange)
                }
                quickDockBtn("♨️", active: capy.isOnsenMode, help: capy.isOnsenMode ? "Selesai Berendam Onsen" : "Berendam Onsen Air Hangat") {
                    capy.toggleOnsen()
                }
                quickDockBtn("🧹", help: "Sapu Cache & Sampah Aman (Maki Clean)") {
                    DesktopCapyController.shared.ctxCleanCache()
                }
                quickDockBtn(capy.desktopRoamEnabled ? "🚶" : "📌", active: !capy.desktopRoamEnabled, help: capy.desktopRoamEnabled ? "Sedang Bebas Jalan (Klik untuk Kunci Posisi)" : "Posisi Dikunci (Klik agar Bebas Jalan)") {
                    capy.desktopRoamEnabled.toggle()
                    if !capy.desktopRoamEnabled {
                        DesktopCapyController.shared.stopCurrentWalk()
                        capy.showDesktopBubble("oke duduk sini aja", duration: 2.0)
                    } else {
                        capy.showDesktopBubble("jalan-jalan lagi ah", duration: 2.0)
                        DesktopCapyController.shared.startAutonomousStroll()
                    }
                }
                quickDockBtn("🏠", help: "Jalan Pulang ke Notch") {
                    capy.returnToNotch()
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(
                Capsule()
                    .fill(Color(red: 1.0, green: 0.985, blue: 0.95).opacity(0.95))
                    .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 3)
            )
            .overlay(
                Capsule()
                    .stroke(Color(red: 0.23, green: 0.13, blue: 0.06).opacity(0.25), lineWidth: 1.0)
            )
            .opacity((isHovering || gemini.isDesktopChatOpen) && !capy.isDraggingOnDesktop && !capy.isReturningToNotch ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.16), value: isHovering)
            .frame(height: 27)
        }
        .frame(
            width: gemini.isDesktopChatOpen ? 336 : 264,
            height: gemini.isDesktopChatOpen ? 376 : 194,
            alignment: .bottom
        )
        .help("Klik 💬 untuk Tanya Jawab AI • Tarik Screenshot/File ke Maki • Klik: Elus • Klik Kanan: Menu")
    }

    @ViewBuilder
    private func quickDockBtn(_ icon: String, active: Bool = false, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(icon)
                .font(.system(size: 11))
                .frame(width: 22, height: 20)
                .background(active ? Color.orange.opacity(0.35) : Color.black.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
