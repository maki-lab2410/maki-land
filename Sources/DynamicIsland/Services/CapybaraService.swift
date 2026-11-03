import Foundation
import AppKit
import SwiftUI
import Combine
import UniformTypeIdentifiers

public enum CapyMascotModel: String, CaseIterable, Identifiable, Codable {
    case classic = "classic"
    case plushie = "plushie"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .classic: return "🐾 Maki Klasik (Capybara)"
        case .plushie: return "🧸 Maki Boneka (Kaos 'maki')"
        }
    }

    public var shortLabel: String {
        switch self {
        case .classic: return "🐾 Klasik"
        case .plushie: return "🧸 Boneka"
        }
    }

    public var displayName: String {
        switch self {
        case .classic: return "🐾 Klasik"
        case .plushie: return "🧸 Boneka Kaos 'maki'"
        }
    }
}

public enum CapyFood: String, CaseIterable, Identifiable {
    case orange     = "Jeruk"
    case watermelon = "Semangka"
    case greens     = "Sayur"

    public var id: String { rawValue }

    public var emoji: String {
        switch self {
        case .orange:     return "🍊"
        case .watermelon: return "🍉"
        case .greens:     return "🥬"
        }
    }
}

public enum CapyRole: Equatable {
    case djMusic
    case habitat
    case scholarNotes
    case pilotLauncher
    case builderTray
    case mechanicSystem
    case detectiveClipboard
    case senseiTimer

    public static func from(tab: IslandTab) -> CapyRole {
        switch tab {
        case .makiLand:  return .djMusic
        case .capy:      return .habitat
        case .notes:     return .scholarNotes
        case .launcher:  return .pilotLauncher
        case .tray:      return .builderTray
        case .monitor:   return .mechanicSystem
        case .clipboard: return .detectiveClipboard
        case .timer:     return .senseiTimer
        }
    }

    public var badgeLabel: String {
        switch self {
        case .djMusic:            return "🎧 DJ Maki"
        case .habitat:            return "🐾 Maki"
        case .scholarNotes:       return "👓 Sekretaris"
        case .pilotLauncher:      return "🚀 Kapten"
        case .builderTray:        return "👷 Studio"
        case .mechanicSystem:     return "🔧 Mekanik"
        case .detectiveClipboard: return "🔍 Detektif"
        case .senseiTimer:        return "🔥 Sensei"
        }
    }
}

public enum CapyAction: Equatable {
    case chill
    case walking
    case happyPet
    case ticklish
    case dizzy
    case brushed
    case eating(String)
    case swallowing
    case sleeping
    // Autonomous idle & interactive showcase activities!
    case sippingTea
    case butterflyChase
    case jugglingOranges
    case blowingBubbles
    case typingLaptop
    case readingBook
    case stretching

    public var isIdleShowActivity: Bool {
        switch self {
        case .sippingTea, .butterflyChase, .jugglingOranges, .blowingBubbles, .typingLaptop, .readingBook, .stretching:
            return true
        default:
            return false
        }
    }
}

public class CapybaraService: ObservableObject {
    public static let shared = CapybaraService()

    @Published public var mood: Int = 90 { didSet { save() } }
    @Published public var fullness: Int = 85 { didSet { save() } }
    @Published public var xp: Int = 15 { didSet { save() } }
    @Published public var orangesOnHead: Int = 1 { didSet { save() } }
    @Published public var isOnsenMode: Bool = false { didSet { save() } }
    @Published public var mascotModel: CapyMascotModel = .classic { didSet { save() } }
    @Published public var showInCompactNotch: Bool = true {
        didSet {
            save()
            IslandState.shared.notifySize()
        }
    }

    // Coucou / Shimeji-style Floating Desktop Companion state
    @Published public var isOnDesktop: Bool = false {
        didSet {
            save()
            IslandState.shared.notifySize()
        }
    }
    @Published public var desktopRoamEnabled: Bool = true { didSet { save() } }
    @Published public var isDraggingOnDesktop: Bool = false
    @Published public var isChasingCursor: Bool = false
    @Published public var isMouthOpenForDrop: Bool = false
    /// True while the pointer is over Maki's body (or his visible quick dock) on the Desktop.
    @Published public var desktopPointerInside: Bool = false
    @Published public var isReturningToNotch: Bool = false
    @Published public var notchClimbProgress: CGFloat = 0

    // Live interactive animation & gaze state
    @Published public var currentAction: CapyAction = .chill
    @Published public var lookVector: CGPoint = .zero
    @Published public var lastSquishTime: TimeInterval = 0
    @Published public var speechBubble: String? = nil
    @Published public var contextualTip: String? = nil
    @Published public var desktopBubble: String? = nil
    @Published public var heartBurstCount: Int = 0
    @Published public var posX: CGFloat = 0
    @Published public var facingRight: Bool = false

    public var desktopOrigin: CGPoint = .zero { didSet { saveDesktopOrigin() } }

    public var level: Int {
        max(1, (xp / 50) + 1)
    }

    public var levelProgress: Double {
        Double(xp % 50) / 50.0
    }

    private let storagePrefix = "maki_capybara_"
    private var lifeTimer: Timer?
    private var gazeTimer: Timer?
    private var chaseStopWork: DispatchWorkItem?
    private var bubbleDismissWork: DispatchWorkItem?
    private var tipDismissWork: DispatchWorkItem?
    private var desktopBubbleWork: DispatchWorkItem?
    private var actionResetWork: DispatchWorkItem?

    private var pokeStreak: Int = 0
    private var lastPokeDate: Date = .distantPast
    private var strokeAccum: CGFloat = 0
    private var lastStrokeSoundDate: Date = .distantPast
    private var lastActivityIndex: Int = -1
    private var isLoading: Bool = false

    private let petQuotes = [
        "adem dielus..",
        "hehe makasih ya",
        "hmm nyaman banget",
        "jadi ngantuk nih..",
        "santai aja kerjanya",
        "jangan lupa minum air ya"
    ]

    private let ticklishQuotes = [
        "eh geli tau..",
        "haha jangan disitu",
        "pelan-pelan dong.."
    ]

    private let dizzyQuotes = [
        "aduh pusing..",
        "jangan ditoel terus dong",
        "muter-muter nih kepalaku.."
    ]

    private init() {
        isLoading = true
        load()
        isLoading = false
        startLifeLoop()
        startGlobalCursorGazeTracker()
    }

    private func load() {
        let d = UserDefaults.standard
        if d.object(forKey: storagePrefix + "mood") != nil {
            mood = d.integer(forKey: storagePrefix + "mood")
            fullness = d.integer(forKey: storagePrefix + "fullness")
            xp = d.integer(forKey: storagePrefix + "xp")
            orangesOnHead = d.integer(forKey: storagePrefix + "oranges")
            isOnsenMode = d.bool(forKey: storagePrefix + "onsen")
            if let savedModel = d.string(forKey: storagePrefix + "mascot_model"),
               let parsed = CapyMascotModel(rawValue: savedModel) {
                mascotModel = parsed
            }
            showInCompactNotch = d.bool(forKey: storagePrefix + "compact")
            isOnDesktop = d.bool(forKey: storagePrefix + "on_desktop")
            if d.object(forKey: storagePrefix + "desk_roam") != nil {
                desktopRoamEnabled = d.bool(forKey: storagePrefix + "desk_roam")
            }
        }
        if d.object(forKey: storagePrefix + "desk_x") != nil {
            desktopOrigin = CGPoint(
                x: d.double(forKey: storagePrefix + "desk_x"),
                y: d.double(forKey: storagePrefix + "desk_y")
            )
        } else if let screen = NSScreen.main ?? NSScreen.screens.first {
            desktopOrigin = CGPoint(
                x: screen.visibleFrame.maxX - 185,
                y: screen.visibleFrame.minY + 24
            )
        }
    }

    private func save() {
        guard !isLoading else { return }
        let d = UserDefaults.standard
        d.set(mood, forKey: storagePrefix + "mood")
        d.set(fullness, forKey: storagePrefix + "fullness")
        d.set(xp, forKey: storagePrefix + "xp")
        d.set(orangesOnHead, forKey: storagePrefix + "oranges")
        d.set(isOnsenMode, forKey: storagePrefix + "onsen")
        d.set(mascotModel.rawValue, forKey: storagePrefix + "mascot_model")
        d.set(showInCompactNotch, forKey: storagePrefix + "compact")
        d.set(isOnDesktop, forKey: storagePrefix + "on_desktop")
        d.set(desktopRoamEnabled, forKey: storagePrefix + "desk_roam")
    }

    private func saveDesktopOrigin() {
        let d = UserDefaults.standard
        d.set(Double(desktopOrigin.x), forKey: storagePrefix + "desk_x")
        d.set(Double(desktopOrigin.y), forKey: storagePrefix + "desk_y")
    }

    // MARK: - Global Real-Time Eye & Head Cursor Tracking
    private func startGlobalCursorGazeTracker() {
        let timer = Timer(timeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            self?.updateGazeTowardMouse()
        }
        RunLoop.main.add(timer, forMode: .common)
        gazeTimer = timer
    }

    private func updateGazeTowardMouse() {
        let mouse = NSEvent.mouseLocation
        let anchor: CGPoint

        if isOnDesktop, let deskFrame = DesktopCapyController.shared.panel?.frame, DesktopCapyController.shared.panel?.isVisible == true {
            anchor = CGPoint(x: deskFrame.midX, y: deskFrame.minY + 90)
        } else if let islandFrame = IslandController.shared.panel?.frame {
            anchor = CGPoint(
                x: IslandState.shared.isExpanded ? islandFrame.midX + 275 : islandFrame.midX + 80,
                y: IslandState.shared.isExpanded ? islandFrame.maxY - 90 : islandFrame.maxY - 18
            )
        } else {
            return
        }

        let dx = mouse.x - anchor.x
        let dy = mouse.y - anchor.y
        let nx = max(-1.0, min(1.0, dx / 220.0))
        let ny = max(-1.0, min(1.0, -dy / 180.0))

        let smoothedX = lookVector.x * 0.65 + nx * 0.35
        let smoothedY = lookVector.y * 0.65 + ny * 0.35
        if abs(smoothedX - lookVector.x) > 0.03 || abs(smoothedY - lookVector.y) > 0.03 {
            lookVector = CGPoint(x: smoothedX, y: smoothedY)
        }
    }

    // MARK: - Autonomous Living Desktop & Habitat Loop!
    private func startLifeLoop() {
        let timer = Timer(timeInterval: 5.5, repeats: true) { [weak self] _ in
            self?.tickAutonomousBehavior()
        }
        RunLoop.main.add(timer, forMode: .common)
        lifeTimer = timer
    }

    private func tickAutonomousBehavior() {
        guard !isDraggingOnDesktop && !isMouthOpenForDrop && !isChasingCursor && !isReturningToNotch else { return }
        guard !GeminiService.shared.isThinking && !GeminiService.shared.isDesktopChatOpen else { return }

        // Don't interrupt an active poke/eat/idle showcase mid-animation!
        if currentAction.isIdleShowActivity || currentAction == .sleeping {
            return
        }
        switch currentAction {
        case .happyPet, .ticklish, .dizzy, .brushed, .eating, .swallowing:
            return
        default:
            break
        }

        if isOnsenMode && !isOnDesktop {
            posX = 0
            currentAction = .chill
            return
        }

        if isOnDesktop {
            // Do NOT interrupt if currently strolling to a spot on desktop
            if DesktopCapyController.shared.isCurrentlyWalking { return }

            let roll = Int.random(in: 0..<12)
            if desktopRoamEnabled && !isOnsenMode && roll < 5 {
                // 1) Stroll autonomously to a new cozy spot on the user's Desktop!
                DesktopCapyController.shared.startAutonomousStroll()
            } else if roll < 10 && !isOnsenMode {
                // 2) Perform a cute autonomous idle activity (coding, tea, butterfly, juggling, bubbles, reading, stretching)!
                performContextualOrRandomIdleActivity(silentSound: true)
            } else if roll == 10 && !MusicService.shared.currentTrack.isPlaying {
                // 3) Take a cozy nap with a poppable sleep bubble!
                currentAction = .sleeping
                if Int.random(in: 0..<2) == 0 {
                    showDesktopBubble("ngantuk dikit..", duration: 2.5)
                }
                scheduleActionReset(after: 9.0)
            } else {
                currentAction = .chill
            }
            return
        }

        // Inside Habitat / Notch behavior
        let roll = Int.random(in: 0..<10)
        if roll < 3 {
            let nextX = CGFloat.random(in: -46...46)
            walkTo(offsetX: nextX)
        } else if roll < 7 {
            performContextualOrRandomIdleActivity(silentSound: true)
        } else if roll == 9 && !MusicService.shared.currentTrack.isPlaying && !TimerService.shared.isRunning {
            currentAction = .sleeping
            scheduleActionReset(after: 7.0)
        } else {
            currentAction = .chill
        }
    }

    /// Picks a smart activity (e.g. coding on mini MacBook when user is in a code editor!) or cycles fun tricks!
    public func performContextualOrRandomIdleActivity(silentSound: Bool = false) {
        if !silentSound {
            NSSound(named: "Pop")?.play()
        }
        registerSquish()

        let appName = NSWorkspace.shared.frontmostApplication?.localizedName?.lowercased() ?? ""
        let isCodingApp = appName.contains("code") || appName.contains("xcode") || appName.contains("cursor")
            || appName.contains("terminal") || appName.contains("iterm") || appName.contains("warp")
            || appName.contains("antigravity")

        let allActivities: [(CapyAction, [String], Double)] = [
            (.sippingTea,      ["anget tehnya..", "nyeruput bentar", "slurrpp.."], 6.5),
            (.butterflyChase,  ["eh ada kupu-kupu", "mau kemana tuh..", "lucu warnanya"], 7.0),
            (.jugglingOranges, ["satu.. dua.. tiga..", "awas jangan jatoh..", "fokus tangkep.."], 7.5),
            (.blowingBubbles,  ["fuuhh..", "melayang jauh.."], 6.5),
            (.typingLaptop,    isCodingApp ? ["ikut ngetik ah..", "fokus dikit..", "lagi sibuk ya?"] : ["cek catatan bentar..", "ketik dikit ah"], 7.0),
            (.readingBook,     ["baca bentar..", "seru juga isinya", "hmm gitu ternyata"], 6.5),
            (.stretching,      ["pegel duduk terus..", "nguap dulu ah", "lumayan pegel nih"], 5.5)
        ]

        var idx: Int
        if isCodingApp && silentSound && Int.random(in: 0..<3) == 0 && lastActivityIndex != 4 {
            idx = 4 // typingLaptop!
        } else {
            repeat {
                idx = Int.random(in: 0..<allActivities.count)
            } while idx == lastActivityIndex && allActivities.count > 1
        }
        lastActivityIndex = idx

        let chosen = allActivities[idx]
        let phrase = chosen.1.randomElement() ?? ""
        if isOnsenMode { isOnsenMode = false }
        currentAction = chosen.0

        // Keep autonomous background chatter light & natural (~45% chance), always speak when user clicked!
        if !silentSound || Int.random(in: 0..<10) < 4 {
            if isOnDesktop {
                showDesktopBubble(phrase, duration: 2.6)
            }
            showBubble(phrase, duration: 2.6)
        }
        if !silentSound {
            showContextualTip(phrase, duration: 2.5)
            xp += 4
        }
        scheduleActionReset(after: chosen.2)
    }

    public func triggerRandomFunActivity() {
        guard !isReturningToNotch else { return }
        isChasingCursor = false
        DesktopCapyController.shared.stopCurrentWalk()
        performContextualOrRandomIdleActivity(silentSound: false)
    }

    public func triggerSpecificActivity(_ action: CapyAction, message: String, duration: Double = 7.5) {
        guard !isReturningToNotch else { return }
        isChasingCursor = false
        DesktopCapyController.shared.stopCurrentWalk()
        NSSound(named: "Pop")?.play()
        registerSquish()
        if isOnsenMode { isOnsenMode = false }
        currentAction = action
        if isOnDesktop {
            showDesktopBubble(message, duration: 2.8)
        }
        showBubble(message, duration: 2.8)
        showContextualTip(message, duration: 2.5)
        xp += 4
        scheduleActionReset(after: duration)
    }

    // MARK: - Interactive "Chase My Cursor!" Mini-Game on Desktop!
    public func toggleChaseCursor() {
        if isChasingCursor {
            stopChaseCursor(caught: false)
        } else {
            startChaseCursor()
        }
    }

    public func startChaseCursor() {
        if isReturningToNotch {
            DesktopCapyController.shared.cancelWalkHomeToNotch()
        }
        if !isOnDesktop {
            releaseToDesktop(at: nil)
        }
        if isOnsenMode { isOnsenMode = false }
        NSSound(named: "Pop")?.play()
        isChasingCursor = true
        currentAction = .walking
        showDesktopBubble("tungguin, ikut..", duration: 2.6)

        chaseStopWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.stopChaseCursor(caught: false)
        }
        chaseStopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 12.0, execute: work)
    }

    public func stopChaseCursor(caught: Bool) {
        guard isChasingCursor else { return }
        chaseStopWork?.cancel()
        isChasingCursor = false
        registerSquish()
        if caught {
            NSSound(named: "Hero")?.play()
            xp += 8
            mood = min(100, mood + 8)
            heartBurstCount += 1
            currentAction = .happyPet
            showDesktopBubble("dapet kursormu hehe", duration: 2.5)
            scheduleActionReset(after: 2.0)
        } else {
            currentAction = .stretching
            showDesktopBubble("hah.. capek juga lari", duration: 2.5)
            scheduleActionReset(after: 2.2)
        }
    }

    // MARK: - Trackpad Two-Finger Fur Brushing / Petting!
    public func strokeFur(delta: CGFloat) {
        guard delta > 0.5 && !isReturningToNotch else { return }
        strokeAccum += delta
        currentAction = .brushed
        if Date().timeIntervalSince(lastStrokeSoundDate) > 0.9 {
            lastStrokeSoundDate = Date()
            NSSound(named: "Tink")?.play()
            mood = min(100, mood + 3)
            xp += 2
            registerSquish()
            let msg = ["wah enak disisir..", "rapi lagi deh bulunya", "hmm lanjut dong.."].randomElement()!
            emitAllBubbles(msg, fromDesktop: isOnDesktop)
        }
        scheduleActionReset(after: 1.4)
    }

    public func walkTo(offsetX: CGFloat) {
        let clamped = max(-52, min(52, offsetX))
        if abs(clamped - posX) < 5 { return }
        facingRight = clamped >= posX
        currentAction = .walking
        posX = clamped
        scheduleActionReset(after: 1.0)
    }

    // MARK: - Progressive Poke & Per-Menu Interaction

    public func registerSquish() {
        lastSquishTime = Date.timeIntervalSinceReferenceDate
    }

    public func interactInTab(_ tab: IslandTab, fromDesktop: Bool = false) {
        guard !isReturningToNotch else { return }
        let now = Date()
        if now.timeIntervalSince(lastPokeDate) < 2.2 {
            pokeStreak += 1
        } else {
            pokeStreak = 1
        }
        lastPokeDate = now
        registerSquish()

        // Pop the cartoon sleep bubble if sleeping!
        if currentAction == .sleeping {
            NSSound(named: "Pop")?.play()
            currentAction = .ticklish
            let wakeMsg = ["eh kaget.. ketiduran tadi", "hmm? udah bangun kok"].randomElement()!
            emitAllBubbles(wakeMsg, fromDesktop: fromDesktop)
            scheduleActionReset(after: 1.8)
            return
        }

        if pokeStreak >= 5 {
            NSSound(named: "Basso")?.play()
            currentAction = .dizzy
            let msg = dizzyQuotes.randomElement()!
            emitAllBubbles(msg, fromDesktop: fromDesktop)
            scheduleActionReset(after: 2.3)
            return
        } else if pokeStreak >= 3 {
            NSSound(named: "Pop")?.play()
            currentAction = .ticklish
            xp += 2
            let msg = ticklishQuotes.randomElement()!
            emitAllBubbles(msg, fromDesktop: fromDesktop)
            scheduleActionReset(after: 1.7)
            return
        }

        NSSound(named: "Tink")?.play()
        mood = min(100, mood + 5)
        xp += 5
        heartBurstCount += 1
        currentAction = .happyPet

        let line: String
        switch tab {
        case .makiLand:
            if MusicService.shared.currentTrack.isPlaying {
                line = ["enak lagunya..", "asik juga iramanya", "santai sambil denger lagu"].randomElement()!
            } else {
                line = ["sepi nih, setel lagu yuk", "lagi santai aja.."].randomElement()!
            }
        case .capy:
            line = petQuotes.randomElement() ?? "adem dielus.."
        case .notes:
            let todos = NotesService.shared.todos
            let remaining = todos.filter { !$0.isDone }.count
            if remaining == 0 && !todos.isEmpty {
                line = "semua tugas udah beres nih"
            } else {
                line = ["pelan-pelan dicicil aja", "jangan lupa dicatat ya"].randomElement()!
            }
        case .launcher:
            line = ["mau buka aplikasi apa?", "tinggal klik aja langsung jalan"].randomElement()!
        case .tray:
            let count = DropZoneService.shared.droppedItems.count
            if DropZoneService.shared.isBusy {
                line = "tunggu bentar lagi diolah.."
            } else if count > 0 {
                line = "tinggal tarik keluar kalau mau pakai"
            } else {
                line = "kasih screenshot ke aku juga bisa"
            }
        case .monitor:
            let cpu = Int(SystemMonitorService.shared.cpuPercent)
            if cpu >= 60 {
                line = "lumayan kerja keras nih mac-nya"
            } else {
                line = "mesinnya masih adem kok"
            }
        case .clipboard:
            line = ["aman, udah kesalin di sini", "klik aja buat salin ulang"].randomElement()!
        case .timer:
            if TimerService.shared.isTimeUpAlert {
                line = "waktunya udah habis, istirahat dulu"
            } else if TimerService.shared.isRunning {
                line = "fokus dulu bentar ya.."
            } else {
                line = "mau mulai fokus pakai timer?"
            }
        }

        emitAllBubbles(line, fromDesktop: fromDesktop)
        scheduleActionReset(after: 1.7)
    }

    public func reactToEvent(_ shortText: String) {
        registerSquish()
        currentAction = .happyPet
        if IslandState.shared.isExpanded {
            showContextualTip(shortText, duration: 2.0)
        }
        scheduleActionReset(after: 1.4)
    }

    public func pet(fromDesktop: Bool = false) {
        interactInTab(.capy, fromDesktop: fromDesktop)
    }

    public func feed(_ food: CapyFood) {
        guard !isReturningToNotch else { return }
        NSSound(named: "Pop")?.play()
        DesktopCapyController.shared.stopCurrentWalk()
        isChasingCursor = false
        registerSquish()
        pokeStreak = 0
        fullness = min(100, fullness + 16)
        mood = min(100, mood + 6)
        xp += 10
        heartBurstCount += 1
        currentAction = .eating(food.emoji)

        let msg: String
        switch food {
        case .orange:     msg = ["manis jeruknya..", "seger banget jeruknya", "nyam.. enak"].randomElement()!
        case .watermelon: msg = ["adem makan semangka..", "manis berair nih"].randomElement()!
        case .greens:     msg = ["kriuk.. sehat juga", "lumayan buat camilan"].randomElement()!
        }
        emitAllBubbles(msg, fromDesktop: isOnDesktop)
        scheduleActionReset(after: 2.3)
    }

    public func cycleOrangeOnHead() {
        NSSound(named: "Pop")?.play()
        registerSquish()
        orangesOnHead = (orangesOnHead + 1) % 4
        xp += 3
        let msg: String
        switch orangesOnHead {
        case 0:  msg = "enteng lagi kepalaku"
        case 1:  msg = "satu jeruk pas di kepala"
        case 2:  msg = "dua jeruk.. tahan jangan goyang"
        default: msg = "tiga jeruk nih, lumayan berat.."
        }
        emitAllBubbles(msg, fromDesktop: isOnDesktop)
    }

    public func toggleOnsen() {
        NSSound(named: "Bottle")?.play()
        DesktopCapyController.shared.stopCurrentWalk()
        isChasingCursor = false
        registerSquish()
        isOnsenMode.toggle()
        if isOnsenMode {
            posX = 0
            currentAction = .chill
            if orangesOnHead == 0 { orangesOnHead = 1 }
            mood = min(100, mood + 10)
            emitAllBubbles("anget banget airnya..", fromDesktop: isOnDesktop)
        } else {
            emitAllBubbles("seger habis berendam", fromDesktop: isOnDesktop)
        }
    }

    // MARK: - Screenshot & File Swallow (Drop Directly Onto Maki -> Ready to Grab in Tray!)

    public func completeSwallowIntoTray(urls: [URL]) {
        guard !urls.isEmpty else { return }
        isMouthOpenForDrop = false
        NSSound(named: "Pop")?.play()
        registerSquish()
        currentAction = .swallowing
        xp += 12
        heartBurstCount += 1

        // Keep Tray on the Shelf view (selectFirstInStudio: false) so screenshots/files can be dragged out or copied right away!
        _ = DropZoneService.shared.addURLs(urls, selectFirstInStudio: false)
        IslandState.shared.selectedTab = .tray
        IslandState.shared.setExpanded(true)

        let msg = ["udah masuk Tray ya, tinggal ambil", "oke kusimpen di Tray, siap dipakai"].randomElement()!
        emitAllBubbles(msg, fromDesktop: isOnDesktop)
        scheduleActionReset(after: 1.8)
    }

    public func catchClipboardOrRecentScreenshot() {
        if let url = DropZoneService.shared.grabLatestScreenshotFromClipboardOrDesktop() {
            completeSwallowIntoTray(urls: [url])
        } else {
            NSSound(named: "Basso")?.play()
            emitAllBubbles("belum nemu screenshot baru nih..", fromDesktop: isOnDesktop)
        }
    }

    public func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        isMouthOpenForDrop = false
        guard !providers.isEmpty else { return false }

        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    var resolved: URL? = nil
                    if let data = item as? Data {
                        resolved = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let url = item as? URL {
                        resolved = url
                    } else if let nsurl = item as? NSURL {
                        resolved = nsurl as URL
                    }
                    if let u = resolved {
                        lock.lock()
                        urls.append(u)
                        lock.unlock()
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
                group.enter()
                provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { data, _ in
                    defer { group.leave() }
                    if let d = data, let saved = DropZoneService.shared.saveImageDataAsScreenshot(d, ext: "png") {
                        lock.lock()
                        urls.append(saved)
                        lock.unlock()
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.tiff.identifier) {
                group.enter()
                provider.loadDataRepresentation(forTypeIdentifier: UTType.tiff.identifier) { data, _ in
                    defer { group.leave() }
                    if let d = data, let saved = DropZoneService.shared.saveImageDataAsScreenshot(d, ext: "png") {
                        lock.lock()
                        urls.append(saved)
                        lock.unlock()
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                group.enter()
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    defer { group.leave() }
                    if let d = data, let saved = DropZoneService.shared.saveImageDataAsScreenshot(d, ext: "png") {
                        lock.lock()
                        urls.append(saved)
                        lock.unlock()
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self, !urls.isEmpty else { return }
            self.completeSwallowIntoTray(urls: urls)
        }
        return true
    }

    // MARK: - Floating Desktop Mode & Walking Back to Notch!

    public func toggleDesktopMode() {
        if isOnDesktop {
            returnToNotch()
        } else {
            releaseToDesktop(at: nil)
        }
    }

    public func releaseToDesktop(at screenPoint: CGPoint?) {
        DesktopCapyController.shared.cancelWalkHomeToNotch()
        isReturningToNotch = false
        notchClimbProgress = 0
        NSSound(named: "Pop")?.play()
        if let pt = screenPoint {
            desktopOrigin = CGPoint(x: pt.x - 95, y: pt.y - 80)
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            isOnDesktop = true
            IslandState.shared.notifySize()
        }
        registerSquish()
        DesktopCapyController.shared.show(at: desktopOrigin)
        showDesktopBubble("main di bawah dulu ya..", duration: 2.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            guard let self = self, self.isOnDesktop, !self.isReturningToNotch, self.currentAction == .chill else { return }
            self.performContextualOrRandomIdleActivity(silentSound: true)
        }
    }

    /// Walks Maki all the way back up to the Notch doorstep and hops inside!
    public func returnToNotch() {
        guard isOnDesktop else { return }
        guard !isReturningToNotch else { return }

        isDraggingOnDesktop = false
        isChasingCursor = false
        notchClimbProgress = 0
        chaseStopWork?.cancel()
        actionResetWork?.cancel()
        if isOnsenMode { isOnsenMode = false }

        if let panel = DesktopCapyController.shared.panel, panel.isVisible {
            isReturningToNotch = true
            currentAction = .walking
            let msg = ["balik ke atas dulu ya..", "pulang ke notch ah..", "ke atas dulu ya"].randomElement()!
            showDesktopBubble(msg, duration: 2.0)
            DesktopCapyController.shared.walkHomeToNotch()
        } else {
            completeReturnToNotchArrival()
        }
    }

    public func completeReturnToNotchArrival() {
        NSSound(named: "Tink")?.play()
        isReturningToNotch = false
        notchClimbProgress = 0
        isDraggingOnDesktop = false
        isChasingCursor = false
        if !showInCompactNotch {
            showInCompactNotch = true
        }
        DesktopCapyController.shared.hide()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            isOnDesktop = false
            IslandState.shared.notifySize()
        }
        currentAction = .chill
        registerSquish()
        showBubble("udah nyampe di atas..", duration: 2.2)
        showContextualTip("udah balik di notch", duration: 2.0)
    }

    // MARK: - Bubbles

    private func emitAllBubbles(_ text: String, fromDesktop: Bool) {
        if fromDesktop || isOnDesktop {
            showDesktopBubble(text)
        }
        showBubble(text)
        showContextualTip(text)
    }

    public func showContextualTip(_ text: String, duration: Double = 2.4) {
        tipDismissWork?.cancel()
        contextualTip = text
        let work = DispatchWorkItem { [weak self] in
            self?.contextualTip = nil
        }
        tipDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    public func showBubble(_ text: String, duration: Double = 2.5) {
        bubbleDismissWork?.cancel()
        speechBubble = text
        let work = DispatchWorkItem { [weak self] in
            self?.speechBubble = nil
        }
        bubbleDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    public func wakeUpFromSleep() {
        actionResetWork?.cancel()
        currentAction = .stretching
        let msg = "Selamat datang kembali! 👋✨"
        speechBubble = msg
        showDesktopBubble(msg, duration: 4.5)
        scheduleActionReset(after: 4.5)
    }

    public func showDesktopBubble(_ text: String, duration: Double = 2.6) {
        desktopBubbleWork?.cancel()
        desktopBubble = text
        let work = DispatchWorkItem { [weak self] in
            self?.desktopBubble = nil
        }
        desktopBubbleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func scheduleActionReset(after seconds: Double) {
        actionResetWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.currentAction = .chill
        }
        actionResetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}
