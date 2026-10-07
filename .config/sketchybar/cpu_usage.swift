// CPU utilization, as a percentage of total capacity.
//
// Why this exists instead of a one-line sysctl: the obvious shell approach,
//
//     load=$(sysctl -n vm.loadavg); pct=$((load * 100 / ncpu))
//
// does not measure CPU utilization at all. Load average counts threads that
// WANT to run -- including ones blocked on disk or locks -- so on a busy
// machine it exceeds the core count and the percentage goes past 100% while
// the CPU is mostly idle. Measured on this machine: load 12.66 on 16 cores
// reported 79% while the CPU was 75% idle.
//
// host_statistics(HOST_CPU_LOAD_INFO) gives the kernel's own tick counters --
// the same source `top` uses. They are cumulative since boot, so a single
// reading is meaningless; utilization is the delta between two samples.
// Previous ticks are cached in a state file so each run measures the interval
// since the last run.
//
// `top -l 1` would also be correct but costs ~590ms per call against ~5ms for
// this, which at a 5s tick is the difference between a free widget and a
// permanent background cost.
//
// Build: swiftc -O -o cpu_usage cpu_usage.swift

import Foundation
import Darwin

let stateFile = "/tmp/.sketchybar_cpu_ticks"

func readTicks() -> (user: Double, system: Double, idle: Double, nice: Double)? {
    var size = mach_msg_type_number_t(
        MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
    var info = host_cpu_load_info_data_t()

    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
            host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
        }
    }
    guard result == KERN_SUCCESS else { return nil }

    return (Double(info.cpu_ticks.0),   // CPU_STATE_USER
            Double(info.cpu_ticks.1),   // CPU_STATE_SYSTEM
            Double(info.cpu_ticks.2),   // CPU_STATE_IDLE
            Double(info.cpu_ticks.3))   // CPU_STATE_NICE
}

guard let now = readTicks() else { exit(1) }

let prev = (try? String(contentsOfFile: stateFile, encoding: .utf8))?
    .split(separator: " ").compactMap { Double($0) }

try? "\(now.user) \(now.system) \(now.idle) \(now.nice)"
    .write(toFile: stateFile, atomically: true, encoding: .utf8)

// First run after boot or a cleared state file: no interval to measure yet.
guard let p = prev, p.count == 4 else {
    print(0)
    exit(0)
}

let dUser = now.user - p[0]
let dSys  = now.system - p[1]
let dIdle = now.idle - p[2]
let dNice = now.nice - p[3]
let total = dUser + dSys + dIdle + dNice

// Counters reset (reboot) or no time elapsed between samples.
guard total > 0 else {
    print(0)
    exit(0)
}

print(Int(((dUser + dSys + dNice) / total * 100).rounded()))
