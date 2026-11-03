import SwiftUI

public struct SystemMonitorView: View {
    @ObservedObject var monitor = SystemMonitorService.shared
    @ObservedObject var battery = BatteryService.shared
    @ObservedObject var cleaner = CacheCleanerManager.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            // Top Row: Core System Metrics
            HStack(spacing: 10) {
                // CPU
                metricCard(
                    icon: "cpu",
                    iconColor: cpuColor,
                    label: "CPU",
                    valueText: String(format: "%.0f%%", monitor.cpuPercent),
                    gauge: monitor.cpuPercent / 100.0,
                    gaugeColor: cpuColor
                )

                divider

                // RAM
                metricCard(
                    icon: "memorychip",
                    iconColor: ramColor,
                    label: "RAM",
                    valueText: String(format: "%.1f/%.0fGB", monitor.ramUsedGB, monitor.ramTotalGB),
                    gauge: monitor.ramPercent / 100.0,
                    gaugeColor: ramColor
                )

                divider

                // Network
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Image(systemName: "network")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.cyan)
                        Text("Network")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 8.5, weight: .bold))
                            Text(monitor.formatNetSpeed(monitor.netDownKBs))
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .monospacedDigit()
                                .lineLimit(1)
                        }

                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(.green.opacity(0.85))
                            Text(monitor.formatNetSpeed(monitor.netUpKBs))
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.88))
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                divider

                // Battery
                metricCard(
                    icon: battery.isCharging ? "bolt.fill" : batteryIcon,
                    iconColor: batteryColor,
                    label: "Baterai",
                    valueText: "\(battery.level)%",
                    gauge: Double(battery.level) / 100.0,
                    gaugeColor: batteryColor
                )
            }
            .frame(maxWidth: .infinity)

            // Bottom Card: Maki Cache Cleaner (Opsi 2)
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.20))
                            .frame(width: 24, height: 24)
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text("Pembersih Cache Aman")
                                .font(.system(size: 9.8, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            if cleaner.isScanning || cleaner.isCleaning {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 10, height: 10)
                            }
                        }

                        if cleaner.isScanning {
                            Text(cleaner.progressText.isEmpty ? "Memindai sampah cache..." : cleaner.progressText)
                                .font(.system(size: 8.2, design: .rounded))
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(1)
                        } else if cleaner.isCleaning {
                            Text(cleaner.progressText.isEmpty ? "Memindahkan ke Sampah..." : cleaner.progressText)
                                .font(.system(size: 8.2, design: .rounded))
                                .foregroundColor(.orange.opacity(0.9))
                                .lineLimit(1)
                        } else if cleaner.lastFreedBytes > 0 {
                            Text("Baru dibersihkan: \(ByteCountFormatter.string(fromByteCount: cleaner.lastFreedBytes, countStyle: .file)) dibuang ke Sampah ✨")
                                .font(.system(size: 8.2, weight: .semibold, design: .rounded))
                                .foregroundColor(.green)
                        } else {
                            Text("\(cleaner.formattedTotalSafeSize) cache aman (\(cleaner.safeItems.count) folder Browser, DerivedData, Logs)")
                                .font(.system(size: 8.2, design: .rounded))
                                .foregroundColor(.white.opacity(0.65))
                        }
                    }
                }

                Spacer()

                // Rescan
                Button {
                    Task { await cleaner.startScan() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(5.5)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Pindai ulang cache")

                // Clean Button
                Button {
                    Task {
                        let res = await cleaner.cleanSafeItems()
                        if res.totalBytesFreed > 0 {
                            NSSound(named: "Glass")?.play()
                            let capy = CapybaraService.shared
                            capy.xp += 10
                            capy.mood = min(100, capy.mood + 5)
                            capy.showDesktopBubble("Hup! \(res.formattedTotalFreed) sampah cache berhasil dipindahkan ke Tong Sampah! 🧹✨", duration: 4.5)
                        }
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 8.5))
                        Text(cleaner.safeItems.isEmpty ? "Kinclong" : "Sapu Aman (\(cleaner.formattedTotalSafeSize))")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 8.5)
                    .padding(.vertical, 4.5)
                    .background(cleaner.safeItems.isEmpty ? Color.white.opacity(0.08) : Color.orange.opacity(0.85))
                    .foregroundColor(cleaner.safeItems.isEmpty ? .white.opacity(0.45) : .white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(cleaner.isScanning || cleaner.isCleaning || cleaner.safeItems.isEmpty)
                .help("Pindahkan cache aman ke Tong Sampah (bisa di-restore kapan saja)")
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                    )
            )
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Color.white.opacity(0.08)
            .frame(width: 0.5, height: 44)
    }

    @ViewBuilder
    private func metricCard(icon: String, iconColor: Color, label: String, valueText: String, gauge: Double, gaugeColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(iconColor)
                Text(label)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Text(valueText)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(gaugeColor)
                        .frame(width: geo.size.width * max(0, min(1, gauge)))
                        .animation(.easeInOut(duration: 0.6), value: gauge)
                }
            }
            .frame(height: 4.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cpuColor: Color {
        if monitor.cpuPercent >= 80 { return .red }
        if monitor.cpuPercent >= 50 { return .orange }
        return .blue
    }

    private var ramColor: Color {
        if monitor.ramPercent >= 85 { return .red }
        if monitor.ramPercent >= 65 { return .orange }
        return .purple
    }

    private var batteryColor: Color {
        if battery.isCharging { return .green }
        if battery.level <= 20 { return .red }
        if battery.level <= 40 { return .orange }
        return .cyan
    }

    private var batteryIcon: String {
        switch battery.level {
        case 0...20:   return "battery.25"
        case 21...50:  return "battery.50"
        case 51...80:  return "battery.75"
        default:       return "battery.100"
        }
    }
}
