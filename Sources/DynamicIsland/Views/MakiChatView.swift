import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Rich Markdown Helper (Preserves All Line Breaks & Lists!)

private func renderMakiMarkdown(_ raw: String) -> Text {
    let opts = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace
    )
    if let attr = try? AttributedString(markdown: raw, options: opts) {
        return Text(attr)
    }
    return Text(raw)
}

// MARK: - 1. Notch AI Chat Panel (Inside `🐾 Capy` Tab)

public struct MakiNotchChatPanelView: View {
    @ObservedObject var gemini = GeminiService.shared
    @State private var draftText: String = ""
    @State private var keyInput: String = ""
    @State private var copiedMessageId: UUID? = nil
    @State private var isDropTargeted: Bool = false
    @FocusState private var isInputFocused: Bool

    public init() {}

    public var body: some View {
        VStack(spacing: 6) {
            headerBar

            if gemini.isShowingSettings {
                settingsCard
            } else {
                messagesArea
                if let att = gemini.pendingAttachment {
                    attachmentBanner(att)
                }
                inputBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                isInputFocused = true
            }
        }
        .onReceive(gemini.focusInputTrigger) { _ in
            if !gemini.isShowingSettings {
                isInputFocused = true
            }
        }
        .onDrop(of: DropZoneService.supportedDropUTTypes, isTargeted: $isDropTargeted) { providers in
            handleDroppedImageProviders(providers)
        }
    }

    private var headerBar: some View {
        HStack(spacing: 5) {
            HStack(spacing: 4) {
                Text("💬 Tanya Maki")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Quick Model Switcher Pill
                Menu {
                    ForEach(MakiAIProvider.allCases) { prov in
                        let models = MakiGeminiModel.allCases.filter { $0.provider == prov }
                        if !models.isEmpty {
                            Section("\(prov.icon) \(prov.name)") {
                                ForEach(models) { model in
                                    Button {
                                        gemini.selectedModel = model
                                    } label: {
                                        HStack {
                                            Text(model.shortLabel)
                                            if gemini.selectedModel == model {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 2.5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8, weight: .bold))
                        Text(gemini.selectedModel.shortLabel)
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.22))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Pilih model Gemini AI")
            }

            Spacer()

            // 1-Click Attach Screenshot (Clipboard / Tray / Recent)
            Button {
                if !gemini.attachLatestScreenshotOrClipboard() {
                    gemini.pickImageAttachmentFromFinder()
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 8.5, weight: .bold))
                    Text("Screenshot")
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 6.5)
                .padding(.vertical, 2.5)
                .background(Color.cyan.opacity(0.18))
                .foregroundColor(.cyan)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Lampirkan screenshot dari Clipboard / Tray (atau pilih gambar)")

            if !gemini.messages.isEmpty {
                Button {
                    gemini.startNewConversation()
                } label: {
                    HStack(spacing: 2.5) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 8, weight: .bold))
                        Text("Baru")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.09))
                    .foregroundColor(.white.opacity(0.78))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Mulai obrolan baru")
            }

            // API Key & Model Settings Button
            Button {
                keyInput = ""
                withAnimation(.easeInOut(duration: 0.16)) {
                    gemini.isShowingSettings.toggle()
                }
            } label: {
                HStack(spacing: 3) {
                    Circle()
                        .fill(gemini.hasAPIKey ? Color.green : Color.orange)
                        .frame(width: 5.5, height: 5.5)
                    Image(systemName: "key.fill")
                        .font(.system(size: 8.5, weight: .bold))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(gemini.isShowingSettings ? Color.orange.opacity(0.30) : Color.white.opacity(0.09))
                .foregroundColor(gemini.isShowingSettings ? .orange : .white.opacity(0.85))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Pengaturan API Key Gemini (\(gemini.maskedAPIKey))")

            // Switch back to Care / Habitat
            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                    gemini.isNotchChatMode = false
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 8, weight: .bold))
                    Text("Habitat")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Color.green.opacity(0.20))
                .foregroundColor(.green)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Kembali ke kandang & perawatan Maki")
        }
    }

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 6) {
                    if gemini.messages.isEmpty && !gemini.isThinking {
                        emptyPromptSuggestions
                    } else {
                        ForEach(gemini.messages) { msg in
                            messageRow(msg, compact: false)
                                .id(msg.id)
                        }
                        if gemini.isThinking {
                            thinkingRow
                                .id("maki_thinking_anchor")
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            }
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isDropTargeted ? Color.orange.opacity(0.14) : Color.white.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(isDropTargeted ? Color.orange : Color.white.opacity(0.09), lineWidth: isDropTargeted ? 1.1 : 0.6)
            )
            .onChange(of: gemini.messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: gemini.isThinking) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
        }
    }

    private var emptyPromptSuggestions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Halo! Aku Maki 🐾 Mau tanya jadwal hari ini, minta jelasin screenshot, atau diskusi kode & ide? Tulis aja di bawah!")
                .font(.system(size: 9.8, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.78))
                .lineSpacing(1.5)

            HStack(spacing: 5) {
                quickChip("📅 Jadwal & Tugas") {
                    gemini.sendMessage("Rangkum jadwal kalender hari ini dan tugas To-Do aku yang belum selesai dong.")
                }
                quickChip("📸 Jelaskan Screenshot") {
                    if gemini.attachLatestScreenshotOrClipboard() {
                        gemini.sendMessage("Tolong jelaskan isi screenshot ini secara ringkas dan jelas.")
                    } else {
                        gemini.pickImageAttachmentFromFinder()
                    }
                }
            }
            HStack(spacing: 5) {
                quickChip("📋 Rapikan Clipboard") {
                    let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if clip.isEmpty {
                        gemini.sendMessage("Kasih tips singkat biar fokus kerja di depan Mac hari ini dong.")
                    } else {
                        gemini.sendMessage("Tolong rapikan atau rangkum teks dari clipboard ini:\n\n\(String(clip.prefix(1500)))")
                    }
                }
                quickChip("🍵 Teman Ngobrol") {
                    gemini.sendMessage("Lagi rehat sebentar nih, kasih 1 fakta unik atau obrolan ringan yang bikin segar dong.")
                }
            }
        }
        .padding(4)
    }

    private var inputBar: some View {
        HStack(spacing: 6) {
            Button {
                gemini.pickImageAttachmentFromFinder()
            } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(gemini.pendingAttachment != nil ? .orange : .white.opacity(0.62))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Pilih file gambar untuk dilampirkan")

            TextField("Tanya apa aja ke Maki... (Enter untuk kirim)", text: $draftText)
                .textFieldStyle(.plain)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .focused($isInputFocused)
                .onSubmit {
                    submitCurrentDraft()
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.09))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(isInputFocused ? Color.orange.opacity(0.65) : Color.white.opacity(0.12), lineWidth: 0.7)
                )

            Button {
                if gemini.isThinking {
                    gemini.cancelCurrentTask()
                } else {
                    submitCurrentDraft()
                }
            } label: {
                Image(systemName: gemini.isThinking ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(gemini.isThinking ? Color(red: 1.0, green: 0.40, blue: 0.40) : (canSend ? .orange : .white.opacity(0.28)))
            }
            .buttonStyle(.plain)
            .disabled(!gemini.isThinking && !canSend)
            .help(gemini.isThinking ? "Batalkan (Stop)" : "Kirim ke Maki (Enter)")
        }
    }

    private var settingsCard: some View {
        MakiGeminiSettingsCard(keyInput: $keyInput)
    }

    private var canSend: Bool {
        !gemini.isThinking && (!draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || gemini.pendingAttachment != nil)
    }

    private func submitCurrentDraft() {
        guard canSend else { return }
        let prompt = draftText
        draftText = ""
        gemini.sendMessage(prompt)
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        let action = {
            if gemini.isThinking {
                proxy.scrollTo("maki_thinking_anchor", anchor: .bottom)
            } else if let last = gemini.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
        if animated {
            withAnimation(.easeOut(duration: 0.20)) { action() }
        } else {
            action()
        }
    }

    @ViewBuilder
    private func attachmentBanner(_ att: MakiChatAttachment) -> some View {
        HStack(spacing: 6) {
            Image(nsImage: att.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 24, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            Text("📷 \(att.name)")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(.cyan)
                .lineLimit(1)

            Spacer()

            Button {
                gemini.pendingAttachment = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10.5))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.cyan.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    @ViewBuilder
    private func quickChip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .overlay(Capsule().stroke(Color.orange.opacity(0.32), lineWidth: 0.6))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var thinkingRow: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.75)
            Text("Maki lagi mikir sebentar...")
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundColor(Color(red: 0.85, green: 0.42, blue: 0.08))
            Spacer()

            Button {
                gemini.cancelCurrentTask()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 8))
                    Text("Batal")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Color.red.opacity(0.14))
                .foregroundColor(Color(red: 0.90, green: 0.25, blue: 0.25))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Batalkan proses jawaban ini")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color(red: 1.0, green: 0.965, blue: 0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.orange.opacity(0.30), lineWidth: 0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    @ViewBuilder
    private func messageRow(_ msg: MakiChatMessage, compact: Bool) -> some View {
        switch msg.sender {
        case .user:
            HStack {
                Spacer(minLength: 32)
                VStack(alignment: .trailing, spacing: 3) {
                    if let imgName = msg.attachedImageName {
                        HStack(spacing: 4) {
                            if let path = msg.attachedImagePath, let nsImg = NSImage(contentsOfFile: path) {
                                Image(nsImage: nsImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 26, height: 20)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 8.5))
                            }
                            Text(imgName)
                                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundColor(Color(red: 1.0, green: 0.94, blue: 0.85))
                    }

                    Text(msg.text)
                        .font(.system(size: compact ? 9.8 : 10.2, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 1.0, green: 0.98, blue: 0.95))
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5.5)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.82, green: 0.46, blue: 0.18), Color(red: 0.68, green: 0.35, blue: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(red: 1.0, green: 0.65, blue: 0.35).opacity(0.35), lineWidth: 0.6)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color(red: 0.55, green: 0.25, blue: 0.08).opacity(0.20), radius: 3, x: 0, y: 1)
            }

        case .maki:
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4.0) {
                    HStack(spacing: 5) {
                        Text("🐾 Maki")
                            .font(.system(size: 8.8, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.42, green: 0.22, blue: 0.08))

                        if let m = msg.modelUsed {
                            Text(m.replacingOccurrences(of: "gemini-", with: ""))
                                .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(red: 0.55, green: 0.38, blue: 0.25).opacity(0.85))
                        }

                        Spacer()

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(msg.text, forType: .string)
                            copiedMessageId = msg.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                if copiedMessageId == msg.id { copiedMessageId = nil }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: copiedMessageId == msg.id ? "checkmark" : "doc.on.doc.fill")
                                    .font(.system(size: 7.5, weight: .bold))
                                Text(copiedMessageId == msg.id ? "Disalin!" : "Salin Jawaban")
                                    .font(.system(size: 8.0, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 6.5)
                            .padding(.vertical, 2.5)
                            .background(copiedMessageId == msg.id ? Color.green.opacity(0.18) : Color.orange.opacity(0.12))
                            .foregroundColor(copiedMessageId == msg.id ? Color(red: 0.10, green: 0.55, blue: 0.20) : Color(red: 0.85, green: 0.42, blue: 0.08))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Salin seluruh jawaban Maki")
                    }

                    renderMakiMarkdown(msg.text)
                        .font(.system(size: compact ? 9.8 : 10.2, weight: .regular, design: .rounded))
                        .foregroundColor(Color(red: 0.16, green: 0.10, blue: 0.04))
                        .lineSpacing(1.8)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6.5)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(red: 0.23, green: 0.13, blue: 0.06).opacity(0.14), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 2.5, x: 0, y: 1)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Spacer(minLength: 18)
            }

        case .error:
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9.5))
                    .foregroundColor(.orange)
                Text(msg.text)
                    .font(.system(size: 9.2, weight: .medium, design: .rounded))
                    .foregroundColor(.orange)
                    .textSelection(.enabled)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.red.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func handleDroppedImageProviders(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var resolved: URL?
                    if let data = item as? Data {
                        resolved = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let url = item as? URL {
                        resolved = url
                    }
                    if let u = resolved {
                        DispatchQueue.main.async {
                            _ = GeminiService.shared.attachImage(from: u)
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}

// MARK: - 2. Floating Desktop Chat Card (Attached Right Above Desktop Maki!)

public struct MakiDesktopChatCard: View {
    @ObservedObject var gemini = GeminiService.shared
    @State private var draftText: String = ""
    @State private var keyInput: String = ""
    @State private var copiedMessageId: UUID? = nil
    @FocusState private var isDesktopInputFocused: Bool

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 5) {
                // Top Mini Header
                HStack(spacing: 5) {
                    Text("💬 Tanya Maki")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.18, green: 0.10, blue: 0.05))

                    Menu {
                        ForEach(MakiAIProvider.allCases) { prov in
                            let models = MakiGeminiModel.allCases.filter { $0.provider == prov }
                            if !models.isEmpty {
                                Section("\(prov.icon) \(prov.name)") {
                                    ForEach(models) { m in
                                        Button {
                                            gemini.selectedModel = m
                                        } label: {
                                            HStack {
                                                Text(m.shortLabel)
                                                if gemini.selectedModel == m {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(gemini.selectedModel.shortLabel)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12))
                            .foregroundColor(Color(red: 0.85, green: 0.38, blue: 0.05))
                            .clipShape(Capsule())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Spacer()

                    Button {
                        if !gemini.attachLatestScreenshotOrClipboard() {
                            gemini.pickImageAttachmentFromFinder()
                        }
                    } label: {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(Color(red: 0.03, green: 0.57, blue: 0.70))
                            .frame(width: 20, height: 20)
                            .background(Color(red: 0.03, green: 0.57, blue: 0.70).opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Lampirkan screenshot terbaru / Clipboard")

                    if !gemini.messages.isEmpty {
                        Button {
                            gemini.startNewConversation()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color(red: 0.28, green: 0.16, blue: 0.08))
                                .frame(width: 20, height: 20)
                                .background(Color(red: 0.28, green: 0.16, blue: 0.08).opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Obrolan baru")
                    }

                    Button {
                        keyInput = ""
                        gemini.isShowingSettings.toggle()
                    } label: {
                        Image(systemName: "key.fill")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(gemini.hasAPIKey ? Color(red: 0.10, green: 0.65, blue: 0.25) : Color.orange)
                            .frame(width: 20, height: 20)
                            .background(Color(red: 0.28, green: 0.16, blue: 0.08).opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Pengaturan API Key Gemini")

                    Button {
                        gemini.isDesktopChatOpen = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(red: 0.28, green: 0.16, blue: 0.08))
                            .frame(width: 20, height: 20)
                            .background(Color(red: 0.28, green: 0.16, blue: 0.08).opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Tutup chat (Esc)")
                }

                if gemini.isShowingSettings {
                    MakiGeminiSettingsCard(keyInput: $keyInput, light: true)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 5.5) {
                                if gemini.messages.isEmpty && !gemini.isThinking {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Hai! Mau tanya apa sambil kerja di Desktop? Bisa tanya jadwal, kode, atau lampirkan screenshot 📸")
                                            .font(.system(size: 9.4, weight: .medium, design: .rounded))
                                            .foregroundColor(Color(red: 0.35, green: 0.22, blue: 0.12))

                                        HStack(spacing: 4) {
                                            desktopQuickChip("📅 Jadwal") {
                                                gemini.sendMessage("Apa jadwal kalender dan tugas aku yang belum beres hari ini?")
                                            }
                                            desktopQuickChip("📸 Screenshot") {
                                                if gemini.attachLatestScreenshotOrClipboard() {
                                                    gemini.sendMessage("Tolong jelaskan isi screenshot ini secara ringkas.")
                                                } else {
                                                    gemini.pickImageAttachmentFromFinder()
                                                }
                                            }
                                            desktopQuickChip("✨ Fitur") {
                                                gemini.sendMessage("Kamu itu apa? Jelaskan maki-land ini aplikasi apa dan apa saja fitur-fiturnya.")
                                            }
                                            desktopQuickChip("📋 Clipboard") {
                                                let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                                if !clip.isEmpty {
                                                    gemini.sendMessage("Tolong rangkum atau rapikan teks ini:\n\n\(String(clip.prefix(1200)))")
                                                } else {
                                                    gemini.sendMessage("Kasih 1 fakta seru biar semangat kerja dong.")
                                                }
                                            }
                                        }
                                    }
                                    .padding(3)
                                } else {
                                    ForEach(gemini.messages) { msg in
                                        desktopBubbleRow(msg)
                                            .id(msg.id)
                                    }
                                    if gemini.isThinking {
                                        HStack(spacing: 5) {
                                            ProgressView().controlSize(.mini).scaleEffect(0.7)
                                            Text("Maki lagi ngetik...")
                                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                                .foregroundColor(Color(red: 0.85, green: 0.42, blue: 0.08))
                                            Spacer()

                                            Button {
                                                gemini.cancelCurrentTask()
                                            } label: {
                                                HStack(spacing: 2.5) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 7.8))
                                                    Text("Batal")
                                                        .font(.system(size: 8.2, weight: .bold, design: .rounded))
                                                }
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.red.opacity(0.14))
                                                .foregroundColor(Color(red: 0.90, green: 0.25, blue: 0.25))
                                                .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                            .help("Batalkan proses jawaban")
                                        }
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 4)
                                        .background(Color(red: 1.0, green: 0.965, blue: 0.92))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(Color.orange.opacity(0.30), lineWidth: 0.6)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .id("desktop_thinking_anchor")
                                    }
                                }
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 4)
                        }
                        .background(Color(red: 0.97, green: 0.95, blue: 0.925).opacity(0.70))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color(red: 0.25, green: 0.15, blue: 0.08).opacity(0.12), lineWidth: 0.8)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .onChange(of: gemini.messages.count) { _ in
                            scrollDesktop(proxy)
                        }
                        .onChange(of: gemini.isThinking) { _ in
                            scrollDesktop(proxy)
                        }
                        .onAppear {
                            scrollDesktop(proxy, animated: false)
                        }
                    }

                    if let att = gemini.pendingAttachment {
                        HStack(spacing: 5) {
                            Image(nsImage: att.thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 20, height: 15)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                            Text("📷 \(att.name)")
                                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.cyan)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                gemini.pendingAttachment = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.cyan.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // Input Field
                    HStack(spacing: 5) {
                        TextField("Ketik pertanyaan ke Maki...", text: $draftText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(Color(red: 0.16, green: 0.10, blue: 0.04))
                            .focused($isDesktopInputFocused)
                            .onSubmit {
                                submitDesktopDraft()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5.5)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 99, style: .continuous)
                                    .stroke(isDesktopInputFocused ? Color.orange : Color(red: 0.25, green: 0.15, blue: 0.08).opacity(0.20), lineWidth: 1.0)
                            )
                            .clipShape(Capsule())

                        Button {
                            if gemini.isThinking {
                                gemini.cancelCurrentTask()
                            } else {
                                submitDesktopDraft()
                            }
                        } label: {
                            Image(systemName: gemini.isThinking ? "stop.circle.fill" : "arrow.up.circle.fill")
                                .font(.system(size: 16.5, weight: .bold))
                                .foregroundColor(gemini.isThinking ? Color(red: 1.0, green: 0.35, blue: 0.35) : (canSendDesktop ? Color(red: 0.95, green: 0.48, blue: 0.12) : Color.black.opacity(0.20)))
                        }
                        .buttonStyle(.plain)
                        .disabled(!gemini.isThinking && !canSendDesktop)
                        .help(gemini.isThinking ? "Batalkan (Stop)" : "Kirim ke Maki (Enter)")
                    }
                }
            }
            .padding(10)
            .frame(width: 326, height: 224)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.988, blue: 0.968).opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(red: 0.25, green: 0.15, blue: 0.08).opacity(0.20), lineWidth: 1.2)
            )
            // Tight, soft shadow that stays inside the transparent window bounds (no clipped grey box)
            .shadow(color: Color(red: 0.20, green: 0.10, blue: 0.04).opacity(0.10), radius: 4, x: 0, y: 2)

            // Pointer Tail pointing down to Maki
            TriangleTailDown()
                .fill(Color(red: 1.0, green: 0.988, blue: 0.968).opacity(0.98))
                .frame(width: 14, height: 7)
                .overlay(
                    TriangleTailDown()
                        .stroke(Color(red: 0.25, green: 0.15, blue: 0.08).opacity(0.20), lineWidth: 1.2)
                )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                isDesktopInputFocused = true
            }
        }
        .onReceive(gemini.focusInputTrigger) { _ in
            if !gemini.isShowingSettings {
                isDesktopInputFocused = true
            }
        }
    }

    private var canSendDesktop: Bool {
        !gemini.isThinking && (!draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || gemini.pendingAttachment != nil)
    }

    private func submitDesktopDraft() {
        guard canSendDesktop else { return }
        let q = draftText
        draftText = ""
        gemini.sendMessage(q)
    }

    private func scrollDesktop(_ proxy: ScrollViewProxy, animated: Bool = true) {
        let go = {
            if gemini.isThinking {
                proxy.scrollTo("desktop_thinking_anchor", anchor: .bottom)
            } else if let last = gemini.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
        if animated {
            withAnimation(.easeOut(duration: 0.18)) { go() }
        } else {
            go()
        }
    }

    @ViewBuilder
    private func desktopQuickChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                .foregroundColor(Color(red: 0.85, green: 0.42, blue: 0.08))
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color(red: 1.0, green: 0.95, blue: 0.90))
                .overlay(Capsule().stroke(Color.orange.opacity(0.35), lineWidth: 0.7))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func desktopBubbleRow(_ msg: MakiChatMessage) -> some View {
        switch msg.sender {
        case .user:
            HStack {
                Spacer(minLength: 24)
                VStack(alignment: .trailing, spacing: 2) {
                    if let img = msg.attachedImageName {
                        Text("📷 \(img)")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.94, blue: 0.85))
                            .lineLimit(1)
                    }
                    Text(msg.text)
                        .font(.system(size: 9.6, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6.5)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.98, green: 0.55, blue: 0.20), Color(red: 0.90, green: 0.38, blue: 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(
                    MakiBubbleShape(bottomLeading: 13, bottomTrailing: 3)
                )
            }

        case .maki:
            HStack {
                VStack(alignment: .leading, spacing: 3.5) {
                    HStack {
                        Text("🐾 Maki")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.48, green: 0.22, blue: 0.06))
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(msg.text, forType: .string)
                            copiedMessageId = msg.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                if copiedMessageId == msg.id { copiedMessageId = nil }
                            }
                        } label: {
                            HStack(spacing: 2.5) {
                                Image(systemName: copiedMessageId == msg.id ? "checkmark" : "doc.on.doc.fill")
                                    .font(.system(size: 7.2, weight: .bold))
                                Text(copiedMessageId == msg.id ? "Disalin!" : "Salin Jawaban")
                                    .font(.system(size: 7.8, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(copiedMessageId == msg.id ? Color.green.opacity(0.18) : Color.orange.opacity(0.12))
                            .foregroundColor(copiedMessageId == msg.id ? Color(red: 0.10, green: 0.55, blue: 0.20) : Color(red: 0.85, green: 0.42, blue: 0.08))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Salin seluruh jawaban Maki")
                    }

                    renderMakiMarkdown(msg.text)
                        .font(.system(size: 9.6, weight: .regular, design: .rounded))
                        .foregroundColor(Color(red: 0.14, green: 0.08, blue: 0.04))
                        .lineSpacing(1.6)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    MakiBubbleShape(bottomLeading: 3, bottomTrailing: 13)
                    .fill(Color.white)
                )
                .overlay(
                    MakiBubbleShape(bottomLeading: 3, bottomTrailing: 13)
                    .stroke(Color(red: 0.25, green: 0.15, blue: 0.08).opacity(0.14), lineWidth: 0.8)
                )
                Spacer(minLength: 6)
            }

        case .error:
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(red: 0.85, green: 0.20, blue: 0.20))
                Text(msg.text)
                    .font(.system(size: 8.8, weight: .medium, design: .rounded))
                    .foregroundColor(Color(red: 0.70, green: 0.12, blue: 0.12))
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 1.0, green: 0.90, blue: 0.90))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.red.opacity(0.35), lineWidth: 0.7)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
    }
}

private struct TriangleTailDown: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        p.closeSubpath()
        return p
    }
}

// MARK: - 3. Shared API Key & Model Settings View

private struct MakiGeminiSettingsCard: View {
    @ObservedObject var gemini = GeminiService.shared
    @Binding var keyInput: String
    var light: Bool = false
    @State private var activeProvider: MakiAIProvider = .gemini

    private var ink: Color { light ? Color(red: 0.16, green: 0.09, blue: 0.04) : .white }
    private var inkSoft: Color { light ? Color(red: 0.16, green: 0.09, blue: 0.04).opacity(0.62) : .white.opacity(0.55) }
    private var chipBG: Color { light ? Color(red: 0.25, green: 0.15, blue: 0.08).opacity(0.08) : Color.white.opacity(0.08) }
    private var fieldBG: Color { light ? Color.white : Color.white.opacity(0.09) }
    private var panelBG: Color { light ? Color(red: 0.97, green: 0.95, blue: 0.925).opacity(0.70) : Color.white.opacity(0.06) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Provider Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(MakiAIProvider.allCases) { prov in
                        let isSelected = (activeProvider == prov)
                        let hasKey = gemini.hasKey(for: prov)
                        Button {
                            activeProvider = prov
                            keyInput = ""
                        } label: {
                            HStack(spacing: 3) {
                                Text(prov.icon)
                                    .font(.system(size: 8))
                                Text(prov.name)
                                    .font(.system(size: 8.2, weight: isSelected ? .bold : .medium, design: .rounded))
                                Circle()
                                    .fill(hasKey ? Color.green : Color.gray.opacity(0.4))
                                    .frame(width: 4.5, height: 4.5)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(isSelected ? Color.orange.opacity(0.35) : chipBG)
                            .foregroundColor(isSelected ? .orange : inkSoft)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Current Provider Detail & Key Input
            HStack {
                Text("\(activeProvider.icon) \(activeProvider.name) (\(activeProvider.badge))")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                Spacer()
                Text(gemini.hasKey(for: activeProvider) ? "✓ Aktif (\(gemini.maskedKey(for: activeProvider)))" : "Belum diatur")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(gemini.hasKey(for: activeProvider) ? .green : inkSoft)
            }

            Text("Env var: \(activeProvider.envVar) • Disimpan lokal di Application Support Mac.")
                .font(.system(size: 8, weight: .regular, design: .rounded))
                .foregroundColor(inkSoft)

            HStack(spacing: 5) {
                SecureField(activeProvider.placeholder, text: $keyInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(ink)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4.5)
                    .background(fieldBG)
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                Button("Simpan") {
                    let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        gemini.updateKey(trimmed, for: activeProvider)
                        keyInput = ""
                        gemini.isShowingSettings = false
                    }
                }
                .font(.system(size: 8.8, weight: .bold, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(Color.green.opacity(0.28))
                .foregroundColor(.green)
                .clipShape(Capsule())
                .buttonStyle(.plain)

                if gemini.hasKey(for: activeProvider) && activeProvider != .ollama {
                    Button("Hapus") {
                        gemini.clearKey(for: activeProvider)
                    }
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4.5)
                    .background(Color.red.opacity(0.18))
                    .foregroundColor(.red)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                }

                Button("Tutup") {
                    gemini.isShowingSettings = false
                }
                .font(.system(size: 8.8, weight: .bold, design: .rounded))
                .foregroundColor(.cyan)
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .onAppear {
            activeProvider = gemini.selectedModel.provider
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(panelBG)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}


// MARK: - Bubble shape with a small "speech" corner (macOS 13 compatible)

struct MakiBubbleShape: Shape {
    var bottomLeading: CGFloat = 13
    var bottomTrailing: CGFloat = 13
    var big: CGFloat = 13

    func path(in rect: CGRect) -> Path {
        let tl = min(big, min(rect.width, rect.height) / 2)
        let tr = tl
        let bl = min(bottomLeading, min(rect.width, rect.height) / 2)
        let br = min(bottomTrailing, min(rect.width, rect.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        p.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        p.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}
