import SwiftUI
import UniformTypeIdentifiers

public struct DropZoneView: View {
    @ObservedObject var dropService = DropZoneService.shared
    @State private var isTargeted: Bool = false

    public init() {}

    public var body: some View {
        Group {
            if let studioItem = dropService.activeStudioItem {
                TrayStudioView(item: studioItem)
                    .id(studioItem.id)
            } else {
                shelfBody
            }
        }
        .onDrop(of: DropZoneService.supportedDropUTTypes, isTargeted: $isTargeted) { providers in
            CapybaraService.shared.handleDroppedProviders(providers)
        }
    }

    private var shelfBody: some View {
        VStack(spacing: 7) {
            if dropService.droppedItems.isEmpty {
                // Empty state drop target + Screenshot & File Picker
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(
                            isTargeted ? Color.cyan : Color.white.opacity(0.18),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(isTargeted ? Color.blue.opacity(0.16) : Color.white.opacity(0.04))
                        )

                    HStack(spacing: 12) {
                        Image(systemName: isTargeted ? "arrow.down.doc.fill" : "photo.on.rectangle.angled")
                            .font(.system(size: 21))
                            .foregroundColor(isTargeted ? .cyan : .white.opacity(0.65))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kasih Screenshot atau File ke Maki / Tray")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))

                            Text("Tarik hasil screenshot langsung ke Maki biar masuk Tray & siap diambil kapan aja")
                                .font(.system(size: 9.2, design: .rounded))
                                .foregroundColor(.white.opacity(0.52))
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                IslandState.shared.isShowingCameraMirror = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("🪞")
                                    .font(.system(size: 10))
                                Text("Cermin / Mirror")
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.28))
                            .foregroundColor(Color.purple.opacity(0.95))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Buka cermin kamera / webcam langsung di layar")

                        Button {
                            CapybaraService.shared.catchClipboardOrRecentScreenshot()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 10))
                                Text("Screenshot")
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.26))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Ambil screenshot terakhir atau dari Clipboard ke Tray")

                        Button {
                            dropService.pickFilesFromFinder()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 10))
                                Text("Pilih File")
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.32))
                            .foregroundColor(.cyan)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: 76)
            } else {
                // Shelf with items (supports dragging files/screenshots OUT immediately + 1-click Copy + Studio!)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(dropService.droppedItems) { item in
                            trayItemCard(item)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(height: 54)

                // Bottom Multi-File Action Bar
                HStack(spacing: 7) {
                    Text("\(dropService.droppedItems.count) item • Tarik keluar untuk pakai atau klik Salin")
                        .font(.system(size: 9.2, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)

                    if let banner = dropService.statusBanner {
                        Text("• \(banner.message)")
                            .font(.system(size: 9.2, weight: .semibold, design: .rounded))
                            .foregroundColor(banner.isError ? .red : .green)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            IslandState.shared.isShowingCameraMirror = true
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text("🪞")
                                .font(.system(size: 9))
                            Text("Cermin")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.24))
                        .foregroundColor(Color.purple.opacity(0.95))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Buka cermin kamera / webcam langsung di layar")

                    Button {
                        CapybaraService.shared.catchClipboardOrRecentScreenshot()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 9, weight: .bold))
                            Text("Screenshot")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.22))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Ambil screenshot dari Clipboard / terakhir ke Tray")

                    Button {
                        dropService.pickFilesFromFinder()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold))
                            Text("Tambah")
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.10))
                        .foregroundColor(.white.opacity(0.85))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    // Merge PDFs / Images into 1 PDF when >= 2 compatible items exist
                    if dropService.mergeableItems.count >= 2 {
                        Button {
                            runMergeAll()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 9))
                                Text("Gabung Jadi 1 PDF (\(dropService.mergeableItems.count))")
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.32))
                            .foregroundColor(.cyan)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(dropService.isBusy)
                    }

                    Button {
                        dropService.zipItems(dropService.droppedItems)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.zipper")
                                .font(.system(size: 9))
                            Text("ZIP")
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.10))
                        .foregroundColor(.white.opacity(0.85))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button("Hapus Semua") {
                        dropService.clearAll()
                    }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.red.opacity(0.85))
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func trayItemCard(_ item: DroppedItem) -> some View {
        HStack(spacing: 8) {
            // Draggable Thumbnail & File Details (Drag directly to Finder / Desktop / Apps)
            HStack(spacing: 8) {
                if item.kind == .image {
                    Image(nsImage: item.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 0.6)
                        )
                } else {
                    Image(nsImage: item.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                }

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(item.name)
                        .font(.system(size: 10.2, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: 108, alignment: .leading)

                    Text("\(item.kind.badgeText) • \(item.sizeFormatted)")
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                        .foregroundColor(.cyan.opacity(0.85))
                }
            }
            .contentShape(Rectangle())
            .onDrag {
                if let provider = NSItemProvider(contentsOf: item.url) {
                    return provider
                }
                return NSItemProvider(object: item.url as NSURL)
            }
            .help("Tarik langsung ke Desktop, Finder, atau aplikasi lain")

            // 1-Click Quick Grab / Copy (Copies both image & file URL!)
            Button {
                dropService.copyItemToClipboard(item)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 8.5, weight: .bold))
                    Text("Salin")
                        .font(.system(size: 8.8, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.26))
                .foregroundColor(.green)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Salin langsung ke Clipboard (siap ⌘V di chat/dokumen/Finder)")

            // 1-Click Ask Maki AI about this Image/Screenshot!
            if item.kind == .image {
                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                        GeminiService.shared.openChatInNotch(attaching: item)
                    }
                } label: {
                    HStack(spacing: 2.5) {
                        Text("💬")
                            .font(.system(size: 8.5))
                        Text("Tanya")
                            .font(.system(size: 8.8, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.26))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Tanyakan isi gambar/screenshot ini ke Maki AI")
            }

            // Primary Studio / Edit / Convert Button
            Button {
                dropService.openStudio(for: item)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 9, weight: .bold))
                    Text(studioButtonLabel(for: item.kind))
                        .font(.system(size: 8.8, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.30))
                .foregroundColor(.cyan)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            HStack(spacing: 5) {
                Button {
                    dropService.openItem(item)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 10.5))
                        .foregroundColor(.white.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Buka File")

                Button {
                    dropService.revealInFinder(item)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 10.5))
                        .foregroundColor(.white.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Tampilkan di Finder")

                Button {
                    dropService.removeItem(item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11.5))
                        .foregroundColor(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
                .help("Hapus dari Tray")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onDrag {
            if let provider = NSItemProvider(contentsOf: item.url) {
                return provider
            }
            return NSItemProvider(object: item.url as NSURL)
        }
        .contextMenu {
            Button("📋 Salin (Siap Paste ⌘V)") {
                dropService.copyItemToClipboard(item)
            }
            Button("✨ Edit / Convert di Studio") {
                dropService.openStudio(for: item)
            }
            Button("Buka File") {
                dropService.openItem(item)
            }
            Button("Tampilkan di Finder") {
                dropService.revealInFinder(item)
            }
            Button("Kompres ke .ZIP") {
                dropService.zipItems([item])
            }
            Divider()
            Button(role: .destructive) {
                dropService.removeItem(item)
            } label: {
                Label("Hapus dari Tray", systemImage: "trash")
            }
        }
    }

    private func studioButtonLabel(for kind: TrayFileKind) -> String {
        switch kind {
        case .pdf:   return "Edit/Convert"
        case .image: return "Convert/OCR"
        case .other: return "Kelola"
        }
    }

    private func runMergeAll() {
        dropService.isBusy = true
        PDFStudioService.mergeIntoPDF(items: dropService.mergeableItems) { res in
            dropService.isBusy = false
            switch res {
            case .success(let outURL):
                NSSound(named: "Glass")?.play()
                dropService.addURLs([outURL])
                dropService.showStatus("Berhasil digabung: \(outURL.lastPathComponent)", outputURL: outURL)
            case .failure(let err):
                dropService.showStatus(err.localizedDescription, outputURL: nil, isError: true)
            }
        }
    }
}
