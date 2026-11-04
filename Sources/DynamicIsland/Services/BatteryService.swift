import Foundation
import IOKit.ps

public class BatteryService: ObservableObject {
    public static let shared = BatteryService()
    
    @Published public var level: Int = 100
    @Published public var isCharging: Bool = false
    @Published public var isPluggedIn: Bool = false
    @Published public var timeRemainingFormatted: String = ""
    
    private var timer: Timer?
    private var powerRunLoopSource: CFRunLoopSource?
    
    private init() {
        updateBatteryInfo()
        registerPowerSourceNotification()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateBatteryInfo()
        }
    }

    private func registerPowerSourceNotification() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            service.updateBatteryInfo()
        }, context)?.takeRetainedValue() {
            powerRunLoopSource = runLoopSource
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
    }
    
    public func updateBatteryInfo() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }
        
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            if let currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int,
               let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int,
               maxCapacity > 0 {
                let percentage = Int(Double(currentCapacity) / Double(maxCapacity) * 100)
                DispatchQueue.main.async {
                    self.level = percentage
                }
            }
            
            let isChargingState = description[kIOPSIsChargingKey as String] as? Bool ?? false
            let powerSourceState = description[kIOPSPowerSourceStateKey as String] as? String
            let pluggedIn = powerSourceState == (kIOPSACPowerValue as String)
            
            DispatchQueue.main.async {
                self.isCharging = isChargingState
                self.isPluggedIn = pluggedIn
            }
            
            if let timeToEmpty = description[kIOPSTimeToEmptyKey as String] as? Int, timeToEmpty > 0 {
                let hours = timeToEmpty / 60
                let minutes = timeToEmpty % 60
                DispatchQueue.main.async {
                    self.timeRemainingFormatted = "\(hours)j \(minutes)m tersisa"
                }
            } else if isChargingState {
                if let timeToFull = description[kIOPSTimeToFullChargeKey as String] as? Int, timeToFull > 0 {
                    let hours = timeToFull / 60
                    let minutes = timeToFull % 60
                    DispatchQueue.main.async {
                        self.timeRemainingFormatted = "\(hours)j \(minutes)m hingga penuh"
                    }
                } else {
                    DispatchQueue.main.async {
                        self.timeRemainingFormatted = "Mengisi daya..."
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.timeRemainingFormatted = "Daya Baterai"
                }
            }
            break
        }
    }
}
