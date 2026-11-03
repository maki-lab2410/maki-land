import SwiftUI

public struct CalendarGlanceView: View {
    @ObservedObject var calService = CalendarService.shared

    @State private var icsDraft: String = ""
    @State private var eventIndex: Int = 0

    private let calendar = Calendar.current

    public init() {}

    private var now: Date { Date() }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        return formatter.string(from: calService.selectedDate)
    }

    private var surroundingDays: [Date] {
        let base = calendar.startOfDay(for: now)
        return (-2...2).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: base)
        }
    }

    private var selectedEvents: [IslandCalendarEvent] {
        calService.events(for: calService.selectedDate)
    }

    public var body: some View {
        if calService.isShowingSettings {
            syncSettingsPanel
        } else {
            glancePanel
        }
    }

    // MARK: - Main Tidy Calendar Glance
    private var glancePanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            // Top Row: Non-wrapping Month + Source Pill on Left, Crisp 5-Day Strip on Right
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthName)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Button {
                        icsDraft = calService.googleICSURL
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                            calService.isShowingSettings = true
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(calService.isAnySourceConnected ? Color.green : Color.orange)
                                .frame(width: 4.5, height: 4.5)
                            Text(sourceShortLabel)
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 6.5, weight: .bold))
                        }
                        .foregroundColor(.white.opacity(0.78))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.09))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Pengaturan Sinkronisasi Google Calendar & Kalender Akun iOS/Mac")
                }

                Spacer(minLength: 4)

                // 5-Day Interactive Strip
                HStack(spacing: 4) {
                    ForEach(surroundingDays, id: \.self) { day in
                        dayCell(for: day)
                    }
                }
            }

            // Bottom Row: Live Events or One-Click Connect Prompt
            if !calService.isAnySourceConnected {
                Button {
                    icsDraft = calService.googleICSURL
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        calService.isShowingSettings = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.cyan)

                        Text("Sambungkan Google / iOS Calendar")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.88))
                            .lineLimit(1)

                        Spacer(minLength: 2)

                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.cyan.opacity(0.85))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(Color.cyan.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.cyan.opacity(0.28), lineWidth: 0.6)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            } else if selectedEvents.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 10.5))
                        .foregroundColor(.white.opacity(0.5))

                    Text(emptyDayText)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.58))
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    Button {
                        calService.refreshAll()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                    .help("Muat ulang jadwal")
                }
                .padding(.top, 1)
            } else {
                let safeIdx = min(eventIndex, max(0, selectedEvents.count - 1))
                let ev = selectedEvents[safeIdx]

                HStack(spacing: 6) {
                    Capsule()
                        .fill(ev.source == .google ? Color.blue : Color.cyan)
                        .frame(width: 3, height: 15)

                    Text(ev.timeLabel)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)

                    Text(ev.title)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    Text(ev.source == .google ? "G" : "")
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Capsule())

                    if selectedEvents.count > 1 {
                        Button {
                            eventIndex = (safeIdx + 1) % selectedEvents.count
                        } label: {
                            Text("\(safeIdx + 1)/\(selectedEvents.count) ▸")
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.orange.opacity(0.18))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Klik untuk lihat jadwal berikutnya di tanggal ini")
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.vertical, 4)
        .onChange(of: calService.selectedDate) { _ in
            eventIndex = 0
        }
    }

    // MARK: - Inline Google Calendar & iOS/Apple Calendar Connection Panel
    private var syncSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 5.5) {
            // Header + Source Filter + Back Button
            HStack(spacing: 5) {
                Text("📅 Kalender")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack(spacing: 2) {
                    ForEach(CalendarProviderFilter.allCases) { f in
                        Button {
                            calService.filter = f
                        } label: {
                            Text(f.rawValue)
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(calService.filter == f ? Color.white.opacity(0.24) : Color.clear)
                                .foregroundColor(calService.filter == f ? .white : .white.opacity(0.55))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(1.5)
                .background(Color.white.opacity(0.07))
                .clipShape(Capsule())

                Spacer(minLength: 2)

                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        calService.isShowingSettings = false
                    }
                } label: {
                    Text("Selesai")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Color.white.opacity(0.92))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Row 1: Apple / iOS / iCloud Calendar (EventKit)
            HStack(spacing: 6) {
                Text(" iOS / Mac:")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: true, vertical: false)

                if calService.hasAppleAccess {
                    Text("✓ Aktif (\(calService.appleCalendarCount) iOS\(calService.systemGoogleCalendarCount > 0 ? " + \(calService.systemGoogleCalendarCount) Google" : ""))")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .lineLimit(1)
                } else {
                    Button {
                        calService.requestAppleCalendarAccess()
                    } label: {
                        Text("Izinkan Akses Kalender")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Color.cyan.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 2)

                Button {
                    calService.openSystemInternetAccounts()
                } label: {
                    Text("+ Akun iCloud/Google")
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.09))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Buka Pengaturan Akun Internet macOS untuk login iCloud (iOS) atau Google")
            }

            // Row 2: Direct Google Calendar .ics Feed Link
            HStack(spacing: 5) {
                Text("🇬 Link .ics:")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: true, vertical: false)

                TextField("Tempel Secret URL iCal Google (.ics)...", text: $icsDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 9.5, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .onSubmit {
                        calService.saveGoogleICSURL(icsDraft)
                    }

                Button {
                    calService.saveGoogleICSURL(icsDraft)
                } label: {
                    Text(calService.isSyncingGoogle ? "..." : "Simpan")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6.5)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.75))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    calService.openGoogleCalendarSettingsWeb()
                } label: {
                    Image(systemName: "safari")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Buka Setelan Google Calendar Web (Salin 'Alamat rahasia dalam format iCal')")
            }

            if let err = calService.googleSyncError {
                Text("⚠️ \(err)")
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundColor(.orange)
                    .lineLimit(1)
            } else if !calService.googleICSURL.isEmpty {
                Text("✓ Google .ics terhubung (\(calService.googleEventCount) jadwal dimuat)")
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundColor(.green.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers
    private var sourceShortLabel: String {
        if !calService.isAnySourceConnected { return "Sinkron" }
        switch calService.filter {
        case .all:      return "Semua"
        case .appleIOS: return "iOS"
        case .google:   return "Google"
        }
    }

    private var emptyDayText: String {
        if calendar.isDateInToday(calService.selectedDate) {
            return "Tidak ada jadwal hari ini"
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "d MMM"
        return "Kosong pada \(f.string(from: calService.selectedDate))"
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let isToday = calendar.isDate(date, inSameDayAs: now)
        let isSelected = calendar.isDate(date, inSameDayAs: calService.selectedDate)
        let hasEv = calService.hasEvents(on: date)
        let dayName = dayAbbreviation(for: date)
        let dayNumber = calendar.component(.day, from: date)

        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                calService.selectedDate = date
            }
        } label: {
            VStack(spacing: 3) {
                Text(dayName)
                    .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity((isToday || isSelected) ? 0.92 : 0.45))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: 9)

                ZStack {
                    if isToday {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 24, height: 24)
                            .shadow(color: Color.blue.opacity(0.4), radius: 3, y: 1)
                    } else if isSelected {
                        Circle()
                            .stroke(Color.white.opacity(0.65), lineWidth: 1.2)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                            .frame(width: 24, height: 24)
                    }

                    Text(String(format: "%02d", dayNumber))
                        .font(.system(size: 11.5, weight: (isToday || isSelected) ? .bold : .semibold, design: .rounded))
                        .foregroundColor((isToday || isSelected) ? .white : .white.opacity(0.85))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(width: 24, height: 24)

                // Tiny event indicator dot
                Circle()
                    .fill(hasEv ? Color.cyan : Color.clear)
                    .frame(width: 3.5, height: 3.5)
            }
            .frame(width: 29)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).uppercased().prefix(3))
    }
}
