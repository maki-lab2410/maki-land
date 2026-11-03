import Foundation
import AppKit

public class TimerService: ObservableObject {
    public static let shared = TimerService()
    
    @Published public var isRunning: Bool = false
    @Published public var totalSeconds: Int = 0
    @Published public var secondsRemaining: Int = 0
    @Published public var progress: Double = 0.0
    @Published public var formattedTime: String = "00:00"
    @Published public var isTimeUpAlert: Bool = false
    
    // Custom timer duration in minutes
    @Published public var customMinutes: Int = 10
    
    private var timer: Timer?
    
    private init() {}
    
    public func start(minutes: Int) {
        start(seconds: minutes * 60)
    }
    
    public func start(seconds: Int) {
        stop()
        self.isTimeUpAlert = false
        self.totalSeconds = max(1, seconds)
        self.secondsRemaining = max(1, seconds)
        self.isRunning = true
        self.updateDisplays()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.secondsRemaining > 0 {
                self.secondsRemaining -= 1
                self.updateDisplays()
                if self.secondsRemaining == 0 {
                    self.timeUp()
                }
            } else {
                self.timeUp()
            }
        }
    }
    
    public func togglePause() {
        if isRunning {
            timer?.invalidate()
            timer = nil
            isRunning = false
        } else if secondsRemaining > 0 {
            isRunning = true
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if self.secondsRemaining > 0 {
                    self.secondsRemaining -= 1
                    self.updateDisplays()
                    if self.secondsRemaining == 0 {
                        self.timeUp()
                    }
                } else {
                    self.timeUp()
                }
            }
        }
    }
    
    public func stop(keepAlert: Bool = false) {
        timer?.invalidate()
        timer = nil
        isRunning = false
        secondsRemaining = 0
        totalSeconds = 0
        progress = 0.0
        formattedTime = "00:00"
        if !keepAlert {
            isTimeUpAlert = false
        }
    }
    
    public func dismissAlert() {
        isTimeUpAlert = false
        stop()
    }
    
    public func adjustCustomMinutes(by amount: Int) {
        let newVal = customMinutes + amount
        customMinutes = max(1, min(180, newVal))
    }
    
    private func updateDisplays() {
        let mins = secondsRemaining / 60
        let secs = secondsRemaining % 60
        formattedTime = String(format: "%02d:%02d", mins, secs)
        
        if totalSeconds > 0 {
            progress = Double(totalSeconds - secondsRemaining) / Double(totalSeconds)
        } else {
            progress = 0.0
        }
    }
    
    private func timeUp() {
        stop(keepAlert: true)
        isTimeUpAlert = true
        playAlarmSound()
        
        // Auto-expand Dynamic Island & switch to Timer tab so user notices immediately!
        DispatchQueue.main.async {
            IslandState.shared.selectedTab = .timer
            IslandState.shared.setExpanded(true)
        }
    }
    
    private func playAlarmSound() {
        // Play 3 crisp, noticeable chimes in sequence
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.45) {
                NSSound(named: "Glass")?.play()
            }
        }
    }
}
