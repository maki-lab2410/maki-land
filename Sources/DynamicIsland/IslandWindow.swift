import Cocoa
import SwiftUI

public class IslandPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        registerForDraggedTypes(DropZoneService.supportedDraggedTypes)
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }

    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }

    @objc public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        DispatchQueue.main.async {
            CapybaraService.shared.isMouthOpenForDrop = true
        }
        return .copy
    }

    @objc public func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    @objc public func draggingExited(_ sender: NSDraggingInfo?) {
        DispatchQueue.main.async {
            CapybaraService.shared.isMouthOpenForDrop = false
        }
    }

    @objc public func draggingEnded(_ sender: NSDraggingInfo) {
        DispatchQueue.main.async {
            CapybaraService.shared.isMouthOpenForDrop = false
        }
    }

    @objc public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        DispatchQueue.main.async {
            CapybaraService.shared.isMouthOpenForDrop = false
        }
        DropZoneService.shared.extractURLsFromDraggingInfo(sender) { urls in
            guard !urls.isEmpty else { return }
            CapybaraService.shared.completeSwallowIntoTray(urls: urls)
        }
        return true
    }

    public override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .leftMouseUp || event.type == .rightMouseDown {
            IslandController.shared.lastInsideClickDate = Date()
        }
        if IslandState.shared.isExpanded && (event.type == .leftMouseDown || event.type == .rightMouseDown) {
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }
            if !isKeyWindow {
                makeKey()
            }
        }
        super.sendEvent(event)
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard IslandState.shared.isExpanded else {
            return super.performKeyEquivalent(with: event)
        }

        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.numericPad, .function])
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let isNotes = (IslandState.shared.selectedTab == .notes)

        // 1. Command + Shift combinations
        if flags == [.command, .shift] {
            if key == "z" {
                if let um = firstResponder?.undoManager, um.canRedo {
                    um.redo()
                    return true
                }
                return NSApp.sendAction(Selector(("redo:")), to: nil, from: self)
            }
            if isNotes {
                switch key {
                case "c":
                    NotesService.shared.copyAllScratchpad()
                    return true
                case "v":
                    NotesService.shared.pasteClipboardAsTodos()
                    return true
                case "l":
                    NotesService.shared.insertBullet()
                    return true
                case "t":
                    NotesService.shared.insertTimestamp()
                    return true
                case "d":
                    NotesService.shared.clearCompleted()
                    return true
                default:
                    if event.keyCode == 51 {
                        NotesService.shared.clearCompleted()
                        return true
                    }
                }
            }
        }

        // 2. Command-only combinations
        if flags == .command {
            if isNotes && (event.keyCode == 36 || event.keyCode == 76) {
                NotesService.shared.sendScratchpadSelectionOrLineToTodo(in: self)
                return true
            }

            if isNotes {
                switch key {
                case "n":
                    NotesService.shared.showShortcutGuide = false
                    NotesService.shared.focusRequest.send(.todoInput)
                    return true
                case "j", "e":
                    NotesService.shared.showShortcutGuide = false
                    NotesService.shared.focusRequest.send(.scratchpad)
                    return true
                case "/":
                    NotesService.shared.showShortcutGuide.toggle()
                    return true
                default:
                    break
                }
            }

            let allTabs = IslandTab.allCases
            if let num = Int(key), num >= 1, num <= allTabs.count {
                if IslandState.shared.selectedTab != allTabs[num - 1] {
                    IslandState.shared.selectedTab = allTabs[num - 1]
                }
                return true
            }

            switch key {
            case "a":
                return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
            case "c":
                return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
            case "v":
                if IslandState.shared.selectedTab == .capy && GeminiService.shared.isNotchChatMode {
                    let pb = NSPasteboard.general
                    if pb.string(forType: .string) == nil, let img = NSImage(pasteboard: pb), img.size.width > 4 {
                        _ = GeminiService.shared.attachNSImage(img, name: "Clipboard Image")
                        return true
                    }
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
}

// MARK: - IslandController (Constant Centered Canvas — Zero Window-Resize Jump!)

public class IslandHostingView: NSHostingView<IslandRootView> {
    @MainActor required public init(rootView: IslandRootView) {
        super.init(rootView: rootView)
        registerForDraggedTypes(DropZoneService.supportedDraggedTypes)
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(DropZoneService.supportedDraggedTypes)
    }

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        DispatchQueue.main.async {
            CapybaraService.shared.isMouthOpenForDrop = true
        }
        return .copy
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if !CapybaraService.shared.isMouthOpenForDrop {
            DispatchQueue.main.async {
                CapybaraService.shared.isMouthOpenForDrop = true
            }
        }
        return .copy
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        DispatchQueue.main.async {
            CapybaraService.shared.isMouthOpenForDrop = false
        }
    }

    public override func draggingEnded(_ sender: NSDraggingInfo) {
        DispatchQueue.main.async {
            CapybaraService.shared.isMouthOpenForDrop = false
        }
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        DispatchQueue.main.async {
            CapybaraService.shared.isMouthOpenForDrop = false
        }
        DropZoneService.shared.extractURLsFromDraggingInfo(sender) { urls in
            guard !urls.isEmpty else { return }
            CapybaraService.shared.completeSwallowIntoTray(urls: urls)
        }
        return true
    }
}

public class IslandController: NSObject {
    public static let shared = IslandController()
    public static let canvasSize = CGSize(width: 720, height: 330)

    public var panel: IslandPanel?
    public private(set) var auxiliaryPanels: [IslandPanel] = []
    public var allPanels: [IslandPanel] { [panel].compactMap { $0 } + auxiliaryPanels }
    public var lastInsideClickDate: Date = .distantPast

    private var globalClickMonitor: Any?
    private var globalMoveMonitor: Any?
    private var localMoveMonitor: Any?
    private var localKeyMonitor: Any?

    override init() { super.init() }

    public func setup() {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let frame = calculateCanvasFrame(on: screen)

        let panel = IslandPanel(contentRect: frame)
        self.panel = panel

        MainActor.assumeIsolated {
            let hosting = IslandHostingView(rootView: IslandRootView())
            hosting.sizingOptions = []
            hosting.frame = NSRect(origin: .zero, size: frame.size)
            hosting.autoresizingMask = [.width, .height]
            hosting.wantsLayer = true
            hosting.layer?.backgroundColor = CGColor(gray: 0, alpha: 0)
            hosting.layer?.isOpaque = false
            panel.contentView = hosting
        }
        panel.orderFrontRegardless()
        syncAuxiliaryPanels()
        updateMousePassthrough()

        IslandState.shared.onSizeChange = { [weak self] _ in
            self?.handleIslandStateUpdated()
        }

        setupMousePassthroughMonitors()
        setupKeyMonitor()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )

        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let s = IslandState.shared
            guard s.isExpanded && !s.isPinned && !s.isModalOpen else { return }

            if Date().timeIntervalSince(self.lastInsideClickDate) < 0.35 { return }
            let mouse = NSEvent.mouseLocation
            for p in self.allPanels {
                if let sc = p.screen ?? NSScreen.main,
                   self.activeNotchScreenRect(on: sc).insetBy(dx: -6, dy: -6).contains(mouse) {
                    return
                }
            }
            if let petRect = DesktopCapyController.shared.interactiveScreenRect,
               petRect.insetBy(dx: -6, dy: -6).contains(mouse) {
                return
            }
            if let companionRect = CompanionCapyController.shared.interactiveScreenRect,
               companionRect.insetBy(dx: -6, dy: -6).contains(mouse) {
                return
            }

            s.setExpanded(false)
        }
    }

    private func setupMousePassthroughMonitors() {
        let moveMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        globalMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: moveMask) { [weak self] _ in
            self?.updateMousePassthrough()
        }
        localMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: moveMask) { [weak self] event in
            self?.updateMousePassthrough()
            return event
        }
    }

    public func updateMousePassthrough() {
        let mouse = NSEvent.mouseLocation
        for p in allPanels {
            guard let screen = p.screen ?? NSScreen.main else { continue }
            let hitZone = activeNotchScreenRect(on: screen).insetBy(dx: -14, dy: -10)
            let shouldAcceptMouse = hitZone.contains(mouse)
            let shouldIgnore = !shouldAcceptMouse
            if p.ignoresMouseEvents != shouldIgnore {
                p.ignoresMouseEvents = shouldIgnore
                if shouldIgnore && !IslandState.shared.isExpanded {
                    IslandState.shared.forceClearHoverTrigger &+= 1
                }
            }
        }
    }

    private func handleIslandStateUpdated() {
        updateMousePassthrough()
        guard let panel = panel else { return }

        if IslandState.shared.isExpanded {
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }
            if !panel.isKeyWindow {
                panel.makeKey()
            }
            startMonitoringOutsideClicks()
        } else {
            stopMonitoringOutsideClicks()
        }
    }

    private func setupKeyMonitor() {
        let optionNumberKeyCodes: [UInt16: Int] = [
            18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8
        ]

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let state = IslandState.shared
            guard state.isExpanded else { return event }

            let flags = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .subtracting([.numericPad, .function])

            if flags == .option, let idx = optionNumberKeyCodes[event.keyCode] {
                if state.selectedTab == .notes {
                    NotesService.shared.toggleTodoAtIndex(idx)
                    return nil
                } else if state.selectedTab == .clipboard {
                    let list = ClipboardService.shared.history
                    if idx < list.count {
                        ClipboardService.shared.copyItem(list[idx])
                    }
                    return nil
                }
            }

            if state.selectedTab == .notes && flags == .command && (event.keyCode == 36 || event.keyCode == 76) {
                NotesService.shared.sendScratchpadSelectionOrLineToTodo(in: self.panel)
                return nil
            }

            if event.keyCode == 53 && flags.isEmpty {
                if state.selectedTab == .capy {
                    if GeminiService.shared.isShowingSettings {
                        GeminiService.shared.isShowingSettings = false
                        return nil
                    }
                    if GeminiService.shared.isNotchChatMode {
                        GeminiService.shared.isNotchChatMode = false
                        return nil
                    }
                }
                if state.selectedTab == .makiLand && CalendarService.shared.isShowingSettings {
                    CalendarService.shared.isShowingSettings = false
                    return nil
                }
                if state.selectedTab == .notes && NotesService.shared.showShortcutGuide {
                    NotesService.shared.showShortcutGuide = false
                    return nil
                }
                if state.selectedTab == .tray && DropZoneService.shared.activeStudioItem != nil {
                    DropZoneService.shared.closeStudio()
                    return nil
                }
                if !state.isPinned && !state.isModalOpen {
                    state.setExpanded(false)
                    return nil
                }
            }

            return event
        }
    }

    // MARK: - Outside Click Detection (checks active visible Notch rect, NOT full canvas!)
    private func startMonitoringOutsideClicks() {
        guard globalClickMonitor == nil else { return }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.handleOutsideClick()
        }
    }

    private func stopMonitoringOutsideClicks() {
        if let m = globalClickMonitor {
            NSEvent.removeMonitor(m)
            globalClickMonitor = nil
        }
    }

    private func handleOutsideClick() {
        guard let panel = panel, let screen = panel.screen ?? NSScreen.main else { return }
        let s = IslandState.shared
        guard !s.isModalOpen else { return }
        if Date().timeIntervalSince(lastInsideClickDate) < 0.25 { return }

        let mouseLoc = NSEvent.mouseLocation
        if let petRect = DesktopCapyController.shared.interactiveScreenRect,
           petRect.insetBy(dx: -4, dy: -4).contains(mouseLoc) {
            return
        }

        let safeRect = activeNotchScreenRect(on: screen).insetBy(dx: -4, dy: -4)
        if !safeRect.contains(mouseLoc) {
            DispatchQueue.main.async {
                if s.isExpanded && !s.isPinned && !s.isModalOpen {
                    s.setExpanded(false)
                }
            }
        }
    }

    public func activeNotchScreenRect(on screen: NSScreen) -> NSRect {
        let s = IslandState.shared
        let size = s.currentTargetSize
        let activeW: CGFloat = s.isExpanded ? (size.width + 12) : (size.width + 26)
        let activeH: CGFloat = s.isExpanded ? (size.height + 12) : 42
        let x = round(screen.frame.midX - activeW / 2)
        let y = screen.frame.maxY - activeH
        return NSRect(x: x, y: y, width: activeW, height: activeH)
    }

    private func calculateCanvasFrame(on screen: NSScreen) -> NSRect {
        let w = Self.canvasSize.width
        let h = Self.canvasSize.height
        let x = round(screen.frame.midX - w / 2)
        let y = screen.frame.maxY - h
        return NSRect(x: x, y: y, width: w, height: h)
    }

    public func syncAuxiliaryPanels() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let primaryScreen = NSScreen.main ?? screens.first!
        let extScreens = screens.filter { $0 != primaryScreen }

        var newAux: [IslandPanel] = []
        for (idx, sc) in extScreens.enumerated() {
            let targetFrame = calculateCanvasFrame(on: sc)
            if idx < auxiliaryPanels.count {
                let p = auxiliaryPanels[idx]
                p.setFrame(targetFrame, display: true)
                p.orderFrontRegardless()
                newAux.append(p)
            } else {
                let newPanel = IslandPanel(contentRect: targetFrame)
                MainActor.assumeIsolated {
                    let hosting = IslandHostingView(rootView: IslandRootView())
                    hosting.sizingOptions = []
                    hosting.frame = NSRect(origin: .zero, size: targetFrame.size)
                    hosting.autoresizingMask = [.width, .height]
                    hosting.wantsLayer = true
                    hosting.layer?.backgroundColor = CGColor(gray: 0, alpha: 0)
                    hosting.layer?.isOpaque = false
                    newPanel.contentView = hosting
                }
                newPanel.orderFrontRegardless()
                newAux.append(newPanel)
            }
        }

        if auxiliaryPanels.count > extScreens.count {
            for extra in auxiliaryPanels[extScreens.count...] {
                extra.orderOut(nil)
            }
        }
        auxiliaryPanels = newAux
    }

    @objc private func screenChanged() {
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            panel?.setFrame(calculateCanvasFrame(on: screen), display: true)
        }
        syncAuxiliaryPanels()
        updateMousePassthrough()
        CompanionCapyController.shared.syncWithScreens()
    }

    public func toggleVisibility() {
        for p in allPanels {
            if p.isVisible { p.orderOut(nil) } else { p.orderFrontRegardless() }
        }
    }
}
