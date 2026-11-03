import Foundation
import AppKit
import SwiftUI
import Combine

public enum MakiAIProvider: String, CaseIterable, Identifiable, Codable {
    case gemini     = "gemini"
    case groq       = "groq"
    case openai     = "openai"
    case deepseek   = "deepseek"
    case openrouter = "openrouter"
    case anthropic  = "anthropic"
    case ollama     = "ollama"

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .gemini:     return "Google Gemini"
        case .groq:       return "Groq (Super Fast)"
        case .openai:     return "OpenAI"
        case .deepseek:   return "DeepSeek"
        case .openrouter: return "OpenRouter"
        case .anthropic:  return "Anthropic Claude"
        case .ollama:     return "Ollama (Lokal)"
        }
    }

    public var icon: String {
        switch self {
        case .gemini:     return "🌿"
        case .groq:       return "⚡"
        case .openai:     return "🧠"
        case .deepseek:   return "🐋"
        case .openrouter: return "🌐"
        case .anthropic:  return "🎭"
        case .ollama:     return "🦙"
        }
    }

    public var badge: String {
        switch self {
        case .gemini:     return "Official"
        case .groq:       return "Gratis & Kilat"
        case .openai:     return "Populer"
        case .deepseek:   return "Reasoning Hemat"
        case .openrouter: return "All-in-One"
        case .anthropic:  return "Cerdas"
        case .ollama:     return "Offline / Bebas Biaya"
        }
    }

    public var placeholder: String {
        switch self {
        case .gemini:     return "Tempel Gemini API Key (AIza...)"
        case .groq:       return "Tempel Groq API Key (gsk_...)"
        case .openai:     return "Tempel OpenAI API Key (sk-...)"
        case .deepseek:   return "Tempel DeepSeek API Key (sk-...)"
        case .openrouter: return "Tempel OpenRouter API Key (sk-or-...)"
        case .anthropic:  return "Tempel Anthropic API Key (sk-ant-...)"
        case .ollama:     return "URL Host Ollama (default: http://localhost:11434)"
        }
    }

    public var envVar: String {
        switch self {
        case .gemini:     return "GEMINI_API_KEY"
        case .groq:       return "GROQ_API_KEY"
        case .openai:     return "OPENAI_API_KEY"
        case .deepseek:   return "DEEPSEEK_API_KEY"
        case .openrouter: return "OPENROUTER_API_KEY"
        case .anthropic:  return "ANTHROPIC_API_KEY"
        case .ollama:     return "OLLAMA_HOST"
        }
    }
}

public enum MakiGeminiModel: String, CaseIterable, Identifiable, Codable {
    // Google Gemini
    case flash35Lite     = "gemini-3.5-flash-lite"
    case flash38         = "gemini-3.8-flash"
    case flash25         = "gemini-2.5-flash"

    // Groq (Free & Super Fast)
    case groqLlama70     = "groq:llama-3.3-70b-versatile"
    case groqLlama8      = "groq:llama-3.1-8b-instant"

    // OpenAI
    case gpt4oMini       = "openai:gpt-4o-mini"
    case gpt4o           = "openai:gpt-4o"

    // DeepSeek
    case deepseekChat    = "deepseek:deepseek-chat"
    case deepseekR1      = "deepseek:deepseek-reasoner"

    // OpenRouter
    case openrouterLlama = "openrouter:meta-llama/llama-3.3-70b-instruct"
    case openrouterR1    = "openrouter:deepseek/deepseek-r1"

    // Anthropic Claude
    case claudeHaiku     = "anthropic:claude-3-5-haiku-20241022"
    case claudeSonnet    = "anthropic:claude-3-5-sonnet-20241022"

    // Ollama (Local)
    case ollamaLlama     = "ollama:llama3.2"
    case ollamaQwen      = "ollama:qwen2.5"

    public var id: String { rawValue }

    public var provider: MakiAIProvider {
        if rawValue.hasPrefix("groq:") { return .groq }
        if rawValue.hasPrefix("openai:") { return .openai }
        if rawValue.hasPrefix("deepseek:") { return .deepseek }
        if rawValue.hasPrefix("openrouter:") { return .openrouter }
        if rawValue.hasPrefix("anthropic:") { return .anthropic }
        if rawValue.hasPrefix("ollama:") { return .ollama }
        return .gemini
    }

    public var rawModelName: String {
        if let idx = rawValue.firstIndex(of: ":") {
            return String(rawValue[rawValue.index(after: idx)...])
        }
        return rawValue
    }

    public var shortLabel: String {
        switch self {
        case .flash35Lite:     return "Gemini 3.5 Lite"
        case .flash38:         return "Gemini 3.8 Flash"
        case .flash25:         return "Gemini 2.5 Flash"
        case .groqLlama70:     return "Llama 3.3 70B (Groq)"
        case .groqLlama8:      return "Llama 3.1 8B (Groq)"
        case .gpt4oMini:       return "GPT-4o Mini"
        case .gpt4o:           return "GPT-4o"
        case .deepseekChat:    return "DeepSeek V3"
        case .deepseekR1:      return "DeepSeek R1"
        case .openrouterLlama: return "Llama 3.3 (OpenRouter)"
        case .openrouterR1:    return "DeepSeek R1 (OpenRouter)"
        case .claudeHaiku:     return "Claude 3.5 Haiku"
        case .claudeSonnet:    return "Claude 3.5 Sonnet"
        case .ollamaLlama:     return "Llama 3.2 (Ollama)"
        case .ollamaQwen:      return "Qwen 2.5 (Ollama)"
        }
    }

    public var subtitle: String {
        switch self {
        case .flash35Lite:     return "Super Cepat & Ringan"
        case .flash38:         return "Cerdas & Multimodal"
        case .flash25:         return "Hemat & Multimodal"
        case .groqLlama70:     return "Free Tier & Super Kencang ⚡"
        case .groqLlama8:      return "Respon Kilat"
        case .gpt4oMini:       return "Cerdas & Hemat Token"
        case .gpt4o:           return "Flagship Multimodal"
        case .deepseekChat:    return "Pintar & Terjangkau"
        case .deepseekR1:      return "Penalaran Berpikir Mendalam"
        case .openrouterLlama: return "Universal Multi-Model"
        case .openrouterR1:    return "Reasoning via OpenRouter"
        case .claudeHaiku:     return "Kreatif & Gesit"
        case .claudeSonnet:    return "Coding & Analisis Terbaik"
        case .ollamaLlama:     return "Offline di Mac via Ollama"
        case .ollamaQwen:      return "Offline di Mac via Ollama"
        }
    }
}

public struct MakiChatAttachment: Equatable {
    public let id: UUID
    public let name: String
    public let mimeType: String
    public let base64Data: String
    public let thumbnail: NSImage
    public let sourceURL: URL?

    public init(
        id: UUID = UUID(),
        name: String,
        mimeType: String,
        base64Data: String,
        thumbnail: NSImage,
        sourceURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.base64Data = base64Data
        self.thumbnail = thumbnail
        self.sourceURL = sourceURL
    }

    public static func == (lhs: MakiChatAttachment, rhs: MakiChatAttachment) -> Bool {
        lhs.id == rhs.id
    }
}

public struct MakiChatMessage: Identifiable, Codable, Equatable {
    public enum Sender: String, Codable {
        case user
        case maki
        case error
    }

    public var id: UUID
    public var sender: Sender
    public var text: String
    public var timestamp: Date
    public var attachedImageName: String?
    public var attachedImagePath: String?
    public var modelUsed: String?

    public init(
        id: UUID = UUID(),
        sender: Sender,
        text: String,
        timestamp: Date = Date(),
        attachedImageName: String? = nil,
        attachedImagePath: String? = nil,
        modelUsed: String? = nil
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.attachedImageName = attachedImageName
        self.attachedImagePath = attachedImagePath
        self.modelUsed = modelUsed
    }
}

private struct GeminiLocalConfig: Codable {
    var apiKey: String?
    var providerKeys: [String: String]?
    var selectedModel: String
}

private struct InteractionResponsePayload: Decodable {
    struct Step: Decodable {
        struct ContentPart: Decodable {
            let type: String?
            let text: String?
        }
        let type: String?
        let content: [ContentPart]?
    }

    struct APIErrorDetail: Decodable {
        let message: String?
        let code: String?
    }

    let id: String?
    let status: String?
    let model: String?
    let steps: [Step]?
    let error: APIErrorDetail?
}

public class GeminiService: ObservableObject {
    public static let shared = GeminiService()

    @Published public var messages: [MakiChatMessage] = []
    @Published public var isThinking: Bool = false
    @Published public var pendingAttachment: MakiChatAttachment? = nil

    @Published public var selectedModel: MakiGeminiModel = .flash35Lite {
        didSet {
            saveConfig()
        }
    }

    @Published public var isNotchChatMode: Bool = false {
        didSet {
            if oldValue != isNotchChatMode {
                IslandState.shared.notifySize()
            }
        }
    }

    @Published public var isDesktopChatOpen: Bool = false {
        didSet {
            if oldValue != isDesktopChatOpen {
                DesktopCapyController.shared.handleDesktopChatVisibilityChanged(isDesktopChatOpen)
            }
        }
    }

    @Published public var isShowingSettings: Bool = false
    @Published public private(set) var apiKey: String = ""
    @Published public private(set) var providerKeys: [String: String] = [:]

    public let focusInputTrigger = PassthroughSubject<Void, Never>()

    private var lastInteractionId: String? = nil
    private var lastInteractionModel: String? = nil
    private var currentTask: Task<Void, Never>? = nil

    private var appSupportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("DynamicIsland", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var configFileURL: URL {
        appSupportDir.appendingPathComponent("gemini_config.json")
    }

    private var historyFileURL: URL {
        appSupportDir.appendingPathComponent("maki_chat_history.json")
    }

    public func effectiveKey(for provider: MakiAIProvider) -> String {
        if let direct = providerKeys[provider.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines), !direct.isEmpty {
            return direct
        }
        if provider == .gemini {
            let leg = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !leg.isEmpty { return leg }
            if let env = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines), !env.isEmpty {
                return env
            }
        } else if let env = ProcessInfo.processInfo.environment[provider.envVar]?.trimmingCharacters(in: .whitespacesAndNewlines), !env.isEmpty {
            return env
        } else if provider == .ollama {
            return "http://localhost:11434"
        }
        return ""
    }

    public func hasKey(for provider: MakiAIProvider) -> Bool {
        if provider == .ollama { return true }
        return !effectiveKey(for: provider).isEmpty
    }

    public func maskedKey(for provider: MakiAIProvider) -> String {
        if provider == .ollama {
            let u = effectiveKey(for: .ollama)
            return u.isEmpty ? "http://localhost:11434" : u
        }
        let k = effectiveKey(for: provider)
        guard !k.isEmpty else { return "Belum diatur" }
        if k.count <= 10 {
            return String(repeating: "•", count: k.count)
        }
        let prefix = k.prefix(6)
        let suffix = k.suffix(4)
        return "\(prefix)••••••••\(suffix)"
    }

    public var effectiveAPIKey: String {
        effectiveKey(for: selectedModel.provider)
    }

    public var hasAPIKey: Bool {
        hasKey(for: selectedModel.provider)
    }

    public var maskedAPIKey: String {
        maskedKey(for: selectedModel.provider)
    }

    private init() {
        loadConfig()
        loadHistory()
    }

    // MARK: - Config & History Persistence

    private func loadConfig() {
        if let data = try? Data(contentsOf: configFileURL),
           let decoded = try? JSONDecoder().decode(GeminiLocalConfig.self, from: data) {
            if let leg = decoded.apiKey {
                self.apiKey = leg.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let pk = decoded.providerKeys {
                self.providerKeys = pk
            }
            if let m = MakiGeminiModel(rawValue: decoded.selectedModel) {
                self.selectedModel = m
            }
        }
    }

    private func saveConfig() {
        let cfg = GeminiLocalConfig(apiKey: apiKey, providerKeys: providerKeys, selectedModel: selectedModel.rawValue)
        guard let data = try? JSONEncoder().encode(cfg) else { return }
        try? data.write(to: configFileURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configFileURL.path)
    }

    public func updateKey(_ newKey: String, for provider: MakiAIProvider) {
        let clean = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        providerKeys[provider.rawValue] = clean
        if provider == .gemini {
            apiKey = clean
        }
        lastInteractionId = nil
        lastInteractionModel = nil
        saveConfig()
    }

    public func clearKey(for provider: MakiAIProvider) {
        providerKeys.removeValue(forKey: provider.rawValue)
        if provider == .gemini {
            apiKey = ""
        }
        lastInteractionId = nil
        lastInteractionModel = nil
        saveConfig()
    }

    public func updateAPIKey(_ newKey: String) {
        updateKey(newKey, for: selectedModel.provider)
    }

    public func clearAPIKey() {
        clearKey(for: selectedModel.provider)
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyFileURL),
              let saved = try? JSONDecoder().decode([MakiChatMessage].self, from: data) else {
            return
        }
        messages = Array(saved.suffix(24))
    }

    private func saveHistory() {
        let trimmed = Array(messages.suffix(24))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        try? data.write(to: historyFileURL, options: .atomic)
    }

    public func startNewConversation() {
        currentTask?.cancel()
        currentTask = nil
        isThinking = false
        messages.removeAll()
        pendingAttachment = nil
        lastInteractionId = nil
        lastInteractionModel = nil
        saveHistory()
        CapybaraService.shared.reactToEvent("siap, ngobrol topik baru yuk")
    }

    /// Explicitly cancels ongoing Gemini thinking / generation request.
    public func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
        isThinking = false
        CapybaraService.shared.currentAction = .chill
        CapybaraService.shared.reactToEvent("dibatalkan yaa")
    }

    // MARK: - Quick Entry Helpers (Notch & Desktop)

    public func openChatInNotch(attaching item: DroppedItem? = nil) {
        if let item = item, item.kind == .image {
            _ = attachImage(from: item.url)
        }
        isNotchChatMode = true
        if IslandState.shared.selectedTab != .capy {
            IslandState.shared.selectedTab = .capy
        }
        if !IslandState.shared.isExpanded {
            IslandState.shared.setExpanded(true)
        } else {
            IslandState.shared.notifySize()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
            self?.focusInputTrigger.send(())
        }
    }

    public func toggleDesktopChat() {
        isDesktopChatOpen.toggle()
        if isDesktopChatOpen {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                self?.focusInputTrigger.send(())
            }
        }
    }

    // MARK: - Image / Screenshot Attachment Helpers

    @discardableResult
    public func attachLatestScreenshotOrClipboard() -> Bool {
        // 1. Check if clipboard currently holds raw image pixels (e.g. ⌘⌃⇧4)
        let pb = NSPasteboard.general
        if let rawImg = NSImage(pasteboard: pb), rawImg.size.width > 4 {
            return attachNSImage(rawImg, name: "Clipboard Screenshot")
        }

        // 2. Check latest image in Tray (DropZoneService)
        if let latestTrayImg = DropZoneService.shared.droppedItems.first(where: { $0.kind == .image }) {
            return attachImage(from: latestTrayImg.url)
        }

        // 3. Check macOS recent screenshot on Desktop / Screencapture location
        if let recentURL = findRecentSystemScreenshot() {
            return attachImage(from: recentURL)
        }

        return false
    }

    @discardableResult
    public func attachImage(from url: URL) -> Bool {
        guard let img = NSImage(contentsOf: url), img.size.width > 1 else { return false }
        return attachNSImage(img, name: url.lastPathComponent, sourceURL: url)
    }

    @discardableResult
    public func attachNSImage(_ image: NSImage, name: String, sourceURL: URL? = nil) -> Bool {
        guard let encoded = Self.encodeResizedJPEG(from: image, maxDimension: 1280, quality: 0.82) else {
            return false
        }
        pendingAttachment = MakiChatAttachment(
            name: name,
            mimeType: "image/jpeg",
            base64Data: encoded.base64EncodedString(),
            thumbnail: image,
            sourceURL: sourceURL
        )
        NSSound(named: "Tink")?.play()
        return true
    }

    public func pickImageAttachmentFromFinder() {
        IslandState.shared.isModalOpen = true
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Lampirkan"
        panel.message = "Pilih gambar atau screenshot untuk ditanyakan ke Maki"
        panel.begin { [weak self] resp in
            DispatchQueue.main.async {
                IslandState.shared.isModalOpen = false
                if resp == .OK, let url = panel.url {
                    _ = self?.attachImage(from: url)
                }
            }
        }
    }

    private func findRecentSystemScreenshot() -> URL? {
        let customLoc = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
        let folderPath = (customLoc as NSString?)?.expandingTildeInPath
            ?? (NSHomeDirectory() as NSString).appendingPathComponent("Desktop")
        let folderURL = URL(fileURLWithPath: folderPath, isDirectory: true)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let imgExts: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff"]
        let candidates = urls.filter { u in
            let lower = u.lastPathComponent.lowercased()
            return imgExts.contains(u.pathExtension.lowercased()) &&
                (lower.contains("screenshot") || lower.contains("screen shot") || lower.contains("tangkapan layar"))
        }

        return candidates.max { a, b in
            let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return da < db
        }
    }

    private static func encodeResizedJPEG(from image: NSImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        var targetRect = NSRect(origin: .zero, size: image.size)
        guard let cgImg = image.cgImage(forProposedRect: &targetRect, context: nil, hints: nil) else {
            return nil
        }

        let srcW = CGFloat(cgImg.width)
        let srcH = CGFloat(cgImg.height)
        guard srcW > 0, srcH > 0 else { return nil }

        let scale = min(1.0, maxDimension / max(srcW, srcH))
        let dstW = max(1, Int(round(srcW * scale)))
        let dstH = max(1, Int(round(srcH * scale)))

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                  data: nil,
                  width: dstW,
                  height: dstH,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        ctx.interpolationQuality = .high
        ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: dstW, height: dstH))
        guard let scaledCG = ctx.makeImage() else { return nil }

        let rep = NSBitmapImageRep(cgImage: scaledCG)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    // MARK: - Send Message to Gemini Interactions API (`v1beta/interactions`)

    public func sendMessage(_ rawPrompt: String) {
        let trimmed = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachment = pendingAttachment

        guard !trimmed.isEmpty || attachment != nil else { return }
        guard !isThinking else { return }

        let prov = selectedModel.provider
        guard hasKey(for: prov) else {
            isShowingSettings = true
            messages.append(
                MakiChatMessage(
                    sender: .error,
                    text: "API Key untuk \(prov.name) belum diatur nih! Klik ikon 🔑 di atas buat masukkan key ya~ 🐾"
                )
            )
            return
        }

        let userText = trimmed.isEmpty ? "Tolong jelaskan isi gambar ini secara ringkas dan jelas." : trimmed
        let priorMessagesSnapshot = messages

        let userMsg = MakiChatMessage(
            sender: .user,
            text: userText,
            attachedImageName: attachment?.name,
            attachedImagePath: attachment?.sourceURL?.path
        )
        messages.append(userMsg)
        pendingAttachment = nil
        saveHistory()

        isThinking = true

        // Animate Maki while thinking!
        let capy = CapybaraService.shared
        capy.currentAction = (attachment != nil) ? .readingBook : .typingLaptop
        if capy.isOnDesktop && !isDesktopChatOpen {
            capy.showDesktopBubble(attachment != nil ? "bentar kulihat gambarnya.." : "bentar mikir dulu..", duration: 4.0)
        }

        let activeKey = effectiveAPIKey
        let systemPrompt = buildSystemInstruction()
        let preferredModel = selectedModel

        currentTask = Task { [weak self] in
            guard let self = self else { return }

            let result: Result<InteractionReply, MakiGeminiError>
            if preferredModel.provider == .anthropic {
                result = await self.sendAnthropicRequest(
                    apiKey: activeKey,
                    modelName: preferredModel.rawModelName,
                    systemInstruction: systemPrompt,
                    userText: userText,
                    attachment: attachment,
                    priorHistory: priorMessagesSnapshot
                )
            } else if preferredModel.provider == .groq || preferredModel.provider == .openai || preferredModel.provider == .deepseek || preferredModel.provider == .openrouter || preferredModel.provider == .ollama {
                result = await self.sendOpenAICompatibleRequest(
                    provider: preferredModel.provider,
                    apiKey: activeKey,
                    modelName: preferredModel.rawModelName,
                    systemInstruction: systemPrompt,
                    userText: userText,
                    attachment: attachment,
                    priorHistory: priorMessagesSnapshot
                )
            } else {
                result = await self.performInteractionWithFallback(
                    apiKey: activeKey,
                    preferredModel: preferredModel,
                    systemInstruction: systemPrompt,
                    userText: userText,
                    attachment: attachment,
                    priorHistory: priorMessagesSnapshot
                )
            }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.isThinking = false

                switch result {
                case .success(let reply):
                    self.lastInteractionId = reply.interactionId
                    self.lastInteractionModel = reply.modelUsed

                    let makiMsg = MakiChatMessage(
                        sender: .maki,
                        text: reply.text,
                        modelUsed: reply.modelUsed
                    )
                    self.messages.append(makiMsg)
                    self.saveHistory()

                    NSSound(named: "Pop")?.play()
                    let capy = CapybaraService.shared
                    capy.xp += 4
                    capy.mood = min(100, capy.mood + 2)
                    capy.currentAction = .happyPet
                    capy.registerSquish()

                    // Show short natural bubble if Desktop Chat card isn't currently expanded
                    if capy.isOnDesktop && !self.isDesktopChatOpen {
                        let preview = Self.shortBubblePreview(from: reply.text)
                        capy.showDesktopBubble(preview, duration: 4.2)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        if capy.currentAction == .happyPet {
                            capy.currentAction = .chill
                        }
                    }

                case .failure(let err):
                    let errMsg = MakiChatMessage(
                        sender: .error,
                        text: err.localizedDescription
                    )
                    self.messages.append(errMsg)
                    self.saveHistory()
                    let capy = CapybaraService.shared
                    if capy.currentAction == .typingLaptop || capy.currentAction == .readingBook {
                        capy.currentAction = .chill
                    }
                }
            }
        }
    }

    private struct InteractionReply {
        let text: String
        let interactionId: String?
        let modelUsed: String
    }

    private struct MakiGeminiError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: - Multi-Provider Dispatchers (OpenAI-Compatible & Anthropic)

    private func sendOpenAICompatibleRequest(
        provider: MakiAIProvider,
        apiKey: String,
        modelName: String,
        systemInstruction: String,
        userText: String,
        attachment: MakiChatAttachment?,
        priorHistory: [MakiChatMessage]
    ) async -> Result<InteractionReply, MakiGeminiError> {
        var endpointStr = "https://api.openai.com/v1/chat/completions"
        if provider == .groq { endpointStr = "https://api.groq.com/openai/v1/chat/completions" }
        else if provider == .deepseek { endpointStr = "https://api.deepseek.com/chat/completions" }
        else if provider == .openrouter { endpointStr = "https://openrouter.ai/api/v1/chat/completions" }
        else if provider == .ollama {
            let base = apiKey.isEmpty ? "http://localhost:11434" : apiKey.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            endpointStr = "\(base)/v1/chat/completions"
        }

        guard let url = URL(string: endpointStr) else {
            return .failure(MakiGeminiError(message: "URL endpoint invalid untuk \(provider.name)"))
        }

        var messagesPayload: [[String: Any]] = [
            ["role": "system", "content": systemInstruction]
        ]

        let validTurns = priorHistory.filter { $0.sender == .user || $0.sender == .maki }.suffix(8)
        for turn in validTurns {
            messagesPayload.append([
                "role": turn.sender == .user ? "user" : "assistant",
                "content": turn.text
            ])
        }

        if let att = attachment {
            let dataUrl = "data:\(att.mimeType);base64,\(att.base64Data)"
            messagesPayload.append([
                "role": "user",
                "content": [
                    ["type": "image_url", "image_url": ["url": dataUrl]],
                    ["type": "text", "text": userText]
                ]
            ])
        } else {
            messagesPayload.append(["role": "user", "content": userText])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey.isEmpty ? "ollama" : apiKey)", forHTTPHeaderField: "Authorization")
        if provider == .openrouter {
            request.setValue("https://makiland.app", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Maki-Land", forHTTPHeaderField: "X-Title")
        }

        let body: [String: Any] = [
            "model": modelName,
            "messages": messagesPayload,
            "max_tokens": 3000
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return .failure(MakiGeminiError(message: "Gagal membuat body request JSON"))
        }
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(MakiGeminiError(message: "Respons invalid dari \(provider.name)"))
            }

            guard (200...299).contains(http.statusCode) else {
                let errText = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                if http.statusCode == 401 || http.statusCode == 403 {
                    return .failure(MakiGeminiError(message: "API Key \(provider.name) salah / ditolak (\(http.statusCode)). Cek menu 🔑 ya!\n\(errText)"))
                }
                return .failure(MakiGeminiError(message: "Gagal memproses (\(http.statusCode)): \(errText)"))
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String,
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .failure(MakiGeminiError(message: "Respons dari \(provider.name) kosong."))
            }

            return .success(InteractionReply(
                text: content.trimmingCharacters(in: .whitespacesAndNewlines),
                interactionId: nil,
                modelUsed: "\(provider.rawValue):\(modelName)"
            ))
        } catch {
            return .failure(MakiGeminiError(message: "Koneksi ke \(provider.name) gagal: \(error.localizedDescription)"))
        }
    }

    private func sendAnthropicRequest(
        apiKey: String,
        modelName: String,
        systemInstruction: String,
        userText: String,
        attachment: MakiChatAttachment?,
        priorHistory: [MakiChatMessage]
    ) async -> Result<InteractionReply, MakiGeminiError> {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return .failure(MakiGeminiError(message: "URL endpoint invalid untuk Anthropic"))
        }

        var messagesPayload: [[String: Any]] = []
        let validTurns = priorHistory.filter { $0.sender == .user || $0.sender == .maki }.suffix(6)
        for turn in validTurns {
            messagesPayload.append([
                "role": turn.sender == .user ? "user" : "assistant",
                "content": turn.text
            ])
        }

        if let att = attachment {
            messagesPayload.append([
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": att.mimeType,
                            "data": att.base64Data
                        ]
                    ],
                    ["type": "text", "text": userText]
                ]
            ])
        } else {
            messagesPayload.append(["role": "user", "content": userText])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": modelName,
            "max_tokens": 3000,
            "system": systemInstruction,
            "messages": messagesPayload
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return .failure(MakiGeminiError(message: "Gagal membuat body JSON untuk Claude"))
        }
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(MakiGeminiError(message: "Respons invalid dari Anthropic"))
            }

            guard (200...299).contains(http.statusCode) else {
                let errText = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                if http.statusCode == 401 || http.statusCode == 403 {
                    return .failure(MakiGeminiError(message: "API Key Anthropic salah / ditolak (\(http.statusCode)). Cek menu 🔑 ya!\n\(errText)"))
                }
                return .failure(MakiGeminiError(message: "Gagal dari Anthropic (\(http.statusCode)): \(errText)"))
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let contentArray = json["content"] as? [[String: Any]] else {
                return .failure(MakiGeminiError(message: "Format respons Claude tidak sesuai."))
            }

            let textParts = contentArray.compactMap { part -> String? in
                if (part["type"] as? String) == "text" {
                    return part["text"] as? String
                }
                return nil
            }
            let fullReply = textParts.joined().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fullReply.isEmpty else {
                return .failure(MakiGeminiError(message: "Respons Claude kosong."))
            }

            return .success(InteractionReply(
                text: fullReply,
                interactionId: nil,
                modelUsed: "anthropic:\(modelName)"
            ))
        } catch {
            return .failure(MakiGeminiError(message: "Koneksi ke Anthropic gagal: \(error.localizedDescription)"))
        }
    }

    private func candidateModels(startingWith preferred: MakiGeminiModel) -> [String] {
        var ordered = [
            preferred.rawValue,
            MakiGeminiModel.flash35Lite.rawValue,
            MakiGeminiModel.flash38.rawValue,
            "gemini-3.1-flash-lite"
        ]
        var seen = Set<String>()
        ordered = ordered.filter { m in
            if seen.contains(m) { return false }
            seen.insert(m)
            return true
        }
        return ordered
    }

    private func performInteractionWithFallback(
        apiKey: String,
        preferredModel: MakiGeminiModel,
        systemInstruction: String,
        userText: String,
        attachment: MakiChatAttachment?,
        priorHistory: [MakiChatMessage]
    ) async -> Result<InteractionReply, MakiGeminiError> {
        let models = candidateModels(startingWith: preferredModel)
        var lastErrorMsg = "Koneksi ke Gemini gagal. Coba lagi sebentar ya."

        for modelName in models {
            if Task.isCancelled {
                return .failure(MakiGeminiError(message: "Permintaan dibatalkan."))
            }

            // Use stateful server-side `previous_interaction_id` when continuing on the same model
            let canReuseInteractionId = (lastInteractionId != nil && lastInteractionModel == modelName)
            let prevIdToUse = canReuseInteractionId ? lastInteractionId : nil
            let contextualizedText = (prevIdToUse == nil)
                ? injectLocalHistoryIfNeeded(userText: userText, history: priorHistory)
                : userText

            let attempt = await sendSingleInteractionRequest(
                apiKey: apiKey,
                model: modelName,
                systemInstruction: systemInstruction,
                promptText: contextualizedText,
                attachment: attachment,
                previousInteractionId: prevIdToUse
            )

            switch attempt {
            case .success(let reply):
                return .success(reply)

            case .retryWithoutPreviousId:
                // Expired or mismatched previous_interaction_id -> retry immediately with local history context
                let fallbackText = injectLocalHistoryIfNeeded(userText: userText, history: priorHistory)
                let secondTry = await sendSingleInteractionRequest(
                    apiKey: apiKey,
                    model: modelName,
                    systemInstruction: systemInstruction,
                    promptText: fallbackText,
                    attachment: attachment,
                    previousInteractionId: nil
                )
                if case .success(let reply) = secondTry {
                    return .success(reply)
                } else if case .fatalError(let msg) = secondTry {
                    return .failure(MakiGeminiError(message: msg))
                } else if case .overloadOrRateLimit(let msg) = secondTry {
                    lastErrorMsg = msg
                    continue
                }

            case .overloadOrRateLimit(let msg):
                // 503 high demand / 429 -> seamlessly try next fast model in chain!
                lastErrorMsg = msg
                continue

            case .fatalError(let msg):
                return .failure(MakiGeminiError(message: msg))
            }
        }

        return .failure(MakiGeminiError(message: lastErrorMsg))
    }

    private enum SingleAttemptOutcome {
        case success(InteractionReply)
        case retryWithoutPreviousId
        case overloadOrRateLimit(String)
        case fatalError(String)
    }

    private func sendSingleInteractionRequest(
        apiKey: String,
        model: String,
        systemInstruction: String,
        promptText: String,
        attachment: MakiChatAttachment?,
        previousInteractionId: String?
    ) async -> SingleAttemptOutcome {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions") else {
            return .fatalError("URL endpoint Gemini tidak valid.")
        }

        var inputParts: [[String: Any]] = []
        if let att = attachment {
            inputParts.append([
                "type": "image",
                "data": att.base64Data,
                "mime_type": att.mimeType
            ])
        }
        inputParts.append([
            "type": "text",
            "text": promptText
        ])

        let thinkingLevel: String
        if model.contains("flash-lite") {
            thinkingLevel = "minimal"
        } else {
            thinkingLevel = "low"
        }

        var body: [String: Any] = [
            "model": model,
            "system_instruction": systemInstruction,
            "generation_config": [
                "thinking_level": thinkingLevel,
                "max_output_tokens": 4096
            ],
            "input": inputParts
        ]

        if let prevId = previousInteractionId, !prevId.isEmpty {
            body["previous_interaction_id"] = prevId
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return .fatalError("Gagal menyiapkan data permintaan ke Gemini.")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 22
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("2026-05-20", forHTTPHeaderField: "Api-Revision")
        req.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let decoded = try? JSONDecoder().decode(InteractionResponsePayload.self, from: data)

            if statusCode >= 200 && statusCode < 300 {
                let text = Self.extractModelOutputText(from: decoded)
                if text.isEmpty {
                    return .fatalError("Maki bingung mau jawab apa barusan (respons kosong). Coba tanya ulang ya!")
                }
                return .success(
                    InteractionReply(
                        text: text,
                        interactionId: decoded?.id,
                        modelUsed: decoded?.model ?? model
                    )
                )
            }

            let serverMsg = decoded?.error?.message ?? String(data: data, encoding: .utf8) ?? "HTTP \(statusCode)"

            if (statusCode == 400 || statusCode == 404), previousInteractionId != nil {
                return .retryWithoutPreviousId
            }

            if statusCode == 503 || statusCode == 429 || statusCode == 500 {
                return .overloadOrRateLimit("Server Gemini lagi padat (\(statusCode)). Mencoba model alternatif...")
            }

            if statusCode == 401 || statusCode == 403 {
                return .fatalError("API Key Gemini ditolak (\(statusCode)). Cek kembali key di menu 🔑 ya! Detail: \(serverMsg)")
            }

            return .fatalError("Gagal memproses jawaban (\(statusCode)): \(serverMsg)")
        } catch let urlErr as URLError where urlErr.code == .cancelled {
            return .fatalError("Permintaan dibatalkan.")
        } catch let urlErr as URLError where urlErr.code == .timedOut || urlErr.code == .networkConnectionLost {
            return .overloadOrRateLimit("Model \(model) melebihi batas waktu (timeout). Mencoba model alternatif...")
        } catch {
            return .fatalError("Tidak bisa terhubung ke internet / Gemini: \(error.localizedDescription)")
        }
    }

    private static func extractModelOutputText(from payload: InteractionResponsePayload?) -> String {
        guard let steps = payload?.steps else { return "" }
        var chunks: [String] = []
        for step in steps where step.type == "model_output" {
            guard let content = step.content else { continue }
            for part in content where part.type == "text" {
                if let t = part.text, !t.isEmpty {
                    chunks.append(t)
                }
            }
        }
        return chunks.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func injectLocalHistoryIfNeeded(userText: String, history: [MakiChatMessage]) -> String {
        let validTurns = history
            .filter { $0.sender == .user || $0.sender == .maki }
            .suffix(6)
        guard !validTurns.isEmpty else { return userText }

        var lines: [String] = ["[Konteks percakapan sebelumnya antara Pengguna dan Maki:]"]
        for turn in validTurns {
            let roleName = (turn.sender == .user) ? "Pengguna" : "Maki"
            let clipped = String(turn.text.prefix(500))
            lines.append("\(roleName): \(clipped)")
        }
        lines.append("\n[Pesan terbaru Pengguna:]\n\(userText)")
        return lines.joined(separator: "\n")
    }

    // MARK: - Maki Persona + Live `maki-land` Workspace Context

    private func buildSystemInstruction() -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "id_ID")
        df.dateFormat = "EEEE, d MMMM yyyy HH:mm"
        let nowStr = df.string(from: Date())

        let capy = CapybaraService.shared
        let music = MusicService.shared.currentTrack
        let events = CalendarService.shared.events(for: Date())
        let todos = NotesService.shared.todos
        let scratch = NotesService.shared.scratchpadText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trayItems = DropZoneService.shared.droppedItems
        let sys = SystemMonitorService.shared
        let timer = TimerService.shared

        var ctxLines: [String] = []
        ctxLines.append("- Waktu lokal: \(nowStr)")
        ctxLines.append("- Status Maki: Level \(capy.level), Mood \(capy.mood)%, Kenyang \(capy.fullness)%, Jeruk di kepala: \(capy.orangesOnHead), Posisi: \(capy.isOnDesktop ? "sedang main di Desktop" : "sedang nongkrong di dalam Notch")")

        if music.isPlaying && !music.title.isEmpty {
            ctxLines.append("- Musik sedang diputar: \"\(music.title)\" oleh \(music.artist.isEmpty ? "Unknown" : music.artist) (\(music.displayAppName))")
        }

        if !events.isEmpty {
            let evSummary = events.prefix(5).map { "\($0.timeLabel) \($0.title)" }.joined(separator: "; ")
            ctxLines.append("- Jadwal Kalender hari ini: \(evSummary)")
        } else {
            ctxLines.append("- Jadwal Kalender hari ini: Kosong / tidak ada jadwal")
        }

        let pendingTodos = todos.filter { !$0.isDone }
        if !pendingTodos.isEmpty {
            let todoSummary = pendingTodos.prefix(6).map { $0.title }.joined(separator: "; ")
            ctxLines.append("- To-Do belum selesai (\(pendingTodos.count)): \(todoSummary)")
        }
        if !scratch.isEmpty {
            ctxLines.append("- Cuplikan Scratchpad Notes: \(String(scratch.prefix(180)))")
        }

        if !trayItems.isEmpty {
            let traySummary = trayItems.prefix(4).map { "\($0.name) (\($0.kind.badgeText))" }.joined(separator: ", ")
            ctxLines.append("- File di Tray saat ini: \(traySummary)")
        }

        if timer.isRunning {
            ctxLines.append("- Timer Fokus sedang jalan (\(timer.formattedTime) tersisa)")
        }
        ctxLines.append(String(format: "- Sistem Mac: CPU %.0f%%, RAM %.1f/%.0f GB", sys.cpuPercent, sys.ramUsedGB, max(1, sys.ramTotalGB)))

        let cleaner = CacheCleanerManager.shared
        if cleaner.hasCompletedInitialScan {
            ctxLines.append("- Pembersih Cache Mac (Maki Clean): Terdeteksi \(cleaner.formattedTotalSafeSize) sampah cache aman (Browser, Logs, Xcode DerivedData). Maki bisa membersihkannya kapan saja via tombol sapu 🧹 di dock desktop atau tab System.")
        }

        let appKnowledge = """
        Pengetahuan tentang dirimu & aplikasi maki-land (jelaskan HANYA bila pengguna bertanya "kamu apa", "ini aplikasi apa", "fitur apa saja", cara pakai, dsb. Jangan mengarang fitur di luar daftar ini):
        - maki-land adalah aplikasi Dynamic Island interaktif di tengah atas layar Mac (di bawah notch MacBook atau tengah atas monitor eksternal) dengan maskot capybara bernama Maki yang hidup. Maki juga bisa keluar dan berkeliaran di Desktop. Gratis & open source (MIT License). Tersedia untuk macOS dan Windows 10/11.
        - Tanya Maki (kamu sendiri): chat AI serbaguna (Google Gemini, Groq, OpenAI, DeepSeek, OpenRouter, Anthropic, Ollama). Bisa tanya apa saja (jadwal, kode, ide, rangkuman, status sistem, pembersih cache), melampirkan screenshot/gambar untuk dijelaskan (tombol kamera, paste, atau drag & drop file), memilih model AI lewat pill model di header, tombol "Salin Jawaban" untuk menyalin jawaban, tombol "Batal" untuk menghentikan jawaban, tombol obrolan baru, dan pengaturan API Key (disimpan lokal). Kamu juga tahu konteks live aplikasi: lagu, jadwal, To-Do, file di Tray, timer, statistik sistem, dan cache.
        - Pembersih Cache Aman (Maki Clean): memindai dan membersihkan sampah cache Mac dengan aman (hanya dipindahkan ke Tong Sampah Mac / Trash, tidak pernah rm -rf). Bisa diakses lewat tombol sapu 🧹 di dock desktop, tab System di Dynamic Island, atau langsung minta ke kamu di chat Tanya Maki.
        - Maki di Desktop: bisa diseret, diklik untuk dielus, klik dua kali untuk atraksi, jalan-jalan sendiri, mengejar kursor, dikasih jeruk, berendam di onsen, sapu-sapu cache 🧹, atau pulang ke notch. Ada dock kecil saat kursor di dekat Maki: 💬 Tanya Maki, 📸 ambil screenshot ke Tray, 🎪 atraksi acak, 🐾 main kejar kursor, 🍊 kasih jeruk, ♨️ onsen, 🧹 sapu cache aman, 🚶/📌 bebas jalan atau kunci posisi, 🏠 pulang ke notch. Maki punya status mood & kenyang serta level, dan tampilan maskot (klasik atau boneka).
        - Tab di Dynamic Island: maki-land (ringkasan: musik, kalender, baterai), Capy (habitat Maki + Tanya AI), Notes (Scratchpad + To-Do + pintasan), Launch (peluncur cepat aplikasi & web favorit), Tray (tempat menaruh file/screenshot + PDF Studio: convert & kompres, edit & pisah halaman, watermark & kunci), System (CPU, RAM, jaringan + Pembersih Cache Aman 🧹), Clipboard (riwayat salinan, tinggal paste), Timer (timer fokus/Pomodoro dengan notifikasi saat selesai).
        - Kalender bisa disambungkan ke iOS/iCloud dan Google Calendar. Widget musik menampilkan lagu yang sedang diputar. Maki juga bisa menerima file yang di-drag ke mulutnya atau ke notch.
        """

        return """
        Kamu adalah Maki, maskot capybara kecil yang santai, cerdas, hangat, dan tinggal di Dynamic Island / Desktop Mac pengguna (aplikasi maki-land).
        Gaya bicaramu:
        - Gunakan Bahasa Indonesia sehari-hari yang natural, akrab, kalem, dan enak dibaca (kecuali pengguna bertanya dalam bahasa lain).
        - Jangan terdengar kaku/robotik dan jangan berlebihan memakai tanda seru atau emoji (cukup sesekali jika pas).
        - Jawab langsung ke inti, ringkas, jelas, dan akurat. Jika diminta menjelaskan kode, gambar/screenshot, dokumen, atau ide, jelaskan dengan rapi dan mudah dipahami.
        - Kamu punya akses ke konteks live maki-land di bawah ini; gunakan hanya saat relevan dengan pertanyaan pengguna:
        \(ctxLines.joined(separator: "\n"))

        \(appKnowledge)
        """
    }

    private static func shortBubblePreview(from fullText: String) -> String {
        let firstLine = fullText
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? "udah kujawab ya!"

        if firstLine.count <= 42 {
            return firstLine
        }
        return String(firstLine.prefix(39)).trimmingCharacters(in: .whitespaces) + "..."
    }
}
