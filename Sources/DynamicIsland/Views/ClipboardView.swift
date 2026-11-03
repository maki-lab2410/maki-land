import SwiftUI

public struct ClipboardView: View {
    @ObservedObject var clipService = ClipboardService.shared
    @State private var copiedId: UUID? = nil
    @State private var searchQuery: String = ""

    public init() {}

    private var filteredItems: [ClipboardItem] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return clipService.history }
        return clipService.history.filter {
            $0.text.localizedCaseInsensitiveContains(q)
        }
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Header + Instant Search Bar
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Clipboard (\(clipService.history.count))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                // Compact Search Input
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                    TextField("Cari riwayat copy...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white)
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                .frame(maxWidth: 185)

                Spacer()

                if clipService.history.contains(where: { !$0.isPinned }) {
                    Button("Bersihkan") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            clipService.clearAll()
                        }
                    }
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.red.opacity(0.82))
                    .buttonStyle(.plain)
                }
            }

            if filteredItems.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.28))
                    Text(searchQuery.isEmpty ? "Semua yang Anda Copy (⌘C) otomatis masuk ke sini" : "Tidak ada hasil yang cocok")
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundColor(.white.opacity(0.42))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { idx, item in
                            clipRow(item, index: idx)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func clipRow(_ item: ClipboardItem, index: Int) -> some View {
        let isJustCopied = (copiedId == item.id)

        HStack(spacing: 7) {
            // Kind Icon or Thumbnail
            kindLeadingView(for: item)
                .frame(width: 18, height: 18)

            // Preview Text
            Text(item.preview)
                .font(.system(size: 10.5, weight: isJustCopied ? .bold : .regular, design: .rounded))
                .foregroundColor(isJustCopied ? .green : .white.opacity(0.9))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Relative Time / Shortcut Hint
            Text(isJustCopied ? "Tersalin!" : (index < 9 ? "⌥\(index + 1) • \(item.relativeTime)" : item.relativeTime))
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                .foregroundColor(isJustCopied ? .green : .white.opacity(0.35))

            // Quick Paste-Back Button
            Button {
                clipService.copyAndPasteToActiveApp(item)
            } label: {
                Text("Paste")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.blue.opacity(0.26))
                    .foregroundColor(.cyan)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Salin & kembali ke aplikasi aktif")

            // Pin Toggle
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    clipService.togglePin(item)
                }
            } label: {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 9))
                    .foregroundColor(item.isPinned ? .orange : .white.opacity(0.32))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help(item.isPinned ? "Lepas sematan" : "Sematkan di atas")

            // Delete Button
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    clipService.remove(item)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 15, height: 15)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4.5)
        .background(isJustCopied ? Color.green.opacity(0.16) : (item.isPinned ? Color.orange.opacity(0.10) : Color.white.opacity(0.07)))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            triggerInstantCopy(item)
        }
    }

    @ViewBuilder
    private func kindLeadingView(for item: ClipboardItem) -> some View {
        switch item.kind {
        case .url:
            Image(systemName: "link")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(.cyan)
        case .file:
            if let path = item.secondaryPath {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "doc.fill")
                    .font(.system(size: 10.5))
                    .foregroundColor(.orange)
            }
        case .image:
            if let path = item.secondaryPath, let img = NSImage(contentsOfFile: path) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 10.5))
                    .foregroundColor(.purple)
            }
        case .text:
            Image(systemName: "doc.plaintext")
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.55))
        }
    }

    private func triggerInstantCopy(_ item: ClipboardItem) {
        clipService.copyItem(item)
        withAnimation(.easeInOut(duration: 0.15)) {
            copiedId = item.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedId == item.id {
                withAnimation { copiedId = nil }
            }
        }
    }
}
