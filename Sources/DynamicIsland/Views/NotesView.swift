import SwiftUI
import AppKit

public struct NotesView: View {
    @ObservedObject var notesService = NotesService.shared
    @State private var newTodoText: String = ""
    @State private var isTodoMaximized: Bool = false
    @State private var selectedTodoDetail: TodoItem? = nil
    @FocusState private var focusedField: NotesFocusTarget?

    public init() {}

    private var completedCount: Int {
        notesService.todos.filter { $0.isDone }.count
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            if notesService.showShortcutGuide {
                shortcutGuideView
            } else {
                mainContent
            }

            // Full-Text Todo Detail Viewer Card (shows complete text when long)
            if let detail = selectedTodoDetail {
                todoDetailModal(detail)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .zIndex(50)
            }

            // Floating shortcut confirmation toast
            if let toast = notesService.toastMessage {
                Text(toast)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3.5)
                    .background(Color.yellow)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.vertical, 3)
        .onReceive(notesService.focusRequest) { target in
            focusedField = target
        }
    }

    private var mainContent: some View {
        Group {
            if isTodoMaximized {
                todoColumnView
                    .padding(.horizontal, 2)
            } else {
                HStack(spacing: 10) {
                    scratchpadColumnView
                    Color.white.opacity(0.08)
                        .frame(width: 0.5)
                        .padding(.vertical, 4)
                    todoColumnView
                }
            }
        }
    }

    // MARK: - Left Column: Quick Scratchpad
    private var scratchpadColumnView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.yellow)
                    Text("Scratchpad")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                // Send line/selection to To-Do (Cmd+Return)
                Button {
                    notesService.sendScratchpadSelectionOrLineToTodo(in: IslandController.shared.panel)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 9))
                        Text("⌘↩")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.18))
                    .foregroundColor(.green)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Kirim baris/pilihan ke To-Do (⌘Return)")

                // Copy all button (Shift+Cmd+C)
                Button {
                    notesService.copyAllScratchpad()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 8.5))
                        Text("Salin")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white.opacity(0.85))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Salin seluruh Scratchpad (⇧⌘C)")

                // Clear button
                if !notesService.scratchpadText.isEmpty {
                    Button {
                        notesService.scratchpadText = ""
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.45))
                            .padding(2)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Text Editor with full Cmd+A/C/V/X/Z responder support
            ZStack(alignment: .topLeading) {
                if notesService.scratchpadText.isEmpty {
                    Text("Ketik catatan (⌘A/C/V/Z aktif, ⌘↩ kirim ke To-Do, ⇧⌘L bullet)...")
                        .font(.system(size: 9.5, design: .rounded))
                        .foregroundColor(.white.opacity(0.32))
                        .padding(.top, 5)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $notesService.scratchpadText)
                    .focused($focusedField, equals: .scratchpad)
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .padding(2)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(7)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Right Column (or Full Width): To-Do List
    private var todoColumnView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                    Text("To\u{2011}Do")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("(\(completedCount)/\(notesService.todos.count))")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                .fixedSize()

                Spacer(minLength: 4)

                if completedCount > 0 {
                    Button {
                        withAnimation { notesService.clearCompleted() }
                    } label: {
                        Text("Bersihkan")
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundColor(.orange.opacity(0.85))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Bersihkan tugas yang selesai (⇧⌘D)")
                }

                // Maximize / Split Toggle Button (⤢ / ⤡)
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        isTodoMaximized.toggle()
                    }
                } label: {
                    HStack(spacing: 2.5) {
                        Image(systemName: isTodoMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 7.8, weight: .bold))
                        Text(isTodoMaximized ? "Bagi" : "Penuh")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isTodoMaximized ? Color.green.opacity(0.24) : Color.white.opacity(0.12))
                    .foregroundColor(isTodoMaximized ? .green : .white.opacity(0.92))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(isTodoMaximized ? "Kembali ke tampilan bagi layar berdampingan" : "Perbesar tampilan To-Do satu layar penuh agar tulisan panjang terlihat jelas")

                // Shortcut Guide Button (Cmd + /)
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        notesService.showShortcutGuide.toggle()
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "command")
                            .font(.system(size: 8.5, weight: .bold))
                        Text("Pintasan")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.22))
                    .foregroundColor(.cyan)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Lihat daftar kombinasi shortcut (⌘/)")
            }

            // Add Todo Row
            HStack(spacing: 5) {
                TextField("Tambah tugas baru... (⌘N)", text: $newTodoText)
                    .focused($focusedField, equals: .todoInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                    .onSubmit {
                        submitNewTodo()
                    }

                Button {
                    submitNewTodo()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(newTodoText.trimmingCharacters(in: .whitespaces).isEmpty ? .white.opacity(0.2) : .green)
                }
                .buttonStyle(.plain)
                .disabled(newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Scrollable To-Do list with clean multi-line wrapping and detail expansion
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    if notesService.todos.isEmpty {
                        VStack(spacing: 3) {
                            Text("Belum ada tugas")
                                .font(.system(size: 9.8, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.35))
                            Text("Tekan ⌘N atau ketik di atas")
                                .font(.system(size: 8.5, design: .rounded))
                                .foregroundColor(.white.opacity(0.2))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                    } else {
                        ForEach(Array(notesService.todos.enumerated()), id: \.element.id) { index, item in
                            HStack(alignment: .top, spacing: 7) {
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        notesService.toggleTodo(id: item.id)
                                    }
                                } label: {
                                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundColor(item.isDone ? .green : .white.opacity(0.45))
                                        .padding(.top, 1)
                                }
                                .buttonStyle(.plain)

                                // Title with clean multi-line typography and click-to-open detail
                                Text(item.title)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .strikethrough(item.isDone, color: .white.opacity(0.4))
                                    .foregroundColor(item.isDone ? .white.opacity(0.45) : .white)
                                    .lineLimit(isTodoMaximized ? nil : 2)
                                    .lineSpacing(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedTodoDetail = item
                                    }

                                // Neat delete button on right
                                Button {
                                    withAnimation { notesService.deleteTodo(id: item.id) }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8.5, weight: .bold))
                                        .foregroundColor(.white.opacity(0.35))
                                        .padding(.top, 2)
                                        .padding(.horizontal, 2)
                                }
                                .buttonStyle(.plain)
                                .help("Hapus tugas ini (atau ⌥\(index + 1) untuk centang)")
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4.5)
                            .background(Color.white.opacity(item.isDone ? 0.025 : 0.055))
                            .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Full-Text Todo Detail Modal View
    @ViewBuilder
    private func todoDetailModal(_ item: TodoItem) -> some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    selectedTodoDetail = nil
                }

            VStack(alignment: .leading, spacing: 8) {
                todoDetailHeader(item)
                todoDetailContent(item)
                todoDetailFooter(item)
            }
            .padding(10)
            .frame(maxWidth: 420)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.14, green: 0.10, blue: 0.08).opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1.0)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 16, y: 6)
            .padding(8)
        }
    }

    @ViewBuilder
    private func todoDetailHeader(_ item: TodoItem) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.cyan)
            Text("Detail Tugas To-Do")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            Button {
                withAnimation {
                    notesService.toggleTodo(id: item.id)
                    if let updated = notesService.todos.first(where: { $0.id == item.id }) {
                        selectedTodoDetail = updated
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 8.5))
                    Text(item.isDone ? "Selesai" : "Tandai Selesai")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(item.isDone ? Color.green.opacity(0.25) : Color.white.opacity(0.12))
                .foregroundColor(item.isDone ? .green : .white.opacity(0.85))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                selectedTodoDetail = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func todoDetailContent(_ item: TodoItem) -> some View {
        ScrollView(.vertical) {
            Text(item.title)
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundColor(.white)
                .lineSpacing(2.0)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
        }
        .frame(maxHeight: 120)
        .background(Color.white.opacity(0.06))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func todoDetailFooter(_ item: TodoItem) -> some View {
        HStack {
            Text("\(item.title.count) karakter")
                .font(.system(size: 8.5, design: .rounded))
                .foregroundColor(.white.opacity(0.4))

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.title, forType: .string)
                notesService.showToast("✓ Teks tugas disalin!")
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 8.5))
                    Text("Salin Teks")
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.24))
                .foregroundColor(.cyan)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                selectedTodoDetail = nil
            } label: {
                Text("Tutup")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Shortcut Cheat Sheet View
    private var shortcutGuideView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "keyboard")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.cyan)
                Text("Kombinasi Shortcut Scratchpad & To-Do")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        notesService.showShortcutGuide = false
                    }
                } label: {
                    Text("Tutup (⌘/)")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(Color.white.opacity(0.14))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 3.5) {
                    shortcutRow(keys: "⌘A / ⌘C / ⌘V / ⌘X", desc: "Pilih Semua, Copy, Paste, Cut")
                    shortcutRow(keys: "⌘Z / ⇧⌘Z", desc: "Undo & Redo ketikan")
                    shortcutRow(keys: "⌘↩ (Cmd+Enter)", desc: "Kirim baris/pilihan ke To-Do")
                    shortcutRow(keys: "⇧⌘C", desc: "Salin seluruh isi Scratchpad")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 3.5) {
                    shortcutRow(keys: "⌘N / ⌘J", desc: "Fokus Tugas Baru / Scratchpad")
                    shortcutRow(keys: "⌥1 s/d ⌥9", desc: "Centang cepat To-Do #1–#9")
                    shortcutRow(keys: "⇧⌘V / ⇧⌘D", desc: "Paste jadi To-Do / Bersihkan")
                    shortcutRow(keys: "⇧⌘L / ⇧⌘T", desc: "Sisipkan Bullet (•) / Waktu")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @ViewBuilder
    private func shortcutRow(keys: String, desc: String) -> some View {
        HStack(spacing: 6) {
            Text(keys)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Color.white.opacity(0.10))
                .cornerRadius(4)
            Text(desc)
                .font(.system(size: 9.5, design: .rounded))
                .foregroundColor(.white.opacity(0.82))
                .lineLimit(1)
        }
    }

    private func submitNewTodo() {
        notesService.addTodo(newTodoText)
        newTodoText = ""
    }
}
