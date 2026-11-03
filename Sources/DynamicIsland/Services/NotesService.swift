import Foundation
import AppKit
import Combine

public struct TodoItem: Identifiable, Codable, Equatable {
    public var id = UUID()
    public var title: String
    public var isDone: Bool = false

    public init(id: UUID = UUID(), title: String, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}

public enum NotesFocusTarget {
    case scratchpad
    case todoInput
}

public class NotesService: ObservableObject {
    public static let shared = NotesService()

    @Published public var scratchpadText: String = "" {
        didSet { saveScratchpad() }
    }

    @Published public var todos: [TodoItem] = [] {
        didSet { saveTodos() }
    }

    @Published public var showShortcutGuide: Bool = false
    @Published public var toastMessage: String? = nil
    public let focusRequest = PassthroughSubject<NotesFocusTarget, Never>()

    private let scratchpadKey = "dynamic_island_scratchpad"
    private let todosKey = "dynamic_island_todos"
    private var toastWork: DispatchWorkItem?

    private init() {
        loadData()
    }

    private func loadData() {
        if let text = UserDefaults.standard.string(forKey: scratchpadKey) {
            scratchpadText = text
        }

        if let data = UserDefaults.standard.data(forKey: todosKey),
           let list = try? JSONDecoder().decode([TodoItem].self, from: data) {
            todos = list
        } else {
            todos = [
                TodoItem(title: "Fokus kerja / belajar", isDone: false),
                TodoItem(title: "Minum air putih", isDone: true)
            ]
        }
    }

    private func saveScratchpad() {
        UserDefaults.standard.set(scratchpadText, forKey: scratchpadKey)
    }

    private func saveTodos() {
        if let data = try? JSONEncoder().encode(todos) {
            UserDefaults.standard.set(data, forKey: todosKey)
        }
    }

    public func cleanTodoLine(_ line: String) -> String {
        var s = line.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["• ", "- [ ] ", "- [x] ", "- ", "* ", "[] "] {
            if s.hasPrefix(prefix) {
                s = String(s.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        return s
    }

    public func addTodo(_ title: String) {
        let cleaned = cleanTodoLine(title)
        guard !cleaned.isEmpty else { return }
        todos.append(TodoItem(title: cleaned, isDone: false))
    }

    @discardableResult
    public func addMultipleTodos(from text: String) -> Int {
        let lines = text.components(separatedBy: .newlines)
        var added = 0
        for line in lines {
            let cleaned = cleanTodoLine(line)
            if !cleaned.isEmpty {
                todos.append(TodoItem(title: cleaned, isDone: false))
                added += 1
            }
        }
        if added > 0 {
            NSSound(named: "Pop")?.play()
            showToast("+\(added) tugas ditambahkan")
        }
        return added
    }

    public func toggleTodo(id: UUID) {
        if let idx = todos.firstIndex(where: { $0.id == id }) {
            todos[idx].isDone.toggle()
            NSSound(named: "Tink")?.play()
            if todos[idx].isDone {
                CapybaraService.shared.reactToEvent("satu tugas beres nih")
            }
        }
    }

    public func toggleTodoAtIndex(_ index: Int) {
        guard index >= 0 && index < todos.count else { return }
        todos[index].isDone.toggle()
        NSSound(named: "Tink")?.play()
        let status = todos[index].isDone ? "✓ Selesai" : "↺ Belum selesai"
        showToast("\(status): #\(index + 1)")
    }

    public func deleteTodo(id: UUID) {
        todos.removeAll { $0.id == id }
    }

    public func clearCompleted() {
        let before = todos.count
        todos.removeAll { $0.isDone }
        let removed = before - todos.count
        if removed > 0 {
            NSSound(named: "Pop")?.play()
            showToast("\(removed) tugas selesai dibersihkan")
        }
    }

    // MARK: - Power Shortcut Actions

    public func copyAllScratchpad() {
        guard !scratchpadText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(scratchpadText, forType: .string)
        NSSound(named: "Tink")?.play()
        showToast("Scratchpad disalin! (⇧⌘C)")
    }

    public func pasteClipboardAsTodos() {
        guard let str = NSPasteboard.general.string(forType: .string), !str.isEmpty else { return }
        _ = addMultipleTodos(from: str)
    }

    public func sendScratchpadSelectionOrLineToTodo(in window: NSWindow?) {
        // Check if an NSTextView has selected text first
        if let tv = window?.firstResponder as? NSTextView,
           tv.selectedRange().length > 0,
           let nsStr = tv.string as NSString? {
            let selected = nsStr.substring(with: tv.selectedRange())
            if addMultipleTodos(from: selected) > 0 {
                return
            }
        }

        // Otherwise send the current / last non-empty line in scratchpad
        let lines = scratchpadText.components(separatedBy: .newlines)
        if let lastLine = lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            addTodo(lastLine)
            NSSound(named: "Pop")?.play()
            showToast("Dikirim ke To-Do! (⌘↩)")
        }
    }

    public func insertBullet() {
        if scratchpadText.isEmpty || scratchpadText.hasSuffix("\n") {
            scratchpadText += "• "
        } else {
            scratchpadText += "\n• "
        }
        focusRequest.send(.scratchpad)
    }

    public func insertTimestamp() {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM HH:mm"
        let stamp = "[\(fmt.string(from: Date()))] "
        if scratchpadText.isEmpty || scratchpadText.hasSuffix("\n") || scratchpadText.hasSuffix(" ") {
            scratchpadText += stamp
        } else {
            scratchpadText += "\n" + stamp
        }
        focusRequest.send(.scratchpad)
        showToast("Timestamp disisipkan")
    }

    public func showToast(_ text: String) {
        toastWork?.cancel()
        toastMessage = text
        let work = DispatchWorkItem { [weak self] in
            self?.toastMessage = nil
        }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }
}
