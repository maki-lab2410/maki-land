import SwiftUI

public struct SystemMonitorView: View {
    @ObservedObject var monitor = SystemMonitorService.shared
    @ObservedObject var battery = BatteryService.shared

    public init() {}

    public var body: some View {
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
                            .foregroundColor(.cyan)
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
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Color.white.opacity(0.08)
            .frame(width: 0.5, height: 48)
    }

    @ViewBuilder
    private func metricCard(icon: String, iconColor: Color, label: String, valueText: String, gauge: Double, gaugeColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(iconColor)
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Text(valueText)
                .font(.system(size: 13.5, weight: .heavy, design: .rounded))
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
            .frame(height: 5)
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
        if battery.level <= 15 { return .red }
        if battery.level <= 30 { return .orange }
        return .green
    }

    private var batteryIcon: String {
        if battery.level >= 90 { return "battery.100" }
        if battery.level >= 60 { return "battery.75" }
        if battery.level >= 40 { return "battery.50" }
        if battery.level >= 15 { return "battery.25" }
        return "battery.0"
    }
}
