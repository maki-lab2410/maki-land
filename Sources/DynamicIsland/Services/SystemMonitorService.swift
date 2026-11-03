import Foundation
import AppKit
import Darwin

public class SystemMonitorService: ObservableObject {
    public static let shared = SystemMonitorService()
    
    @Published public var cpuPercent: Double = 0.0
    @Published public var ramUsedGB: Double = 0.0
    @Published public var ramTotalGB: Double = 0.0
    @Published public var ramPercent: Double = 0.0
    @Published public var netDownKBs: Double = 0.0
    @Published public var netUpKBs: Double = 0.0
    
    private var prevBytesIn: UInt64 = 0
    private var prevBytesOut: UInt64 = 0
    private var prevCPUTicks: (user: UInt64, sys: UInt64, idle: UInt64) = (0, 0, 0)
    private var pollTimer: Timer?
    
    private init() {
        // Seed the previous values
        prevBytesIn = currentNetBytes().in
        prevBytesOut = currentNetBytes().out
        prevCPUTicks = currentCPUTicks()
        
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }
    
    private func refresh() {
        updateCPU()
        updateRAM()
        updateNetwork()
    }
    
    // MARK: - CPU
    private func updateCPU() {
        let ticks = currentCPUTicks()
        let user = ticks.user - prevCPUTicks.user
        let sys  = ticks.sys  - prevCPUTicks.sys
        let idle = ticks.idle - prevCPUTicks.idle
        let total = user + sys + idle
        
        prevCPUTicks = ticks
        
        DispatchQueue.main.async {
            if total > 0 {
                self.cpuPercent = Double(user + sys) / Double(total) * 100.0
            }
        }
    }
    
    private func currentCPUTicks() -> (user: UInt64, sys: UInt64, idle: UInt64) {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kerr == KERN_SUCCESS else { return (0, 0, 0) }
        return (
            user: UInt64(load.cpu_ticks.0),
            sys:  UInt64(load.cpu_ticks.1),
            idle: UInt64(load.cpu_ticks.2)
        )
    }
    
    // MARK: - RAM
    private func updateRAM() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kerr == KERN_SUCCESS else { return }
        
        let pageSize = UInt64(vm_page_size)
        let used = UInt64(stats.active_count + stats.wire_count + stats.compressor_page_count) * pageSize
        let total = ProcessInfo.processInfo.physicalMemory
        
        DispatchQueue.main.async {
            self.ramUsedGB  = Double(used)  / 1_073_741_824.0
            self.ramTotalGB = Double(total) / 1_073_741_824.0
            self.ramPercent = Double(used) / Double(total) * 100.0
        }
    }
    
    // MARK: - Network
    private func updateNetwork() {
        let net = currentNetBytes()
        let dt: Double = 2.0
        
        let diffIn  = net.in  > prevBytesIn  ? net.in  - prevBytesIn  : 0
        let diffOut = net.out > prevBytesOut ? net.out - prevBytesOut : 0
        prevBytesIn  = net.in
        prevBytesOut = net.out
        
        DispatchQueue.main.async {
            self.netDownKBs = Double(diffIn)  / dt / 1024.0
            self.netUpKBs   = Double(diffOut) / dt / 1024.0
        }
    }
    
    private func currentNetBytes() -> (in: UInt64, out: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var ptr = ifaddr
        while let cur = ptr {
            let name = String(cString: cur.pointee.ifa_name)
            if (name.hasPrefix("en") || name.hasPrefix("utun") || name.hasPrefix("pdp")) &&
               cur.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                if let data = cur.pointee.ifa_data {
                    let d = data.assumingMemoryBound(to: if_data.self)
                    totalIn  += UInt64(d.pointee.ifi_ibytes)
                    totalOut += UInt64(d.pointee.ifi_obytes)
                }
            }
            ptr = cur.pointee.ifa_next
        }
        return (totalIn, totalOut)
    }
    
    // MARK: - Formatting Helpers
    public func formatNetSpeed(_ kbs: Double) -> String {
        if kbs >= 1024 {
            return String(format: "%.1f MB/s", kbs / 1024.0)
        } else {
            return String(format: "%.0f KB/s", kbs)
        }
    }
}
