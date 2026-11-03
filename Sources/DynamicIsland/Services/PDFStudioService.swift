import Foundation
import AppKit
import PDFKit
import Vision
import UniformTypeIdentifiers

public enum PDFExportFormat: String, CaseIterable, Identifiable {
    case png  = "PNG"
    case jpg  = "JPG"
    case txt  = "TXT (OCR)"
    case md   = "Markdown"
    case rtf  = "RTF (Word)"
    case html = "HTML"
    case tiff = "TIFF"

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .png:  return "png"
        case .jpg:  return "jpg"
        case .txt:  return "txt"
        case .md:   return "md"
        case .rtf:  return "rtf"
        case .html: return "html"
        case .tiff: return "tiff"
        }
    }

    public var iconName: String {
        switch self {
        case .png, .jpg, .tiff: return "photo"
        case .txt:  return "doc.plaintext"
        case .md:   return "text.badge.checkmark"
        case .rtf:  return "doc.richtext"
        case .html: return "globe"
        }
    }
}

public enum ImageExportFormat: String, CaseIterable, Identifiable {
    case pdf  = "PDF"
    case png  = "PNG"
    case jpg  = "JPG"
    case tiff = "TIFF"
    case bmp  = "BMP"

    public var id: String { rawValue }
    public var ext: String { rawValue.lowercased() }
}

public enum PDFCompressLevel: String, CaseIterable, Identifiable {
    case light   = "Ringan (Kualitas Tinggi)"
    case medium  = "Sedang (Ideal)"
    case extreme = "Ekstrem (Ukuran Kecil)"

    public var id: String { rawValue }

    public var scale: CGFloat {
        switch self {
        case .light:   return 1.6
        case .medium:  return 1.2
        case .extreme: return 0.85
        }
    }

    public var jpegQuality: CGFloat {
        switch self {
        case .light:   return 0.78
        case .medium:  return 0.58
        case .extreme: return 0.38
        }
    }
}

public struct PDFPageThumb: Identifiable {
    public let id = UUID()
    public let index: Int
    public let image: NSImage
    public let rotation: Int
}

/// Interactive visual PDF page editor session (Rotate, Reorder, Delete, Append, Save, Split)
public class PDFEditorSession: ObservableObject {
    @Published public var thumbnails: [PDFPageThumb] = []
    @Published public var selectedIndex: Int = 0
    @Published public var hasUnsavedChanges: Bool = false

    public let sourceURL: URL
    public private(set) var document: PDFDocument?

    public init(url: URL) {
        self.sourceURL = url
        self.document = PDFDocument(url: url)
        rebuildThumbnails()
    }

    public var pageCount: Int {
        document?.pageCount ?? 0
    }

    public func rebuildThumbnails() {
        guard let doc = document else {
            thumbnails = []
            return
        }
        var list: [PDFPageThumb] = []
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i) {
                let thumb = page.thumbnail(of: NSSize(width: 110, height: 150), for: .mediaBox)
                list.append(PDFPageThumb(index: i, image: thumb, rotation: page.rotation))
            }
        }
        thumbnails = list
        if selectedIndex >= list.count {
            selectedIndex = max(0, list.count - 1)
        }
    }

    public func rotateSelected(by degrees: Int) {
        guard let doc = document, selectedIndex >= 0, selectedIndex < doc.pageCount,
              let page = doc.page(at: selectedIndex) else { return }
        let next = ((page.rotation + degrees) % 360 + 360) % 360
        page.rotation = next
        hasUnsavedChanges = true
        rebuildThumbnails()
    }

    public func rotateAll(by degrees: Int) {
        guard let doc = document else { return }
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i) {
                page.rotation = ((page.rotation + degrees) % 360 + 360) % 360
            }
        }
        hasUnsavedChanges = true
        rebuildThumbnails()
    }

    public func moveSelected(offset: Int) {
        guard let doc = document else { return }
        let target = selectedIndex + offset
        guard selectedIndex >= 0, selectedIndex < doc.pageCount,
              target >= 0, target < doc.pageCount else { return }
        doc.exchangePage(at: selectedIndex, withPageAt: target)
        selectedIndex = target
        hasUnsavedChanges = true
        rebuildThumbnails()
    }

    public func deleteSelected() {
        guard let doc = document, doc.pageCount > 1,
              selectedIndex >= 0, selectedIndex < doc.pageCount else { return }
        doc.removePage(at: selectedIndex)
        hasUnsavedChanges = true
        rebuildThumbnails()
    }

    public func appendFromFinder() {
        IslandState.shared.isModalOpen = true
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = "Sisipkan PDF atau Gambar ke Halaman Akhir"
        panel.prompt = "Sisipkan"
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.pdf, .image]
        panel.level = .modalPanel

        panel.begin { [weak self] response in
            DispatchQueue.main.async {
                IslandState.shared.isModalOpen = false
                IslandController.shared.panel?.makeKeyAndOrderFront(nil)
                guard response == .OK, let self = self, let doc = self.document else { return }

                for url in panel.urls {
                    if url.pathExtension.lowercased() == "pdf", let otherDoc = PDFDocument(url: url) {
                        for p in 0..<otherDoc.pageCount {
                            if let page = otherDoc.page(at: p) {
                                doc.insert(page, at: doc.pageCount)
                            }
                        }
                    } else if let img = NSImage(contentsOf: url), let page = PDFPage(image: img) {
                        doc.insert(page, at: doc.pageCount)
                    }
                }
                self.hasUnsavedChanges = true
                self.rebuildThumbnails()
                NSSound(named: "Pop")?.play()
            }
        }
    }

    public func saveEditedPDF(overwriteOriginal: Bool) -> URL? {
        guard let doc = document else { return nil }
        let outURL: URL
        if overwriteOriginal {
            outURL = sourceURL
        } else {
            let dir = PDFStudioService.writableOutputDirectory(near: sourceURL)
            let base = sourceURL.deletingPathExtension().lastPathComponent + "_edited"
            outURL = PDFStudioService.uniqueOutputURL(in: dir, baseName: base, ext: "pdf")
        }

        if doc.write(to: outURL) {
            if overwriteOriginal {
                hasUnsavedChanges = false
            }
            NSSound(named: "Glass")?.play()
            return outURL
        }
        return nil
    }
}

public class PDFStudioService {

    // MARK: - Output Path Helpers

    public static func writableOutputDirectory(near sourceURL: URL) -> URL {
        let parent = sourceURL.deletingLastPathComponent()
        if FileManager.default.isWritableFile(atPath: parent.path) {
            return parent
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }

    public static func uniqueOutputURL(in directory: URL, baseName: String, ext: String) -> URL {
        let fm = FileManager.default
        let first = ext.isEmpty
            ? directory.appendingPathComponent(baseName)
            : directory.appendingPathComponent("\(baseName).\(ext)")
        if !fm.fileExists(atPath: first.path) {
            return first
        }
        for i in 1...999 {
            let candidate = ext.isEmpty
                ? directory.appendingPathComponent("\(baseName)_\(i)")
                : directory.appendingPathComponent("\(baseName)_\(i).\(ext)")
            if !fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return first
    }

    // MARK: - Render PDFPage to Bitmap

    public static func renderPage(_ page: PDFPage, scale: CGFloat = 2.0) -> NSBitmapImageRep? {
        let bounds = page.bounds(for: .mediaBox)
        let pixelW = max(1, Int(bounds.width * scale))
        let pixelH = max(1, Int(bounds.height * scale))

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelW,
            pixelsHigh: pixelH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let nsCtx = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx
        let cg = nsCtx.cgContext
        cg.setFillColor(NSColor.white.cgColor)
        cg.fill(CGRect(x: 0, y: 0, width: CGFloat(pixelW), height: CGFloat(pixelH)))
        cg.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: cg)
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    // MARK: - Vision OCR Helper

    public static func performOCR(on cgImage: CGImage) -> String {
        var recognizedLines: [String] = []
        let request = VNRecognizeTextRequest { req, _ in
            guard let observations = req.results as? [VNRecognizedTextObservation] else { return }
            for obs in observations {
                if let top = obs.topCandidates(1).first {
                    recognizedLines.append(top.string)
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        return recognizedLines.joined(separator: "\n")
    }

    public static func extractPageText(_ page: PDFPage) -> String {
        if let direct = page.string, !direct.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return direct.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Fallback to Apple Vision OCR for scanned PDFs!
        if let rep = renderPage(page, scale: 2.0), let cg = rep.cgImage {
            return performOCR(on: cg)
        }
        return ""
    }

    // MARK: - 1. Convert PDF to Other Extensions

    public static func convertPDF(
        url: URL,
        to format: PDFExportFormat,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let doc = PDFDocument(url: url), doc.pageCount > 0 else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PDFStudio", code: 1, userInfo: [NSLocalizedDescriptionKey: "File PDF tidak dapat dibaca"])))
                }
                return
            }

            let dir = writableOutputDirectory(near: url)
            let base = url.deletingPathExtension().lastPathComponent

            do {
                let resultURL: URL

                switch format {
                case .png, .jpg, .tiff:
                    if doc.pageCount == 1, let page = doc.page(at: 0), let rep = renderPage(page, scale: 2.0) {
                        let out = uniqueOutputURL(in: dir, baseName: base, ext: format.fileExtension)
                        let data = imageData(from: rep, format: format)
                        guard let d = data else { throw NSError(domain: "PDFStudio", code: 2, userInfo: [NSLocalizedDescriptionKey: "Gagal merender gambar"]) }
                        try d.write(to: out, options: .atomic)
                        resultURL = out
                    } else {
                        let folder = uniqueOutputURL(in: dir, baseName: "\(base)_\(format.fileExtension.uppercased())", ext: "")
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        for i in 0..<doc.pageCount {
                            if let page = doc.page(at: i), let rep = renderPage(page, scale: 2.0),
                               let d = imageData(from: rep, format: format) {
                                let fileURL = folder.appendingPathComponent(String(format: "Halaman_%02d.%@", i + 1, format.fileExtension))
                                try d.write(to: fileURL, options: .atomic)
                            }
                        }
                        resultURL = folder
                    }

                case .txt:
                    var sections: [String] = []
                    for i in 0..<doc.pageCount {
                        if let page = doc.page(at: i) {
                            let txt = extractPageText(page)
                            if doc.pageCount > 1 {
                                sections.append("--- Halaman \(i + 1) ---\n\(txt)")
                            } else {
                                sections.append(txt)
                            }
                        }
                    }
                    let out = uniqueOutputURL(in: dir, baseName: base, ext: "txt")
                    try sections.joined(separator: "\n\n").write(to: out, atomically: true, encoding: .utf8)
                    resultURL = out

                case .md:
                    var md = "# \(base)\n\n"
                    for i in 0..<doc.pageCount {
                        if let page = doc.page(at: i) {
                            let txt = extractPageText(page)
                            md += "## Halaman \(i + 1)\n\n\(txt)\n\n"
                        }
                    }
                    let out = uniqueOutputURL(in: dir, baseName: base, ext: "md")
                    try md.write(to: out, atomically: true, encoding: .utf8)
                    resultURL = out

                case .rtf:
                    let fullAttr = NSMutableAttributedString()
                    let headingAttrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.boldSystemFont(ofSize: 13)
                    ]
                    let bodyAttrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 11)
                    ]
                    for i in 0..<doc.pageCount {
                        if let page = doc.page(at: i) {
                            if doc.pageCount > 1 {
                                fullAttr.append(NSAttributedString(string: "Halaman \(i + 1)\n", attributes: headingAttrs))
                            }
                            if let pageAttr = page.attributedString, pageAttr.length > 0 {
                                fullAttr.append(pageAttr)
                                fullAttr.append(NSAttributedString(string: "\n\n", attributes: bodyAttrs))
                            } else {
                                let ocrTxt = extractPageText(page)
                                fullAttr.append(NSAttributedString(string: ocrTxt + "\n\n", attributes: bodyAttrs))
                            }
                        }
                    }
                    let out = uniqueOutputURL(in: dir, baseName: base, ext: "rtf")
                    let rtfData = try fullAttr.data(
                        from: NSRange(location: 0, length: fullAttr.length),
                        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                    )
                    try rtfData.write(to: out, options: .atomic)
                    resultURL = out

                case .html:
                    var html = """
                    <!DOCTYPE html>
                    <html lang="id"><head><meta charset="utf-8"><title>\(base)</title>
                    <style>body{font-family:-apple-system,sans-serif;max-width:780px;margin:32px auto;line-height:1.6;color:#1d1d1f;padding:0 16px;}
                    .page{border:1px solid #e5e5ea;border-radius:12px;padding:24px;margin-bottom:20px;white-space:pre-wrap;}</style></head><body>
                    <h1>\(base)</h1>
                    """
                    for i in 0..<doc.pageCount {
                        if let page = doc.page(at: i) {
                            let escaped = extractPageText(page)
                                .replacingOccurrences(of: "&", with: "&amp;")
                                .replacingOccurrences(of: "<", with: "&lt;")
                                .replacingOccurrences(of: ">", with: "&gt;")
                            html += "<div class=\"page\"><h3>Halaman \(i + 1)</h3>\(escaped)</div>"
                        }
                    }
                    html += "</body></html>"
                    let out = uniqueOutputURL(in: dir, baseName: base, ext: "html")
                    try html.write(to: out, atomically: true, encoding: .utf8)
                    resultURL = out
                }

                DispatchQueue.main.async {
                    completion(.success(resultURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private static func imageData(from rep: NSBitmapImageRep, format: PDFExportFormat) -> Data? {
        switch format {
        case .png:
            return rep.representation(using: .png, properties: [:])
        case .jpg:
            return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.86])
        case .tiff:
            return rep.representation(using: .tiff, properties: [:])
        default:
            return nil
        }
    }

    // MARK: - 2. Compress PDF

    public static func compressPDF(
        url: URL,
        level: PDFCompressLevel,
        completion: @escaping (Result<(URL, String), Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let srcDoc = PDFDocument(url: url), srcDoc.pageCount > 0 else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PDFStudio", code: 3, userInfo: [NSLocalizedDescriptionKey: "Gagal membuka PDF"])))
                }
                return
            }

            let oldSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            let outDoc = PDFDocument()

            for i in 0..<srcDoc.pageCount {
                guard let page = srcDoc.page(at: i),
                      let rep = renderPage(page, scale: level.scale),
                      let jpgData = rep.representation(using: .jpeg, properties: [.compressionFactor: level.jpegQuality]),
                      let compressedImg = NSImage(data: jpgData),
                      let newPage = PDFPage(image: compressedImg) else { continue }
                outDoc.insert(newPage, at: outDoc.pageCount)
            }

            let dir = writableOutputDirectory(near: url)
            let base = url.deletingPathExtension().lastPathComponent + "_compressed"
            let outURL = uniqueOutputURL(in: dir, baseName: base, ext: "pdf")

            if outDoc.write(to: outURL) {
                let newSize = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int64) ?? 0
                let fmt = ByteCountFormatter()
                fmt.countStyle = .file
                let summary = "\(fmt.string(fromByteCount: oldSize)) → \(fmt.string(fromByteCount: newSize))"
                DispatchQueue.main.async {
                    completion(.success((outURL, summary)))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PDFStudio", code: 4, userInfo: [NSLocalizedDescriptionKey: "Gagal menyimpan PDF terkompresi"])))
                }
            }
        }
    }

    // MARK: - 3. Split / Extract Page Range

    public static func splitPDF(
        url: URL,
        rangeText: String?, // nil = split every single page into a folder
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let doc = PDFDocument(url: url), doc.pageCount > 0 else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PDFStudio", code: 5, userInfo: [NSLocalizedDescriptionKey: "Gagal membuka PDF"])))
                }
                return
            }

            let dir = writableOutputDirectory(near: url)
            let base = url.deletingPathExtension().lastPathComponent

            if let rangeStr = rangeText?.trimmingCharacters(in: .whitespacesAndNewlines), !rangeStr.isEmpty {
                let indices = parsePageRange(rangeStr, maxPages: doc.pageCount)
                guard !indices.isEmpty else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "PDFStudio", code: 6, userInfo: [NSLocalizedDescriptionKey: "Format halaman tidak valid (contoh: 1-3 atau 1,4)"])))
                    }
                    return
                }
                let outDoc = PDFDocument()
                for idx in indices {
                    if let p = doc.page(at: idx), let copyPage = p.copy() as? PDFPage {
                        outDoc.insert(copyPage, at: outDoc.pageCount)
                    }
                }
                let safeLabel = rangeStr.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: "_")
                let outURL = uniqueOutputURL(in: dir, baseName: "\(base)_hal_\(safeLabel)", ext: "pdf")
                if outDoc.write(to: outURL) {
                    DispatchQueue.main.async { completion(.success(outURL)) }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "PDFStudio", code: 7, userInfo: [NSLocalizedDescriptionKey: "Gagal menulis PDF baru"])))
                    }
                }
            } else {
                // Split all pages into individual PDFs in a folder
                let folder = uniqueOutputURL(in: dir, baseName: "\(base)_Split", ext: "")
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    for i in 0..<doc.pageCount {
                        if let p = doc.page(at: i), let copyPage = p.copy() as? PDFPage {
                            let single = PDFDocument()
                            single.insert(copyPage, at: 0)
                            let pageURL = folder.appendingPathComponent(String(format: "%@_Hal_%02d.pdf", base, i + 1))
                            _ = single.write(to: pageURL)
                        }
                    }
                    DispatchQueue.main.async { completion(.success(folder)) }
                } catch {
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
            }
        }
    }

    private static func parsePageRange(_ input: String, maxPages: Int) -> [Int] {
        var result: [Int] = []
        let parts = input.components(separatedBy: ",")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("-") {
                let bounds = trimmed.components(separatedBy: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                if bounds.count == 2 {
                    let start = max(1, min(bounds[0], bounds[1]))
                    let end = min(maxPages, max(bounds[0], bounds[1]))
                    if start <= end {
                        for p in start...end { result.append(p - 1) }
                    }
                }
            } else if let single = Int(trimmed), single >= 1, single <= maxPages {
                result.append(single - 1)
            }
        }
        return result
    }

    // MARK: - 4. Merge Multiple PDFs & Images into 1 PDF

    public static func mergeIntoPDF(
        items: [DroppedItem],
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let first = items.first else { return }
            let merged = PDFDocument()

            for item in items {
                let ext = item.url.pathExtension.lowercased()
                if ext == "pdf", let doc = PDFDocument(url: item.url) {
                    for i in 0..<doc.pageCount {
                        if let page = doc.page(at: i), let copyPage = page.copy() as? PDFPage {
                            merged.insert(copyPage, at: merged.pageCount)
                        }
                    }
                } else if let img = NSImage(contentsOf: item.url), let page = PDFPage(image: img) {
                    merged.insert(page, at: merged.pageCount)
                }
            }

            guard merged.pageCount > 0 else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PDFStudio", code: 8, userInfo: [NSLocalizedDescriptionKey: "Tidak ada halaman valid untuk digabung"])))
                }
                return
            }

            let dir = writableOutputDirectory(near: first.url)
            let outURL = uniqueOutputURL(in: dir, baseName: "Gabungan_\(items.count)_Dokumen", ext: "pdf")
            if merged.write(to: outURL) {
                DispatchQueue.main.async { completion(.success(outURL)) }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PDFStudio", code: 9, userInfo: [NSLocalizedDescriptionKey: "Gagal menyimpan PDF gabungan"])))
                }
            }
        }
    }

    // MARK: - 5. Add Vector Watermark Stamp & Password Lock

    public static func addWatermark(
        url: URL,
        text: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let stamp = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !stamp.isEmpty, let doc = PDFDocument(url: url), doc.pageCount > 0 else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PDFStudio", code: 10, userInfo: [NSLocalizedDescriptionKey: "Teks watermark kosong atau PDF tidak valid"])))
                }
                return
            }

            let dir = writableOutputDirectory(near: url)
            let base = url.deletingPathExtension().lastPathComponent + "_watermark"
            let outURL = uniqueOutputURL(in: dir, baseName: base, ext: "pdf")

            var defaultBox = doc.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 612, height: 792)
            guard let pdfCtx = CGContext(outURL as CFURL, mediaBox: &defaultBox, nil) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PDFStudio", code: 11, userInfo: [NSLocalizedDescriptionKey: "Gagal membuat konteks PDF"])))
                }
                return
            }

            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                var pageBox = page.bounds(for: .mediaBox)
                pdfCtx.beginPage(mediaBox: &pageBox)
                page.draw(with: .mediaBox, to: pdfCtx)

                // Draw semi-transparent diagonal watermark text
                pdfCtx.saveGState()
                let nsCtx = NSGraphicsContext(cgContext: pdfCtx, flipped: false)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = nsCtx

                let fontSize = max(24, min(pageBox.width, pageBox.height) * 0.085)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: fontSize),
                    .foregroundColor: NSColor.red.withAlphaComponent(0.20)
                ]
                let nsStr = stamp as NSString
                let textSize = nsStr.size(withAttributes: attrs)

                pdfCtx.translateBy(x: pageBox.midX, y: pageBox.midY)
                pdfCtx.rotate(by: .pi / 5.5)
                nsStr.draw(at: NSPoint(x: -textSize.width / 2, y: -textSize.height / 2), withAttributes: attrs)

                NSGraphicsContext.restoreGraphicsState()
                pdfCtx.restoreGState()
                pdfCtx.endPage()
            }
            pdfCtx.closePDF()

            DispatchQueue.main.async {
                completion(.success(outURL))
            }
        }
    }

    public static func lockPDFWithPassword(
        url: URL,
        password: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let pwd = password.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pwd.isEmpty, let doc = PDFDocument(url: url) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PDFStudio", code: 12, userInfo: [NSLocalizedDescriptionKey: "Password tidak boleh kosong"])))
                }
                return
            }

            let dir = writableOutputDirectory(near: url)
            let base = url.deletingPathExtension().lastPathComponent + "_locked"
            let outURL = uniqueOutputURL(in: dir, baseName: base, ext: "pdf")

            let ok = doc.write(to: outURL, withOptions: [
                .userPasswordOption: pwd,
                .ownerPasswordOption: pwd
            ])

            DispatchQueue.main.async {
                if ok {
                    completion(.success(outURL))
                } else {
                    completion(.failure(NSError(domain: "PDFStudio", code: 13, userInfo: [NSLocalizedDescriptionKey: "Gagal mengunci PDF"])))
                }
            }
        }
    }

    // MARK: - 6. Image Convert, Resize & OCR Tools

    public static func convertImage(
        url: URL,
        to format: ImageExportFormat,
        scaleFactor: CGFloat = 1.0,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let img = NSImage(contentsOf: url) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PDFStudio", code: 14, userInfo: [NSLocalizedDescriptionKey: "Gagal membaca gambar"])))
                }
                return
            }

            let dir = writableOutputDirectory(near: url)
            let suffix = scaleFactor < 0.99 ? "_\(Int(scaleFactor * 100))pct" : "_converted"
            let base = url.deletingPathExtension().lastPathComponent + suffix
            let outURL = uniqueOutputURL(in: dir, baseName: base, ext: format.ext)

            if format == .pdf {
                let doc = PDFDocument()
                if let page = PDFPage(image: img) {
                    doc.insert(page, at: 0)
                }
                if doc.write(to: outURL) {
                    DispatchQueue.main.async { completion(.success(outURL)) }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "PDFStudio", code: 15, userInfo: [NSLocalizedDescriptionKey: "Gagal membuat PDF dari gambar"])))
                    }
                }
                return
            }

            guard let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PDFStudio", code: 16, userInfo: [NSLocalizedDescriptionKey: "Format gambar tidak didukung"])))
                }
                return
            }

            let targetW = max(1, Int(CGFloat(cg.width) * scaleFactor))
            let targetH = max(1, Int(CGFloat(cg.height) * scaleFactor))

            guard let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: targetW,
                pixelsHigh: targetH,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .calibratedRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ), let nsCtx = NSGraphicsContext(bitmapImageRep: rep) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PDFStudio", code: 17, userInfo: [NSLocalizedDescriptionKey: "Gagal merender gambar"])))
                }
                return
            }

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsCtx
            if format == .jpg || format == .bmp {
                nsCtx.cgContext.setFillColor(NSColor.white.cgColor)
                nsCtx.cgContext.fill(CGRect(x: 0, y: 0, width: targetW, height: targetH))
            }
            nsCtx.cgContext.interpolationQuality = .high
            nsCtx.cgContext.draw(cg, in: CGRect(x: 0, y: 0, width: targetW, height: targetH))
            NSGraphicsContext.restoreGraphicsState()

            let fileType: NSBitmapImageRep.FileType
            var props: [NSBitmapImageRep.PropertyKey: Any] = [:]
            switch format {
            case .png:  fileType = .png
            case .jpg:  fileType = .jpeg; props[.compressionFactor] = 0.85
            case .tiff: fileType = .tiff
            case .bmp:  fileType = .bmp
            case .pdf:  fileType = .png
            }

            if let data = rep.representation(using: fileType, properties: props) {
                do {
                    try data.write(to: outURL, options: .atomic)
                    DispatchQueue.main.async { completion(.success(outURL)) }
                } catch {
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PDFStudio", code: 18, userInfo: [NSLocalizedDescriptionKey: "Gagal mengonversi gambar"])))
                }
            }
        }
    }

    public static func extractImageOCR(
        url: URL,
        completion: @escaping (Result<(String, URL), Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let img = NSImage(contentsOf: url),
                  let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PDFStudio", code: 19, userInfo: [NSLocalizedDescriptionKey: "Gambar tidak valid"])))
                }
                return
            }

            let text = performOCR(on: cg)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PDFStudio", code: 20, userInfo: [NSLocalizedDescriptionKey: "Tidak ditemukan teks pada gambar"])))
                }
                return
            }

            let dir = writableOutputDirectory(near: url)
            let base = url.deletingPathExtension().lastPathComponent + "_OCR"
            let outURL = uniqueOutputURL(in: dir, baseName: base, ext: "txt")
            try? text.write(to: outURL, atomically: true, encoding: .utf8)

            DispatchQueue.main.async {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                completion(.success((text, outURL)))
            }
        }
    }
}
