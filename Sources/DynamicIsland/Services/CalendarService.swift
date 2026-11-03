import Foundation
import AppKit
import EventKit
import SwiftUI

public enum CalendarSourceKind: String, Codable, Equatable {
    case appleIOS = "iOS"
    case google   = "Google"
}

public enum CalendarProviderFilter: String, CaseIterable, Identifiable {
    case all      = "Semua"
    case appleIOS = "🍎 iOS"
    case google   = "🇬 Google"

    public var id: String { rawValue }
}

public struct IslandCalendarEvent: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let source: CalendarSourceKind
    public let colorHex: String

    public var timeLabel: String {
        if isAllDay { return "Seharian" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: startDate)
    }
}

public class CalendarService: ObservableObject {
    public static let shared = CalendarService()

    @Published public var filter: CalendarProviderFilter = .all {
        didSet {
            UserDefaults.standard.set(filter.rawValue, forKey: storagePrefix + "filter")
        }
    }
    @Published public var selectedDate: Date = Date()
    @Published public var isShowingSettings: Bool = false {
        didSet {
            IslandState.shared.notifySize()
        }
    }

    // EventKit (Apple / iOS / iCloud + macOS System Google Accounts)
    @Published public var appleAuthStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published public var appleCalendarCount: Int = 0
    @Published public var systemGoogleCalendarCount: Int = 0

    // Direct Google Calendar .ics URL sync
    @Published public var googleICSURL: String = ""
    @Published public var isSyncingGoogle: Bool = false
    @Published public var googleSyncError: String? = nil
    @Published public var googleEventCount: Int = 0

    @Published private var appleEvents: [IslandCalendarEvent] = []
    @Published private var googleICSEvents: [IslandCalendarEvent] = []

    private let store = EKEventStore()
    private let storagePrefix = "maki_calendar_"
    private var refreshTimer: Timer?

    public var hasAppleAccess: Bool {
        if #available(macOS 14.0, *) {
            return appleAuthStatus == .fullAccess
        } else {
            return appleAuthStatus == .authorized
        }
    }

    public var hasGoogleConnected: Bool {
        !googleICSURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (hasAppleAccess && systemGoogleCalendarCount > 0)
    }

    public var isAnySourceConnected: Bool {
        hasAppleAccess || !googleICSURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private init() {
        if let savedFilter = UserDefaults.standard.string(forKey: storagePrefix + "filter"),
           let parsed = CalendarProviderFilter(rawValue: savedFilter) {
            filter = parsed
        }
        googleICSURL = UserDefaults.standard.string(forKey: storagePrefix + "google_ics") ?? ""

        updateAuthStatus()
        if hasAppleAccess {
            reloadAppleEvents()
        }
        if !googleICSURL.isEmpty {
            syncGoogleICS()
        }

        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            self?.reloadAppleEvents()
        }

        let timer = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            self?.refreshAll()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    public func updateAuthStatus() {
        appleAuthStatus = EKEventStore.authorizationStatus(for: .event)
    }

    public func requestAppleCalendarAccess() {
        IslandState.shared.isModalOpen = true
        let finish: (Bool) -> Void = { [weak self] granted in
            DispatchQueue.main.async {
                IslandState.shared.isModalOpen = false
                guard let self = self else { return }
                self.updateAuthStatus()
                if granted {
                    self.reloadAppleEvents()
                    CapybaraService.shared.reactToEvent("kalender udah nyambung nih")
                } else {
                    // Open macOS Privacy > Calendars if previously denied
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { granted, _ in
                finish(granted)
            }
        } else {
            store.requestAccess(to: .event) { granted, _ in
                finish(granted)
            }
        }
    }

    public func saveGoogleICSURL(_ raw: String) {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("webcal://") {
            cleaned = "https://" + cleaned.dropFirst("webcal://".count)
        }
        googleICSURL = cleaned
        UserDefaults.standard.set(cleaned, forKey: storagePrefix + "google_ics")
        if cleaned.isEmpty {
            googleICSEvents = []
            googleEventCount = 0
            googleSyncError = nil
        } else {
            syncGoogleICS()
        }
    }

    public func refreshAll() {
        updateAuthStatus()
        if hasAppleAccess {
            reloadAppleEvents()
        }
        if !googleICSURL.isEmpty {
            syncGoogleICS()
        }
    }

    public func openSystemInternetAccounts() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openGoogleCalendarSettingsWeb() {
        if let url = URL(string: "https://calendar.google.com/calendar/u/0/r/settings") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Query Events for Any Day

    public func events(for date: Date) -> [IslandCalendarEvent] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        var combined = appleEvents + googleICSEvents

        // Deduplicate if user connected both macOS Google Account AND .ics feed
        var seen = Set<String>()
        combined = combined.filter { ev in
            let key = "\(ev.title.lowercased())|\(Int(ev.startDate.timeIntervalSince1970 / 60))"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        return combined
            .filter { ev in
                switch filter {
                case .all:      break
                case .appleIOS: if ev.source != .appleIOS { return false }
                case .google:   if ev.source != .google { return false }
                }
                return ev.startDate < dayEnd && ev.endDate > dayStart
            }
            .sorted { a, b in
                if a.isAllDay != b.isAllDay { return !a.isAllDay }
                return a.startDate < b.startDate
            }
    }

    public func hasEvents(on date: Date) -> Bool {
        !events(for: date).isEmpty
    }

    // MARK: - EventKit Loader (Apple/iOS/iCloud + macOS Google Accounts)

    public func reloadAppleEvents() {
        guard hasAppleAccess else { return }
        let cal = Calendar.current
        let now = Date()
        guard let start = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: now)),
              let end = cal.date(byAdding: .day, value: 14, to: cal.startOfDay(for: now)) else { return }

        let calendars = store.calendars(for: .event)
        var iOSCount = 0
        var gCount = 0
        for c in calendars {
            if isGoogleCalendar(c) { gCount += 1 } else { iOSCount += 1 }
        }
        appleCalendarCount = iOSCount
        systemGoogleCalendarCount = gCount

        let pred = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let ekEvents = store.events(matching: pred)

        appleEvents = ekEvents.map { ek in
            let isG = isGoogleCalendar(ek.calendar)
            let hex = hexString(from: ek.calendar.cgColor) ?? (isG ? "#4285F4" : "#0A84FF")
            return IslandCalendarEvent(
                id: ek.eventIdentifier + "_\(ek.startDate.timeIntervalSince1970)",
                title: (ek.title?.isEmpty == false) ? ek.title! : "(Tanpa Judul)",
                startDate: ek.startDate,
                endDate: ek.endDate,
                isAllDay: ek.isAllDay,
                source: isG ? .google : .appleIOS,
                colorHex: hex
            )
        }
    }

    private func isGoogleCalendar(_ cal: EKCalendar) -> Bool {
        let src = cal.source?.title.lowercased() ?? ""
        let title = cal.title.lowercased()
        return src.contains("google") || src.contains("gmail") || title.contains("@gmail.com")
    }

    private func hexString(from cgColor: CGColor?) -> String? {
        guard let cg = cgColor, let rgb = cg.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil),
              let comps = rgb.components, comps.count >= 3 else { return nil }
        let r = Int(round(comps[0] * 255))
        let g = Int(round(comps[1] * 255))
        let b = Int(round(comps[2] * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    // MARK: - Native Google Calendar .ics Fetcher & RFC 5545 Parser

    public func syncGoogleICS() {
        let urlStr = googleICSURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: urlStr), url.scheme == "https" || url.scheme == "http" else {
            googleSyncError = "URL .ics tidak valid"
            return
        }

        isSyncingGoogle = true
        googleSyncError = nil

        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 12

        URLSession.shared.dataTask(with: req) { [weak self] data, resp, err in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSyncingGoogle = false

                if let err = err {
                    self.googleSyncError = "Gagal koneksi: \(err.localizedDescription)"
                    return
                }
                guard let data = data, let text = String(data: data, encoding: .utf8), text.contains("BEGIN:VCALENDAR") else {
                    self.googleSyncError = "Bukan format iCal (.ics) Google Calendar"
                    return
                }

                let parsed = self.parseICS(text)
                self.googleICSEvents = parsed
                self.googleEventCount = parsed.count
                self.googleSyncError = nil
                CapybaraService.shared.reactToEvent("google calendar udah masuk ya")
            }
        }.resume()
    }

    private func parseICS(_ raw: String) -> [IslandCalendarEvent] {
        // Unfold RFC 5545 folded lines
        let normalized = raw
            .replacingOccurrences(of: "\r\n ", with: "")
            .replacingOccurrences(of: "\r\n\t", with: "")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\n\t", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")

        let cal = Calendar.current
        let now = Date()
        guard let windowStart = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: now)),
              let windowEnd = cal.date(byAdding: .day, value: 14, to: cal.startOfDay(for: now)) else { return [] }

        var results: [IslandCalendarEvent] = []
        var inEvent = false
        var props: [String: (params: String, value: String)] = [:]

        for line in normalized.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "BEGIN:VEVENT" {
                inEvent = true
                props.removeAll()
                continue
            }
            if trimmed == "END:VEVENT" {
                inEvent = false
                if let status = props["STATUS"]?.value.uppercased(), status == "CANCELLED" {
                    continue
                }
                if let built = buildEventsFromICSProps(props, windowStart: windowStart, windowEnd: windowEnd) {
                    results.append(contentsOf: built)
                }
                continue
            }
            guard inEvent, let colonIdx = trimmed.firstIndex(of: ":") else { continue }
            let left = String(trimmed[..<colonIdx])
            let val = String(trimmed[trimmed.index(after: colonIdx)...])
            let parts = left.split(separator: ";", maxSplits: 1).map(String.init)
            let key = parts[0].uppercased()
            let params = parts.count > 1 ? parts[1] : ""
            props[key] = (params, val)
        }

        return results
    }

    private func buildEventsFromICSProps(
        _ props: [String: (params: String, value: String)],
        windowStart: Date,
        windowEnd: Date
    ) -> [IslandCalendarEvent]? {
        guard let dtStartEntry = props["DTSTART"],
              let (start, isAllDay) = parseICSDate(value: dtStartEntry.value, params: dtStartEntry.params) else {
            return nil
        }

        let end: Date
        if let dtEndEntry = props["DTEND"],
           let (parsedEnd, _) = parseICSDate(value: dtEndEntry.value, params: dtEndEntry.params) {
            end = parsedEnd
        } else {
            end = Calendar.current.date(byAdding: isAllDay ? .day : .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
        }

        let duration = max(60, end.timeIntervalSince(start))
        let rawSummary = props["SUMMARY"]?.value ?? "(Acara Google Calendar)"
        let title = rawSummary
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\n", with: " ")
        let uid = props["UID"]?.value ?? UUID().uuidString

        var occurrences: [IslandCalendarEvent] = []

        if let rrule = props["RRULE"]?.value {
            let expandedStarts = expandSimpleRRule(rrule, initialStart: start, windowStart: windowStart, windowEnd: windowEnd)
            for occStart in expandedStarts {
                let occEnd = occStart.addingTimeInterval(duration)
                occurrences.append(
                    IslandCalendarEvent(
                        id: "\(uid)_\(occStart.timeIntervalSince1970)",
                        title: title,
                        startDate: occStart,
                        endDate: occEnd,
                        isAllDay: isAllDay,
                        source: .google,
                        colorHex: "#4285F4"
                    )
                )
            }
        } else if start < windowEnd && end > windowStart {
            occurrences.append(
                IslandCalendarEvent(
                    id: uid,
                    title: title,
                    startDate: start,
                    endDate: end,
                    isAllDay: isAllDay,
                    source: .google,
                    colorHex: "#4285F4"
                )
            )
        }

        return occurrences
    }

    private func parseICSDate(value: String, params: String) -> (Date, Bool)? {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // All-day YYYYMMDD
        if v.count == 8 || params.uppercased().contains("VALUE=DATE") {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone.current
            f.dateFormat = "yyyyMMdd"
            if let d = f.date(from: String(v.prefix(8))) {
                return (d, true)
            }
        }

        var tz = TimeZone.current
        if v.hasSuffix("Z") {
            tz = TimeZone(secondsFromGMT: 0) ?? .current
        } else if let range = params.range(of: "TZID=") {
            let sub = params[range.upperBound...]
            let tzName = sub.split(separator: ";").first.map(String.init) ?? ""
            if let found = TimeZone(identifier: tzName) {
                tz = found
            }
        }

        let clean = v.replacingOccurrences(of: "Z", with: "")
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = clean.count >= 15 ? "yyyyMMdd'T'HHmmss" : "yyyyMMdd'T'HHmm"
        if let d = f.date(from: clean) {
            return (d, false)
        }
        return nil
    }

    private func expandSimpleRRule(_ rrule: String, initialStart: Date, windowStart: Date, windowEnd: Date) -> [Date] {
        guard initialStart <= windowEnd else { return [] }
        var dict: [String: String] = [:]
        for part in rrule.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2 { dict[kv[0].uppercased()] = kv[1].uppercased() }
        }

        guard let freq = dict["FREQ"] else {
            return (initialStart >= windowStart && initialStart <= windowEnd) ? [initialStart] : []
        }

        var untilDate = windowEnd
        if let untilStr = dict["UNTIL"], let (u, _) = parseICSDate(value: untilStr, params: "") {
            untilDate = min(windowEnd, u)
        }

        let interval = max(1, Int(dict["INTERVAL"] ?? "1") ?? 1)
        let cal = Calendar.current
        var results: [Date] = []
        var cursor = initialStart
        var safety = 0

        let comp: Calendar.Component? = {
            switch freq {
            case "DAILY":   return .day
            case "WEEKLY":  return .weekOfYear
            case "MONTHLY": return .month
            case "YEARLY":  return .year
            default:        return nil
            }
        }()

        guard let stepComp = comp else { return [] }

        while cursor <= untilDate && safety < 800 {
            safety += 1
            if cursor >= windowStart {
                results.append(cursor)
            }
            guard let next = cal.date(byAdding: stepComp, value: interval, to: cursor) else { break }
            cursor = next
        }
        return results
    }
}
