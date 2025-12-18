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

#if canImport(Glibc) || canImport(Musl)
extension SystemMetricsMonitorDataProvider: SystemMetricsProvider {
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

    private static let systemStartTimeInSecondsSinceEpoch: Int? = {
        // Read system boot time from /proc/stat btime field
        // This provides the Unix timestamp when the system was booted
        let systemStatFile = CFile("/proc/stat")
        systemStatFile.open()
        defer {
            systemStatFile.close()
        }
        while let line = systemStatFile.readLine() {
            if line.starts(with: "btime"),
                let systemUptimeInSecondsSinceEpochString =
                    line
                    .lazy
                    .split(separator: " ")
                    .last?
                    .split(separator: "\n")
                    .first,
                let systemUptimeInSecondsSinceEpoch = Int(String(systemUptimeInSecondsSinceEpochString))
            {
                return systemUptimeInSecondsSinceEpoch
            }
        }
        return nil
    }()

    /// Collect current system metrics data.
    ///
    /// On Linux, this delegates to the static `linuxSystemMetrics()` function.
    ///
    /// - Returns: Current system metrics, or `nil` if collection failed.
    package func data() async -> SystemMetricsMonitor.Data? {
        Self.linuxSystemMetrics()
    }

    /// Collect system metrics data on Linux using multiple system APIs and interfaces.
    ///
    /// This function combines data from several Linux system interfaces to calculate
    /// process metrics:
    ///
    /// Data Sources:
    ///
    /// - `/proc/stat` - System boot time
    /// - `sysconf(_SC_CLK_TCK)` - System clock ticks per second for time conversion
    /// - `sysconf(_SC_PAGESIZE)` - System page size for memory conversion
    /// - `/proc/self/stat` - Process memory usage and start time
    /// - `getrusage(RUSAGE_SELF)` - CPU time
    /// - `getrlimit(RLIMIT_NOFILE)` - Maximum file descriptors limit
    /// - `/proc/self/fd/` directory enumeration - Count of open file descriptors
    ///
    /// - Returns: A `Data` struct containing all collected metrics, or `nil` if
    ///            metrics could not be collected (e.g., due to file read errors).
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
        }

        /// Use sysconf to get system configuration values that do not change
        /// during the lifetime of the process. They are used later to convert
        /// ticks into seconds and memory pages into total bytes.
        enum SystemConfiguration {
            static let clockTicksPerSecond = sysconf(Int32(_SC_CLK_TCK))
            static let pageByteCount = sysconf(Int32(_SC_PAGESIZE))
        }

        let statFile = CFile("/proc/self/stat")
        statFile.open()
        defer {
            statFile.close()
        }

        // Read /proc/self/stat to get process memory and timing statistics
        let statFileContents = statFile.readFull()

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
            let virtualMemoryBytes = Int(stats[StatIndices.virtualMemoryBytes]),
            let rss = Int(stats[StatIndices.residentMemoryBytes]),
            let startTimeTicks = Int(stats[StatIndices.startTimeTicks])
        else { return nil }

        let residentMemoryBytes = rss * SystemConfiguration.pageByteCount
        let processStartTimeInSeconds = startTimeTicks / SystemConfiguration.clockTicksPerSecond

        // Use getrusage(RUSAGE_SELF) system call to get CPU time consumption
        // This provides both user and system time spent by this process
        var _rusage = rusage()
        guard
            withUnsafeMutablePointer(
                to: &_rusage,
                { ptr in
                    #if canImport(Musl)
                    getrusage(RUSAGE_SELF, ptr) == 0
                    #else
                    getrusage(__rusage_who_t(RUSAGE_SELF.rawValue), ptr) == 0
                    #endif
                }
            )
        else { return nil }
        let cpuSecondsUser: Double = Double(_rusage.ru_utime.tv_sec) + Double(_rusage.ru_utime.tv_usec) / 1_000_000.0
        let cpuSecondsSystem: Double = Double(_rusage.ru_stime.tv_sec) + Double(_rusage.ru_stime.tv_usec) / 1_000_000.0
        let cpuSecondsTotal: Double = cpuSecondsUser + cpuSecondsSystem

        guard let systemStartTimeInSecondsSinceEpoch = Self.systemStartTimeInSecondsSinceEpoch else {
            return nil
        }
        let startTimeInSecondsSinceEpoch = systemStartTimeInSecondsSinceEpoch + processStartTimeInSeconds

        // Use getrlimit(RLIMIT_NOFILE) system call to get file descriptor limits
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

        // Count open file descriptors by enumerating /proc/self/fd directory
        // Each entry represents an open file descriptor for this process
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
            cpuSeconds: cpuSecondsTotal,
            maxFileDescriptors: maxFileDescriptors,
            openFileDescriptors: openFileDescriptors
        )
    }
}
#endif
