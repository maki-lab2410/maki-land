import SwiftUI

public struct BatteryView: View {
    @ObservedObject var batteryService = BatteryService.shared
    
    public init() {}
    
    private var batteryColor: Color {
        if batteryService.isCharging {
            return .green
        } else if batteryService.level <= 20 {
            return .red
        } else if batteryService.level <= 40 {
            return .orange
        } else {
            return .green
        }
    }
    
    public var body: some View {
        HStack(spacing: 20) {
            // Circular Ring Gauge
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 6)
                    .frame(width: 58, height: 58)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(batteryService.level) / 100.0)
                    .stroke(
                        batteryColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 58, height: 58)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: batteryService.level)
                
                if batteryService.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.green)
                        .shadow(color: .green.opacity(0.6), radius: 6)
                } else {
                    Text("\(batteryService.level)%")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .padding(.leading, 8)
            
            // Text Details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Baterai Mac")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if batteryService.isPluggedIn {
                        Text(batteryService.isCharging ? "MENGISI DAYA" : "TERCOLOK ADAPTOR")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }
                }
                
                Text(batteryService.timeRemainingFormatted)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(batteryService.isPluggedIn ? "Adaptor Daya Terhubung" : "Menggunakan Daya Baterai")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
            }
            
            Spacer()
        }
        .padding(.horizontal, 6)
    }
}
