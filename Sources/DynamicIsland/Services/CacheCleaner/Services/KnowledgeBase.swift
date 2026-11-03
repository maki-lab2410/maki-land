import Foundation

public struct KnowledgeRule: Sendable {
    public let matchPattern: String // Prefix, exact, or contains
    public let appName: String
    public let category: CacheCategory
    public let riskLevel: RiskLevel
    public let contentDescription: String
    public let impactDescription: String

    public init(
        matchPattern: String,
        appName: String,
        category: CacheCategory,
        riskLevel: RiskLevel,
        contentDescription: String,
        impactDescription: String
    ) {
        self.matchPattern = matchPattern
        self.appName = appName
        self.category = category
        self.riskLevel = riskLevel
        self.contentDescription = contentDescription
        self.impactDescription = impactDescription
    }
}

public final class KnowledgeBase: Sendable {
    public static let shared = KnowledgeBase()

    private let exactPathRules: [String: KnowledgeRule]
    private let patternRules: [KnowledgeRule]

    public init() {
        var exacts: [String: KnowledgeRule] = [:]
        var patterns: [KnowledgeRule] = []

        // MARK: - Exact or Path Rules
        let derivedData = KnowledgeRule(
            matchPattern: "DerivedData",
            appName: "Xcode DerivedData",
            category: .developer,
            riskLevel: .verySafe,
            contentDescription: "Menyimpan file intermediate build, metadata indexing Swift/Clang, modul yang dikompilasi, dan produk build sementara oleh Xcode.",
            impactDescription: "Xcode akan mengindeks ulang proyek (indexing) dan meng-compile ulang dari awal (clean build) saat build berikutnya. Tidak ada kode sumber yang hilang."
        )
        exacts["DerivedData"] = derivedData
        patterns.append(derivedData)

        let deviceSupport = KnowledgeRule(
            matchPattern: "iOS DeviceSupport",
            appName: "Xcode iOS DeviceSupport",
            category: .developer,
            riskLevel: .needsAttention,
            contentDescription: "Simbol debug sistem operasi untuk perangkat iOS fisik yang pernah disambungkan ke Mac ini.",
            impactDescription: "Xcode akan mengekstrak ulang simbol debug ini (memakan waktu 5-15 menit) saat Anda menyambungkan kembali iPhone/iPad dengan versi iOS terkait untuk debugging."
        )
        exacts["iOS DeviceSupport"] = deviceSupport
        patterns.append(deviceSupport)

        let coreSim = KnowledgeRule(
            matchPattern: "CoreSimulator/Caches",
            appName: "Xcode CoreSimulator Caches",
            category: .developer,
            riskLevel: .verySafe,
            contentDescription: "Cache image runtime dan data sementara sistem simulator iOS, watchOS, dan tvOS.",
            impactDescription: "Simulator akan membuat ulang cache runtime secara otomatis saat simulator dijalankan kembali."
        )
        exacts["CoreSimulator/Caches"] = coreSim
        patterns.append(coreSim)

        let npmCache = KnowledgeRule(
            matchPattern: "_cacache",
            appName: "Node.js NPM Cache",
            category: .packageManagers,
            riskLevel: .verySafe,
            contentDescription: "Cache arsip paket tarball npm yang telah diunduh dari registry npmjs.org.",
            impactDescription: "Menjalankan 'npm install' pada paket baru akan mengunduh dari internet jika belum ada di node_modules lokal."
        )
        exacts["_cacache"] = npmCache
        patterns.append(npmCache)

        let gradleCache = KnowledgeRule(
            matchPattern: ".gradle/caches",
            appName: "Gradle Build Cache",
            category: .packageManagers,
            riskLevel: .verySafe,
            contentDescription: "Cache artifak dependency Maven/Gradle, plugin, dan jar file yang diunduh untuk proyek JVM/Android.",
            impactDescription: "Gradle akan mengunduh ulang dependensi dari repositori online saat kompilasi proyek berikutnya."
        )
        exacts[".gradle/caches"] = gradleCache
        patterns.append(gradleCache)

        let dotCache = KnowledgeRule(
            matchPattern: ".cache",
            appName: "User Generic Tools Cache (~/.cache)",
            category: .packageManagers,
            riskLevel: .safe,
            contentDescription: "Cache tool CLI pengembang seperti pip (Python), yarn, huggingface, atau utilitas open source Linux/macOS.",
            impactDescription: "Tool CLI terkait akan mengunduh kembali file cache yang diperlukan pada eksekusi berikutnya."
        )
        exacts[".cache"] = dotCache
        patterns.append(dotCache)

        let cargoCache = KnowledgeRule(
            matchPattern: "cargo/registry/cache",
            appName: "Rust Cargo Cache",
            category: .packageManagers,
            riskLevel: .verySafe,
            contentDescription: "File .crate arsip paket dependensi Rust yang diunduh dari crates.io.",
            impactDescription: "Cargo akan mengunduh ulang file crate yang diperlukan saat kompilasi proyek baru."
        )
        exacts["cargo/registry/cache"] = cargoCache
        patterns.append(cargoCache)

        let cocoapodsCache = KnowledgeRule(
            matchPattern: "cocoapods/cache",
            appName: "CocoaPods Cache",
            category: .packageManagers,
            riskLevel: .verySafe,
            contentDescription: "Cache arsip Pods iOS/macOS yang telah diunduh dari GitHub atau CDN.",
            impactDescription: "CocoaPods akan mengunduh ulang pod dari repo jika dipanggil 'pod install'."
        )
        exacts["cocoapods/cache"] = cocoapodsCache
        patterns.append(cocoapodsCache)

        // MARK: - Pattern Rules (Bundle IDs & Folders)

        // Web Browsers
        patterns.append(KnowledgeRule(
            matchPattern: "com.google.Chrome",
            appName: "Google Chrome",
            category: .browsers,
            riskLevel: .safe,
            contentDescription: "File cache halaman web, gambar, favicon, shader GPU, dan resource HTTP yang diunduh.",
            impactDescription: "Google Chrome akan memuat halaman web lebih lambat pada kunjungan pertama karena resource akan diunduh ulang. Riwayat bookmark & password tetap aman."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "company.thebrowser.Browser",
            appName: "Arc Browser",
            category: .browsers,
            riskLevel: .safe,
            contentDescription: "Cache halaman web, preview live icon tab, dan resource sementara Arc Browser.",
            impactDescription: "Halaman web yang sering dikunjungi akan diunduh ulang dari internet pada kunjungan pertama."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "com.apple.Safari",
            appName: "Apple Safari",
            category: .browsers,
            riskLevel: .safe,
            contentDescription: "Cache web WebKit, thumbnail tab pratinjau, dan asset website offline Safari.",
            impactDescription: "Safari akan mengunduh ulang aset web pada kunjungan situs berikutnya. Bookmark dan riwayat tersimpan terpisah."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "org.mozilla.firefox",
            appName: "Mozilla Firefox",
            category: .browsers,
            riskLevel: .safe,
            contentDescription: "Cache HTTP, cache bytecode JavaScript, dan database cache startup Firefox.",
            impactDescription: "Firefox akan memuat ulang aset website dari server pada kunjungan awal."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "com.microsoft.edgemac",
            appName: "Microsoft Edge",
            category: .browsers,
            riskLevel: .safe,
            contentDescription: "Cache halaman web Chromium, aset rendering, dan temporary files Edge.",
            impactDescription: "Halaman web akan diunduh ulang saat pertama kali dibuka."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "com.brave.Browser",
            appName: "Brave Browser",
            category: .browsers,
            riskLevel: .safe,
            contentDescription: "Cache web Chromium, Shields asset cache, dan file sementara Brave.",
            impactDescription: "Aset website akan diunduh ulang saat browsing."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "com.operasoftware.Opera",
            appName: "Opera Browser",
            category: .browsers,
            riskLevel: .safe,
            contentDescription: "Cache browsing web Opera dan temporary downloads.",
            impactDescription: "Website akan memuat ulang resource pada kunjungan awal."
        ))

        // Media & Streaming
        patterns.append(KnowledgeRule(
            matchPattern: "com.spotify.client",
            appName: "Spotify Music",
            category: .mediaStreaming,
            riskLevel: .safe,
            contentDescription: "Cache streaming audio, cover album resolusi tinggi, dan track buffer playlist.",
            impactDescription: "Spotify akan mengunduh ulang cover album dan lagu streaming saat diputar kembali."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "com.apple.Music",
            appName: "Apple Music",
            category: .mediaStreaming,
            riskLevel: .safe,
            contentDescription: "Cache artwork album, preview lagu, dan data streaming Apple Music.",
            impactDescription: "Apple Music akan mengunduh ulang artwork saat Anda menelusuri katalog."
        ))

        // Communication & Chat
        patterns.append(KnowledgeRule(
            matchPattern: "com.tinyspeck.slackmacgap",
            appName: "Slack",
            category: .communication,
            riskLevel: .safe,
            contentDescription: "Cache gambar obrolan, lampiran file yang dipratinjau, avatar tim, dan emoji kustom.",
            impactDescription: "Slack akan mengunduh ulang avatar dan lampiran chat saat Anda menggulir ke percakapan lama."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "com.hnc.Discord",
            appName: "Discord",
            category: .communication,
            riskLevel: .safe,
            contentDescription: "Cache emotikon kustom, avatar pengguna, file media percakapan, dan audio cache.",
            impactDescription: "Emote kustom dan avatar server akan diunduh ulang saat Anda membuka channel percakapan."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "ru.keepcoder.Telegram",
            appName: "Telegram Desktop",
            category: .communication,
            riskLevel: .safe,
            contentDescription: "Cache stiker animasi, foto profil, dan media pesan yang telah tersimpan di Mac.",
            impactDescription: "Media stiker dan foto di obrolan akan diunduh ulang secara otomatis saat Anda membuka pesan terkait."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "net.whatsapp.WhatsApp",
            appName: "WhatsApp Desktop",
            category: .communication,
            riskLevel: .safe,
            contentDescription: "Cache thumbnail obrolan, status media, dan file cache sementara WhatsApp.",
            impactDescription: "Thumbnail obrolan dan status akan dimuat ulang dari server WhatsApp."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "us.zoom.xos",
            appName: "Zoom Video Meetings",
            category: .communication,
            riskLevel: .verySafe,
            contentDescription: "Log koneksi video temporer, cache avatar partisipan, dan update installer Zoom.",
            impactDescription: "Tidak ada dampak fungsionalitas, aplikasi Zoom tetap berjalan normal."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "com.microsoft.teams2",
            appName: "Microsoft Teams",
            category: .communication,
            riskLevel: .safe,
            contentDescription: "Cache pesan, preview lampiran file, dan token rendering Teams.",
            impactDescription: "Teams akan sinkronisasi ulang konten chat dan profil organisasi."
        ))

        // Developer Tools
        patterns.append(KnowledgeRule(
            matchPattern: "com.microsoft.VSCode",
            appName: "Visual Studio Code",
            category: .developer,
            riskLevel: .verySafe,
            contentDescription: "Cache ekstensi, cache editor temporary, telemetry buffer, dan file update ShipIt.",
            impactDescription: "VS Code akan memuat ekstensi dan workspace baru sedikit lebih lambat pada pembukaan pertama."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "org.swift.swiftpm",
            appName: "Swift Package Manager Cache",
            category: .developer,
            riskLevel: .verySafe,
            contentDescription: "Repositori git remote yang di-clone untuk paket dependensi Swift dan index manifest.",
            impactDescription: "SwiftPM / Xcode akan meng-clone ulang git repository dependensi saat 'Resolve Package Dependencies' dipanggil."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "com.docker.docker",
            appName: "Docker Desktop",
            category: .developer,
            riskLevel: .verySafe,
            contentDescription: "Log dan temporary socket cache aplikasi Docker Desktop.",
            impactDescription: "Docker Desktop akan membuat ulang socket dan log baru tanpa mempengaruhi images/container Anda."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "Homebrew",
            appName: "Homebrew Package Cache",
            category: .packageManagers,
            riskLevel: .verySafe,
            contentDescription: "File arsip formula/bottle (.tar.gz, .bottle) yang sudah diunduh sebelumnya.",
            impactDescription: "Jika suatu paket di-reinstall, Homebrew akan mengunduhnya ulang dari mirror online."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "JetBrains",
            appName: "JetBrains IDEs",
            category: .developer,
            riskLevel: .verySafe,
            contentDescription: "Cache indeks kode, parser sintaks, dan temporary files IntelliJ / PyCharm / WebStorm.",
            impactDescription: "IDE akan mengindeks ulang proyek (re-indexing) saat dibuka kembali."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "AndroidStudio",
            appName: "Android Studio",
            category: .developer,
            riskLevel: .verySafe,
            contentDescription: "Cache build Gradle, IDE index, dan compiler cache Android Studio.",
            impactDescription: "Android Studio akan mengindeks ulang proyek pada sesi berikutnya."
        ))

        // System & Logs
        patterns.append(KnowledgeRule(
            matchPattern: "Library/Logs",
            appName: "System & App Logs",
            category: .systemLogs,
            riskLevel: .verySafe,
            contentDescription: "Catatan riwayat aktivitas, error, dan crash log aplikasi pengguna serta proses background macOS.",
            impactDescription: "Riwayat log lama akan dibersihkan. Tidak ada dampak fungsionalitas bagi aplikasi maupun macOS."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "com.apple.QuickLook.thumbnailcache",
            appName: "QuickLook Thumbnails",
            category: .utilities,
            riskLevel: .verySafe,
            contentDescription: "Cache thumbnail pratinjau Finder saat menekan tombol Spasi.",
            impactDescription: "Finder akan membuat thumbnail baru saat file dipratinjau dengan tombol Spasi."
        ))

        patterns.append(KnowledgeRule(
            matchPattern: "com.apple.CloudKit",
            appName: "iCloud Sync Cache",
            category: .utilities,
            riskLevel: .safe,
            contentDescription: "Buffer data sinkronisasi sementara iCloud CloudKit.",
            impactDescription: "Sistem akan sinkronisasi ulang data iCloud yang diperlukan secara otomatis."
        ))

        self.exactPathRules = exacts
        self.patternRules = patterns
    }

    /// Evaluates folder name and full path to find the best matching knowledge rule.
    public func resolve(folderName: String, fullPath: String) -> (name: String, category: CacheCategory, risk: RiskLevel, content: String, impact: String) {
        // 1. Check exact path match
        for (key, rule) in exactPathRules {
            if fullPath.contains(key) || folderName == key {
                return (rule.appName, rule.category, rule.riskLevel, rule.contentDescription, rule.impactDescription)
            }
        }

        // 2. Check pattern rules
        for rule in patternRules {
            if fullPath.localizedCaseInsensitiveContains(rule.matchPattern) ||
                folderName.localizedCaseInsensitiveContains(rule.matchPattern) {
                return (rule.appName, rule.category, rule.riskLevel, rule.contentDescription, rule.impactDescription)
            }
        }

        // 3. Intelligent Fallback
        return generateFallback(folderName: folderName, fullPath: fullPath)
    }

    private func generateFallback(folderName: String, fullPath: String) -> (name: String, category: CacheCategory, risk: RiskLevel, content: String, impact: String) {
        let isLog = fullPath.contains("/Logs")
        if isLog {
            let cleanName = cleanIdentifier(folderName)
            return (
                "Log: \(cleanName)",
                .systemLogs,
                .verySafe,
                "File log diagnostik, catatan error, dan riwayat proses untuk \(cleanName).",
                "Log lama akan dibersihkan. Tidak ada dampak pada fungsionalitas aplikasi."
            )
        }

        let isPackage = fullPath.contains(".npm") || fullPath.contains(".cargo") || fullPath.contains(".gradle") || fullPath.contains(".cache")
        if isPackage {
            let cleanName = cleanIdentifier(folderName)
            return (
                "Package Cache: \(cleanName)",
                .packageManagers,
                .verySafe,
                "File cache pustaka dan unduhan paket pengembang untuk \(cleanName).",
                "Package manager akan mengunduh ulang modul saat dibutuhkan pada instalasi berikutnya."
            )
        }

        let cleanName = cleanIdentifier(folderName)
        let isApple = folderName.hasPrefix("com.apple.")
        let category: CacheCategory = isApple ? .utilities : .general
        let risk: RiskLevel = .safe

        return (
            cleanName,
            category,
            risk,
            "File cache dan data sementara yang dibuat oleh \(cleanName) untuk mempercepat performa.",
            "\(cleanName) akan membuat ulang file cache ini secara otomatis saat dibuka. Pembukaan pertama mungkin memerlukan waktu sedikit lebih lama."
        )
    }

    private func cleanIdentifier(_ identifier: String) -> String {
        // If bundle ID like com.company.AppName -> AppName
        let parts = identifier.split(separator: ".")
        if parts.count >= 2 {
            let last = String(parts.last!)
            // If last part is "ShipIt", "helper", etc., take the one before
            if (last.lowercased() == "shipit" || last.lowercased() == "helper") && parts.count >= 3 {
                return String(parts[parts.count - 2]) + " " + last.capitalized
            }
            // Capitalize or keep case
            if last.count > 1 {
                return last
            }
        }
        return identifier
    }
}
