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
    
    // MARK: - Idle Setup View (Presets + Custom Adjuster)
    private var idleSetupView: some View {
        VStack(spacing: 8) {
            // Row 1: Quick Presets
            HStack(spacing: 6) {
                presetButton(title: "1m", minutes: 1)
                presetButton(title: "5m", minutes: 5)
                presetButton(title: "15m", minutes: 15)
                presetButton(title: "25m Pomodoro", minutes: 25, isFocus: true)
                presetButton(title: "45m", minutes: 45)
            }
            
            // Row 2: Custom Timer Stepper & Start Button
            HStack(spacing: 10) {
                Text("Custom:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                
                // Adjuster controls
                HStack(spacing: 4) {
                    adjustButton(title: "-5m", amount: -5)
                    adjustButton(title: "-1m", amount: -1)
                    
                    Text("\(timerService.customMinutes)m")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 44, alignment: .center)
                    
                    adjustButton(title: "+1m", amount: 1)
                    adjustButton(title: "+5m", amount: 5)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                
                Spacer()
                
                // Start Custom Button
                Button {
                    timerService.start(minutes: timerService.customMinutes)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Mulai (\(timerService.customMinutes)m)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.orange)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
        }
    }
    
    private func presetButton(title: String, minutes: Int, isFocus: Bool = false) -> some View {
        Button {
            timerService.start(minutes: minutes)
        } label: {
            HStack(spacing: 3) {
                if isFocus {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(isFocus ? Color.orange.opacity(0.25) : Color.white.opacity(0.12))
            .foregroundColor(isFocus ? .orange : .white)
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
