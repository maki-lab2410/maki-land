import SwiftUI

public struct TimerView: View {
    @ObservedObject var timerService = TimerService.shared
    @State private var alertPulse: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 8) {
            if timerService.isTimeUpAlert {
                // MARK: - Time Up Alert Screen (Noticeable Animation + Sound)
                timeUpAlertView
            } else if timerService.totalSeconds > 0 {
                // MARK: - Active Countdown Display
                activeTimerView
            } else {
                // MARK: - Idle Timer Setup (Presets + Custom Timer)
                idleSetupView
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Time Up Alert View
    private var timeUpAlertView: some View {
        HStack(spacing: 16) {
            ZStack {
                // Pulsing outer glow ring
                Circle()
                    .stroke(Color.orange.opacity(alertPulse ? 0.8 : 0.2), lineWidth: 4)
                    .frame(width: 54, height: 54)
                    .scaleEffect(alertPulse ? 1.15 : 0.95)
                
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.orange)
                    .scaleEffect(alertPulse ? 1.1 : 0.95)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    alertPulse = true
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Waktu Habis!")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.orange)
                
                Text("Timer telah selesai! Istirahat sejenak.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
            }
            
            Spacer()
            
            // Dismiss Button
            Button {
                timerService.dismissAlert()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Selesai")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.orange)
                .foregroundColor(.black)
                .clipShape(Capsule())
                .shadow(color: Color.orange.opacity(0.4), radius: 4, y: 1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    // MARK: - Active Timer View
    private var activeTimerView: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 5)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(timerService.progress))
                    .stroke(
                        Color.orange,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 50, height: 50)
                    .animation(.linear(duration: 1.0), value: timerService.progress)
                
                Image(systemName: "timer")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(timerService.formattedTime)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                
                Text(timerService.isRunning ? "Sedang berjalan..." : "Dijeda")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(timerService.isRunning ? .green : .orange)
            }
            
            Spacer()
            
            // Pause / Resume & Cancel Buttons
            HStack(spacing: 10) {
                Button {
                    timerService.togglePause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: timerService.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                
                Button {
                    timerService.stop()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
    }
    
    // MARK: - Idle Setup View (Interactive Dial + Presets + Stepper)
    private var idleSetupView: some View {
        HStack(spacing: 12) {
            // Left: Interactive circular target duration dial
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 4)
                    .frame(width: 58, height: 58)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(1.0, Double(timerService.customMinutes) / 60.0)))
                    .stroke(
                        Color.orange,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 58, height: 58)
                    .animation(.spring(response: 0.35, dampingFraction: 0.78), value: timerService.customMinutes)
                
                VStack(spacing: 1) {
                    Text("\(timerService.customMinutes)m")
                        .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(timerService.customMinutes == 25 ? "POMODORO" : "FOKUS")
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
            }
            
            // Center & Right: Presets Row + Stepper & Start Button
            VStack(alignment: .leading, spacing: 6) {
                // Row 1: Interactive Presets
                HStack(spacing: 5) {
                    presetButton(title: "5m", minutes: 5)
                    presetButton(title: "15m", minutes: 15)
                    presetButton(title: "25m Pomodoro", minutes: 25, isFocus: true)
                    presetButton(title: "45m", minutes: 45)
                    presetButton(title: "60m", minutes: 60)
                }
                
                // Row 2: Stepper Adjuster & Primary Start Button
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        adjustButton(title: "-5m", amount: -5)
                        adjustButton(title: "-1m", amount: -1)
                        adjustButton(title: "+1m", amount: 1)
                        adjustButton(title: "+5m", amount: 5)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    
                    Spacer(minLength: 4)
                    
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            timerService.start(minutes: timerService.customMinutes)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9.5, weight: .black))
                            Text("Mulai (\(timerService.customMinutes)m)")
                                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        }
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                        .shadow(color: Color.orange.opacity(0.35), radius: 4, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 8)
    }
    
    private func presetButton(title: String, minutes: Int, isFocus: Bool = false) -> some View {
        let isSelected = timerService.customMinutes == minutes
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                timerService.customMinutes = minutes
            }
        } label: {
            HStack(spacing: 3) {
                if isFocus {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8.5))
                }
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .semibold, design: .rounded))
            }
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                isSelected ? Color.orange.opacity(0.32) :
                (isFocus ? Color.orange.opacity(0.16) : Color.white.opacity(0.10))
            )
            .foregroundColor(isSelected ? .orange : (isFocus ? Color.orange.opacity(0.9) : .white.opacity(0.85)))
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.orange.opacity(0.8) : Color.clear, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private func adjustButton(title: String, amount: Int) -> some View {
        Button {
            timerService.adjustCustomMinutes(by: amount)
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
