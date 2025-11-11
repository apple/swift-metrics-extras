//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import CoreMetrics

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

extension SystemMetricsMonitor {
    /// Minimal file reading implementation so we don't have to depend on Foundation.
    /// Designed only for the narrow use case of this library.
    final class CFile {
        let path: String
        
        private var file: UnsafeMutablePointer<FILE>?
        
        init(_ path: String) {
            self.path = path
        }
        
        deinit {
            assert(self.file == nil)
        }
        
        func open() {
            guard let f = fopen(path, "r") else {
                return
            }
            self.file = f
        }
        
        func close() {
            if let f = self.file {
                self.file = nil
                let success = fclose(f) == 0
                assert(success)
            }
        }
        
        func readLine() -> String? {
            guard let f = self.file else {
                return nil
            }
            return withUnsafeTemporaryAllocation(of: CChar.self, capacity: 1024) { (ptr) -> String? in
                let hasNewLine = {
                    guard fgets(ptr.baseAddress, Int32(ptr.count), f) != nil else {
                        // feof returns non-zero only when eof has been reached
                        if feof(f) != 0 {
                            return false
                        } else {
                            preconditionFailure("Error reading line")
                        }
                    }
                    return true
                }()
                if !hasNewLine {
                    return nil
                }
                // fgets return value has already been checked to be non-null
                // and it returns the pointer passed in as the first argument
                // this ensures at this point the ptr contains a valid C string
                // the initializer will copy the memory ensuring it doesn't
                // outlive the scope of withUnsafeTemporaryAllocation
                return String(cString: ptr.baseAddress!)
            }
        }
        
        func readFull() -> String {
            var s = ""
            func loop() -> String {
                if let l = readLine() {
                    s += l
                    return loop()
                }
                return s
            }
            return loop()
        }
    }
    
    /// A type that can calculate CPU usage for a given process.
    ///
    /// CPU usage is calculated as the number of CPU ticks used by this process between measurements.
    /// - Note: the first measurement will be calculated since the process' start time, since there's no
    /// previous measurement to take as reference.
    package final class CPUUsageCalculator: @unchecked Sendable {
        /// The number of ticks after system boot that the last CPU usage stat was taken.
        private var locked_previousTicksSinceSystemBoot: Int = 0
        /// The number of ticks the process actively used the CPU for, as of the previous CPU usage measurement.
        private var locked_previousCPUTicks: Int = 0
        
        func getUsagePercentage(ticksSinceSystemBoot: Int, cpuTicks: Int) -> Double {
            MetricsSystem.withWriterLock {
                defer {
                    self.locked_previousTicksSinceSystemBoot = ticksSinceSystemBoot
                    self.locked_previousCPUTicks = cpuTicks
                }
                let ticksBetweenMeasurements = ticksSinceSystemBoot - self.locked_previousTicksSinceSystemBoot
                guard ticksBetweenMeasurements > 0 else {
                    return 0
                }
                
                let cpuTicksBetweenMeasurements = cpuTicks - self.locked_previousCPUTicks
                return Double(cpuTicksBetweenMeasurements) * 100 / Double(ticksBetweenMeasurements)
            }
        }
    }
    
    private static let systemStartTimeInSecondsSinceEpoch: Int? = {
        let systemStatFile = CFile("/proc/stat")
        systemStatFile.open()
        defer {
            systemStatFile.close()
        }
        while let line = systemStatFile.readLine() {
            if line.starts(with: "btime"),
               let systemUptimeInSecondsSinceEpochString =
                line
                .split(separator: " ")
                .last?
                .split(separator: "\n")
                .first,
               let systemUptimeInSecondsSinceEpoch = Int(systemUptimeInSecondsSinceEpochString)
            {
                return systemUptimeInSecondsSinceEpoch
            }
        }
        return nil
    }()
    
    private static let cpuUsageCalculator = CPUUsageCalculator()
    
    @Sendable
    package static func linuxSystemMetrics() -> SystemMetricsMonitor.Data? {
        /// The current implementation below reads /proc/self/stat. Then,
        /// presumably to accommodate whitespace in the `comm` field
        /// without dealing with null-terminated C strings, it splits on the
        /// closing parenthesis surrounding the value. It then splits the
        /// remaining string by space, meaning the first element in the
        /// resulting array, at index 0, refers to the the third field.
        ///
        /// Note that the man page documents fields starting at index 1.
        ///
        /// ````
        /// proc_pid_stat(5)     File Formats Manual     proc_pid_stat(5)
        ///
        /// ...
        ///
        ///  (1) pid  %d
        ///         The process ID.
        ///
        ///  (2) comm  %s
        ///         The filename of the executable, in parentheses.
        ///         Strings longer than TASK_COMM_LEN (16) characters
        ///         (including the terminating null byte) are silently
        ///         truncated.  This is visible whether or not the
        ///         executable is swapped out.
        /// ...
        ///
        ///  (14) utime  %lu
        ///         Amount of time that this process has been scheduled
        ///         in user mode, measured in clock ticks (divide by
        ///         sysconf(_SC_CLK_TCK)).  This includes guest time,
        ///         guest_time (time spent running a virtual CPU, see
        ///         below), so that applications that are not aware of
        ///         the guest time field do not lose that time from
        ///         their calculations.
        ///
        ///  (15) stime  %lu
        ///         Amount of time that this process has been scheduled
        ///         in kernel mode, measured in clock ticks (divide by
        ///         sysconf(_SC_CLK_TCK)).
        ///
        /// ...
        ///
        ///  (22) starttime  %llu
        ///         The time the process started after system boot.
        ///         Before Linux 2.6, this value was expressed in
        ///         jiffies.  Since Linux 2.6, the value is expressed in
        ///         clock ticks (divide by sysconf(_SC_CLK_TCK)).
        ///
        ///         The format for this field was %lu before Linux 2.6.
        ///
        ///  (23) vsize  %lu
        ///         Virtual memory size in bytes.
        ///         The format for this field was %lu before Linux 2.6.
        ///
        ///  (24) rss  %ld
        ///         Resident Set Size: number of pages the process has
        ///         in real memory.  This is just the pages which count
        ///         toward text, data, or stack space.  This does not
        ///         include pages which have not been demand-loaded in,
        ///         or which are swapped out.  This value is inaccurate;
        ///         see /proc/pid/statm below.
        /// ```
        enum StatIndices {
            static let virtualMemoryBytes = 20
            static let residentMemoryBytes = 21
            static let startTimeTicks = 19
            static let utimeTicks = 11
            static let stimeTicks = 12
        }
        
        /// Some of the metrics from procfs need to be combined with system
        /// values, which we obtain from sysconf(3). These values do not change
        /// during the lifetime of the process so we define them as static
        /// members here.
        enum SystemConfiguration {
            static let clockTicksPerSecond = sysconf(Int32(_SC_CLK_TCK))
            static let pageByteCount = sysconf(Int32(_SC_PAGESIZE))
        }
        
        let statFile = CFile("/proc/self/stat")
        statFile.open()
        defer {
            statFile.close()
        }
        
        let uptimeFile = CFile("/proc/uptime")
        uptimeFile.open()
        defer {
            uptimeFile.close()
        }
        
        // Read both files as close as possible to each other to get an accurate CPU usage metric.
        let statFileContents = statFile.readFull()
        let uptimeFileContents = uptimeFile.readFull()
        
        guard
            let statString =
                statFileContents
                .split(separator: ")")
                .last
        else { return nil }
        let stats = String(statString)
            .split(separator: " ")
            .map(String.init)
        guard
            let virtualMemoryBytes = Int(stats[safe: StatIndices.virtualMemoryBytes]),
            let rss = Int(stats[safe: StatIndices.residentMemoryBytes]),
            let startTimeTicks = Int(stats[safe: StatIndices.startTimeTicks]),
            let utimeTicks = Int(stats[safe: StatIndices.utimeTicks]),
            let stimeTicks = Int(stats[safe: StatIndices.stimeTicks])
        else { return nil }
        
        let residentMemoryBytes = rss * SystemConfiguration.pageByteCount
        let processStartTimeInSeconds = startTimeTicks / SystemConfiguration.clockTicksPerSecond
        let cpuTicks = utimeTicks + stimeTicks
        let cpuSeconds = cpuTicks / SystemConfiguration.clockTicksPerSecond
        
        guard let systemStartTimeInSecondsSinceEpoch = SystemMetricsMonitor.systemStartTimeInSecondsSinceEpoch else {
            return nil
        }
        let startTimeInSecondsSinceEpoch = systemStartTimeInSecondsSinceEpoch + processStartTimeInSeconds
        
        var cpuUsage: Double = 0
        if cpuTicks > 0 {
            guard let uptimeString = uptimeFileContents.split(separator: " ").first,
                  let uptimeSeconds = Float(uptimeString),
                  uptimeSeconds.isFinite
            else { return nil }
            let uptimeTicks = Int(ceilf(uptimeSeconds)) * SystemConfiguration.clockTicksPerSecond
            cpuUsage = SystemMetricsMonitor.cpuUsageCalculator.getUsagePercentage(
                ticksSinceSystemBoot: uptimeTicks,
                cpuTicks: cpuTicks
            )
        }
        
        var _rlim = rlimit()
        guard
            withUnsafeMutablePointer(
                to: &_rlim,
                { ptr in
                    #if canImport(Musl)
                    getrlimit(RLIMIT_NOFILE, ptr) == 0
                    #else
                    getrlimit(__rlimit_resource_t(RLIMIT_NOFILE.rawValue), ptr) == 0
                    #endif
                }
            )
        else { return nil }
        
        let maxFileDescriptors = Int(_rlim.rlim_max)
        
        guard let dir = opendir("/proc/self/fd") else { return nil }
        defer {
            closedir(dir)
        }
        var openFileDescriptors = 0
        while readdir(dir) != nil { openFileDescriptors += 1 }
        
        return .init(
            virtualMemoryBytes: virtualMemoryBytes,
            residentMemoryBytes: residentMemoryBytes,
            startTimeSeconds: startTimeInSecondsSinceEpoch,
            cpuSeconds: cpuSeconds,
            maxFileDescriptors: maxFileDescriptors,
            openFileDescriptors: openFileDescriptors,
            cpuUsage: cpuUsage
        )
    }
    
    /// Collect current system metrics data.
    ///
    /// On Linux, this delegates to the static `linuxSystemMetrics()` function.
    ///
    /// - Returns: Current system metrics, or `nil` if collection failed.
    func collectMetricsData() -> SystemMetricsMonitor.Data? {
        Self.linuxSystemMetrics()
    }
}
#endif
