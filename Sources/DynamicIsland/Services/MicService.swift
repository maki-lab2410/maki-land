import Foundation
import AppKit

public class MicService: ObservableObject {
    public static let shared = MicService()
    
    @Published public var isMuted: Bool = false
    @Published public var inputVolume: Int = 50
    
    private var lastNonZeroVolume: Int = 50
    private var pollTimer: Timer?
    
    private init() {
        checkStatus()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkStatus()
        }
    }
    
    public func checkStatus() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let script = NSAppleScript(source: "input volume of (get volume settings)")
            var err: NSDictionary?
            if let res = script?.executeAndReturnError(&err), let vol = Int(res.stringValue ?? "") {
                DispatchQueue.main.async {
                    self?.inputVolume = vol
                    self?.isMuted = (vol == 0)
                    if vol > 0 {
                        self?.lastNonZeroVolume = vol
                    }
                }
            }
        }
    }
    
    public func toggleMute() {
        if isMuted {
            unmute()
        } else {
            mute()
        }
    }
    
    public func mute() {
        let volToRestore = inputVolume > 0 ? inputVolume : (lastNonZeroVolume > 0 ? lastNonZeroVolume : 50)
        lastNonZeroVolume = volToRestore
        isMuted = true
        inputVolume = 0
        NSSound(named: "Pop")?.play()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let script = NSAppleScript(source: "set volume input volume 0")
            var err: NSDictionary?
            _ = script?.executeAndReturnError(&err)
        }
    }
    
    public func unmute() {
        let vol = lastNonZeroVolume > 0 ? lastNonZeroVolume : 50
        isMuted = false
        inputVolume = vol
        NSSound(named: "Tink")?.play()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let script = NSAppleScript(source: "set volume input volume \(vol)")
            var err: NSDictionary?
            _ = script?.executeAndReturnError(&err)
        }
    }
}
