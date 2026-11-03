import SwiftUI

private enum PDFStudioTab: String, CaseIterable, Identifiable {
    case convert = "Convert & Kompres"
    case pages   = "Edit & Pisah Hal"
    case protect = "Watermark & Kunci"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .convert: return "arrow.triangle.2.circlepath"
        case .pages:   return "doc.on.doc"
        case .protect: return "lock.shield"
        }
    }
}

public struct TrayStudioView: View {
    public let item: DroppedItem
    @ObservedObject var dropService = DropZoneService.shared
    @StateObject private var pdfSession: PDFEditorSession

    @State private var selectedPDFTab: PDFStudioTab = .convert
    @State private var splitRangeText: String = ""
    @State private var watermarkText: String = "CONFIDENTIAL"
    @State private var pdfPassword: String = ""
    @State private var renameInput: String = ""

    public init(item: DroppedItem) {
        self.item = item
        _pdfSession = StateObject(wrappedValue: PDFEditorSession(url: item.url))
        _renameInput = State(initialValue: item.url.deletingPathExtension().lastPathComponent)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: - Top Studio Header
            HStack(spacing: 8) {
                Button {
                    dropService.closeStudio()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("Tray")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)

                Text(item.name)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(item.kind.badgeText) • \(item.sizeFormatted)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.22))
                    .foregroundColor(.cyan)
                    .clipShape(Capsule())

                Spacer()

                if dropService.isBusy {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 16, height: 16)
                }

                Button {
                    dropService.openItem(item)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "eye")
                            .font(.system(size: 9.5))
                        Text("Preview")
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.10))
                    .foregroundColor(.white.opacity(0.85))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // MARK: - Mode Body Based on File Type
            switch item.kind {
            case .pdf:
                pdfStudioContent
            case .image:
                imageStudioContent
            case .other:
                generalFileContent
            }

            // MARK: - Result Banner
            if let banner = dropService.statusBanner {
                statusBannerRow(banner)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - PDF Studio Content
    private var pdfStudioContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Sub-tab selector
            HStack(spacing: 6) {
                ForEach(PDFStudioTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) { selectedPDFTab = tab }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 9.5, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(selectedPDFTab == tab ? Color.blue.opacity(0.32) : Color.white.opacity(0.07))
                        .foregroundColor(selectedPDFTab == tab ? .cyan : .white.opacity(0.6))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    dropService.zipItems([item])
                } label: {
                    Label("Buat .ZIP", systemImage: "doc.zipper")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white.opacity(0.8))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            switch selectedPDFTab {
            case .convert:
                pdfConvertTab
            case .pages:
                pdfPagesEditorTab
            case .protect:
                pdfProtectTab
            }
        }
    }

    // Sub-Tab 1: Convert & Compress PDF
    private var pdfConvertTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Convert format row
            VStack(alignment: .leading, spacing: 4) {
                Text("Convert PDF ke Ekstensi Lain:")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))

                HStack(spacing: 6) {
                    ForEach(PDFExportFormat.allCases) { fmt in
                        Button {
                            runPDFConvert(fmt)
                        } label: {
                            HStack(spacing: 3.5) {
                                Image(systemName: fmt.iconName)
                                    .font(.system(size: 9.5))
                                Text(fmt.rawValue)
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.10))
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(dropService.isBusy)
                    }
                }
            }

            // Compress PDF row
            VStack(alignment: .leading, spacing: 4) {
                Text("Perkecil Ukuran File PDF (Compress):")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))

                HStack(spacing: 6) {
                    ForEach(PDFCompressLevel.allCases) { level in
                        Button {
                            runPDFCompress(level)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: 9))
                                Text(level.rawValue)
                                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(Color.orange.opacity(0.18))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(dropService.isBusy)
                    }
                }
            }

            // Quick Rename row
            inlineRenameRow
        }
    }

    // Sub-Tab 2: Visual Page Editor & Split
    private var pdfPagesEditorTab: some View {
        VStack(alignment: .leading, spacing: 7) {
            // Horizontal Page Thumbnails
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(pdfSession.thumbnails) { thumb in
                        let isSel = (pdfSession.selectedIndex == thumb.index)
                        VStack(spacing: 2) {
                            Image(nsImage: thumb.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 44, height: 58)
                                .background(Color.white)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(isSel ? Color.cyan : Color.white.opacity(0.2), lineWidth: isSel ? 2 : 0.6)
                                )

                            Text("Hal \(thumb.index + 1)")
                                .font(.system(size: 8.5, weight: isSel ? .bold : .medium, design: .rounded))
                                .foregroundColor(isSel ? .cyan : .white.opacity(0.6))
                        }
                        .padding(3)
                        .background(isSel ? Color.blue.opacity(0.22) : Color.clear)
                        .cornerRadius(6)
                        .onTapGesture {
                            pdfSession.selectedIndex = thumb.index
                        }
                    }
                }
            }
            .frame(height: 82)

            // Page Manipulation Toolbar
            HStack(spacing: 5) {
                smallToolBtn(icon: "rotate.left", label: "-90°") { pdfSession.rotateSelected(by: -90) }
                smallToolBtn(icon: "rotate.right", label: "+90°") { pdfSession.rotateSelected(by: 90) }
                smallToolBtn(icon: "arrow.clockwise", label: "Semua") { pdfSession.rotateAll(by: 90) }
                smallToolBtn(icon: "chevron.left", label: "Geser") { pdfSession.moveSelected(offset: -1) }
                smallToolBtn(icon: "chevron.right", label: "Geser") { pdfSession.moveSelected(offset: 1) }

                Button {
                    pdfSession.deleteSelected()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                        Text("Hapus")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.22))
                    .foregroundColor(.red)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(pdfSession.pageCount <= 1)

                smallToolBtn(icon: "plus.rectangle.on.rectangle", label: "Sisipkan") {
                    pdfSession.appendFromFinder()
                }

                Spacer()

                Button {
                    if let saved = pdfSession.saveEditedPDF(overwriteOriginal: false) {
                        dropService.addURLs([saved])
                        dropService.showStatus("PDF hasil edit disimpan: \(saved.lastPathComponent)", outputURL: saved)
                    }
                } label: {
                    Text("Simpan Baru")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if pdfSession.hasUnsavedChanges {
                    Button {
                        if let saved = pdfSession.saveEditedPDF(overwriteOriginal: true) {
                            dropService.refreshItem(item.id)
                            dropService.showStatus("File PDF asli diperbarui!", outputURL: saved)
                        }
                    } label: {
                        Text("Timpa")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .foregroundColor(.black)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Split / Extract Range Row
            HStack(spacing: 6) {
                Text("Pisah Hal:")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))

                TextField("Contoh: 1-3 atau 2,4", text: $splitRangeText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(5)
                    .frame(width: 145)

                Button {
                    runPDFSplit(range: splitRangeText)
                } label: {
                    Text("Ekstrak Range")
                        .font(.system(size: 9.5, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.3))
                        .foregroundColor(.cyan)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(splitRangeText.trimmingCharacters(in: .whitespaces).isEmpty || dropService.isBusy)

                Button {
                    runPDFSplit(range: nil)
                } label: {
                    Text("Pisah Semua Halaman")
                        .font(.system(size: 9.5, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.10))
                        .foregroundColor(.white.opacity(0.85))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(pdfSession.pageCount <= 1 || dropService.isBusy)
            }
        }
    }

    // Sub-Tab 3: Watermark & Password Lock
    private var pdfProtectTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Watermark:")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 72, alignment: .leading)

                TextField("Teks cap diagonal (mis: DRAFT / LUNAS)", text: $watermarkText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.09))
                    .cornerRadius(6)

                Button {
                    runWatermark()
                } label: {
                    Text("Tempel Watermark")
                        .font(.system(size: 9.5, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(Color.purple.opacity(0.35))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(watermarkText.trimmingCharacters(in: .whitespaces).isEmpty || dropService.isBusy)
            }

            HStack(spacing: 8) {
                Text("Password:")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 72, alignment: .leading)

                TextField("Masukkan password untuk mengunci PDF...", text: $pdfPassword)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.09))
                    .cornerRadius(6)

                Button {
                    runPasswordLock()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                        Text("Kunci PDF")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(Color.orange)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(pdfPassword.trimmingCharacters(in: .whitespaces).isEmpty || dropService.isBusy)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Image Studio Content
    private var imageStudioContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Convert Gambar ke Format / PDF:")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))

                HStack(spacing: 6) {
                    ForEach(ImageExportFormat.allCases) { fmt in
                        Button {
                            runImageConvert(to: fmt, scale: 1.0)
                        } label: {
                            Text("Ke \(fmt.rawValue)")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(fmt == .pdf ? Color.blue.opacity(0.32) : Color.white.opacity(0.10))
                                .foregroundColor(fmt == .pdf ? .cyan : .white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(dropService.isBusy)
                    }
                }
            }

            HStack(spacing: 6) {
                Text("Resize & OCR:")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))

                smallToolBtn(icon: "arrow.down.right.and.arrow.up.left", label: "Resize 75%") {
                    runImageConvert(to: .jpg, scale: 0.75)
                }
                smallToolBtn(icon: "arrow.down.right.and.arrow.up.left", label: "Resize 50%") {
                    runImageConvert(to: .jpg, scale: 0.50)
                }

                Button {
                    runImageOCR()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 10))
                        Text("Baca Teks Gambar (OCR → Copy & .TXT)")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Color.green.opacity(0.24))
                    .foregroundColor(.green)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(dropService.isBusy)
            }

            inlineRenameRow
        }
    }

    // MARK: - General File Studio
    private var generalFileContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            inlineRenameRow

            HStack(spacing: 8) {
                Button {
                    dropService.zipItems([item])
                } label: {
                    Label("Kompres ke .ZIP", systemImage: "doc.zipper")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.28))
                        .foregroundColor(.cyan)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    dropService.revealInFinder(item)
                } label: {
                    Label("Tampilkan di Finder", systemImage: "folder")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.10))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Shared Helpers

    private var inlineRenameRow: some View {
        HStack(spacing: 6) {
            Text("Ubah Nama:")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.65))

            TextField("Nama file baru", text: $renameInput)
                .textFieldStyle(.plain)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.08))
                .cornerRadius(5)
                .onSubmit {
                    dropService.renameItem(item, newName: renameInput)
                }

            Button {
                dropService.renameItem(item, newName: renameInput)
            } label: {
                Text("Simpan Nama")
                    .font(.system(size: 9.5, weight: .bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.14))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func smallToolBtn(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.10))
            .foregroundColor(.white.opacity(0.9))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusBannerRow(_ banner: TrayStatusBanner) -> some View {
        HStack(spacing: 8) {
            Image(systemName: banner.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 10.5))
                .foregroundColor(banner.isError ? .red : .green)

            Text(banner.message)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            if let outURL = banner.outputURL {
                Button("Buka") {
                    NSWorkspace.shared.open(outURL)
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.cyan)
                .buttonStyle(.plain)

                Button("Di Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([outURL])
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.yellow)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((banner.isError ? Color.red : Color.green).opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Studio Action Runners

    private func runPDFConvert(_ format: PDFExportFormat) {
        dropService.isBusy = true
        PDFStudioService.convertPDF(url: item.url, to: format) { res in
            dropService.isBusy = false
            switch res {
            case .success(let outURL):
                NSSound(named: "Glass")?.play()
                dropService.addURLs([outURL])
                dropService.showStatus("Selesai convert ke \(format.rawValue): \(outURL.lastPathComponent)", outputURL: outURL)
            case .failure(let err):
                dropService.showStatus(err.localizedDescription, outputURL: nil, isError: true)
            }
        }
    }

    private func runPDFCompress(_ level: PDFCompressLevel) {
        dropService.isBusy = true
        PDFStudioService.compressPDF(url: item.url, level: level) { res in
            dropService.isBusy = false
            switch res {
            case .success(let (outURL, summary)):
                NSSound(named: "Glass")?.play()
                dropService.addURLs([outURL])
                dropService.showStatus("Kompres selesai (\(summary))", outputURL: outURL)
            case .failure(let err):
                dropService.showStatus(err.localizedDescription, outputURL: nil, isError: true)
            }
        }
    }

    private func runPDFSplit(range: String?) {
        dropService.isBusy = true
        PDFStudioService.splitPDF(url: item.url, rangeText: range) { res in
            dropService.isBusy = false
            switch res {
            case .success(let outURL):
                NSSound(named: "Glass")?.play()
                dropService.addURLs([outURL])
                dropService.showStatus("Berhasil dipisah: \(outURL.lastPathComponent)", outputURL: outURL)
            case .failure(let err):
                dropService.showStatus(err.localizedDescription, outputURL: nil, isError: true)
            }
        }
    }

    private func runWatermark() {
        dropService.isBusy = true
        PDFStudioService.addWatermark(url: item.url, text: watermarkText) { res in
            dropService.isBusy = false
            switch res {
            case .success(let outURL):
                NSSound(named: "Glass")?.play()
                dropService.addURLs([outURL])
                dropService.showStatus("Watermark ditambahkan: \(outURL.lastPathComponent)", outputURL: outURL)
            case .failure(let err):
                dropService.showStatus(err.localizedDescription, outputURL: nil, isError: true)
            }
        }
    }

    private func runPasswordLock() {
        dropService.isBusy = true
        PDFStudioService.lockPDFWithPassword(url: item.url, password: pdfPassword) { res in
            dropService.isBusy = false
            switch res {
            case .success(let outURL):
                pdfPassword = ""
                NSSound(named: "Glass")?.play()
                dropService.addURLs([outURL])
                dropService.showStatus("PDF terkunci dibuat: \(outURL.lastPathComponent)", outputURL: outURL)
            case .failure(let err):
                dropService.showStatus(err.localizedDescription, outputURL: nil, isError: true)
            }
        }
    }

    private func runImageConvert(to format: ImageExportFormat, scale: CGFloat) {
        dropService.isBusy = true
        PDFStudioService.convertImage(url: item.url, to: format, scaleFactor: scale) { res in
            dropService.isBusy = false
            switch res {
            case .success(let outURL):
                NSSound(named: "Glass")?.play()
                dropService.addURLs([outURL])
                dropService.showStatus("Gambar disimpan: \(outURL.lastPathComponent)", outputURL: outURL)
            case .failure(let err):
                dropService.showStatus(err.localizedDescription, outputURL: nil, isError: true)
            }
        }
    }

    private func runImageOCR() {
        dropService.isBusy = true
        PDFStudioService.extractImageOCR(url: item.url) { res in
            dropService.isBusy = false
            switch res {
            case .success(let (_, outURL)):
                NSSound(named: "Glass")?.play()
                dropService.addURLs([outURL])
                dropService.showStatus("Teks OCR disalin ke Clipboard & disimpan!", outputURL: outURL)
            case .failure(let err):
                dropService.showStatus(err.localizedDescription, outputURL: nil, isError: true)
            }
        }
    }
}
