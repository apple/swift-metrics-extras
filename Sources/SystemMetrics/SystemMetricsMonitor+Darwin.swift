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

#if canImport(Darwin)
import Darwin

extension SystemMetricsMonitorDataProvider: SystemMetricsProvider {
    /// Collect current system metrics data.
    ///
    /// On Darwin, this delegates to the static `darwinSystemMetrics()` function.
    ///
    /// - Returns: Current system metrics, or `nil` if collection failed.
    package func data() async -> SystemMetricsMonitor.Data? {
        Self.darwinSystemMetrics()
    }

    /// Collect system metrics data on Darwin hosts.
    ///
    /// This function reads process statistics using system APIs to produce
    /// a complete snapshot of the process's resource usage.
    ///
    /// - Returns: A `Data` struct containing all collected metrics, or `nil` if
    ///            metrics could not be collected.
    package static func darwinSystemMetrics() -> SystemMetricsMonitor.Data? {
        guard let taskInfo = ProcessTaskInfo.snapshot() else { return nil }
        guard let fileCounts = FileDescriptorCounts.snapshot() else { return nil }

        // Memory consumption
        let virtualMemoryBytes = Int(taskInfo.ptinfo.pti_virtual_size)
        let residentMemoryBytes = Int(taskInfo.ptinfo.pti_resident_size)

        // CPU time
        let userMachTicks = taskInfo.ptinfo.pti_total_user
        let systemMachTicks = taskInfo.ptinfo.pti_total_system

        let cpuTimeSeconds: Double = {
            // Mach ticks need to be converted to nanoseconds using mach_timebase_info
            let totalUserTime = Double(userMachTicks) * Self.machTimebaseRatio
            let totalSystemTime = Double(systemMachTicks) * Self.machTimebaseRatio
            let cpuTimeNanoseconds = totalUserTime + totalSystemTime
            return cpuTimeNanoseconds / Double(NSEC_PER_SEC)
        }()

        return .init(
            virtualMemoryBytes: virtualMemoryBytes,
            residentMemoryBytes: residentMemoryBytes,
            startTimeSeconds: Int(taskInfo.pbsd.pbi_start_tvsec),
            cpuSeconds: cpuTimeSeconds,
            maxFileDescriptors: fileCounts.maximum,
            openFileDescriptors: fileCounts.open
        )
    }

    /// Converts Mach absolute time ticks to nanoseconds.
    ///
    /// This ratio is determined by the CPU architecture and is used
    /// to convert CPU time measurements from hardware ticks to nanoseconds.
    private static let machTimebaseRatio: Double = {
        var info = mach_timebase_info_data_t()
        let result = mach_timebase_info(&info)
        // This is not expected to fail under any normal condition.
        precondition(result == KERN_SUCCESS, "mach_timebase_info failed")
        return Double(info.numer) / Double(info.denom)
    }()

    /// File descriptor counts for the current process.
    ///
    /// This struct holds both the current number of open file descriptors
    /// and the maximum number allowed by the system limit.
    private struct FileDescriptorCounts {
        /// The current number of open file descriptors.
        var open: Int

        /// The configured maximum number of file descriptors.
        var maximum: Int

        /// Collect current file descriptor counts.
        ///
        /// - Returns: File descriptor counts, or `nil` if collection failed.
        static func snapshot() -> Self? {
            let open: Int? = {
                // First, get the required buffer size
                let bufferSize = proc_pidinfo(getpid(), PROC_PIDLISTFDS, 0, nil, 0)
                guard bufferSize > 0 else { return nil }

                let FDInfoLayout = MemoryLayout<proc_fdinfo>.self

                // Next, use a temporary buffer to retrieve the real
                // count of open files.
                let usedSize = withUnsafeTemporaryAllocation(
                    byteCount: Int(bufferSize),
                    alignment: FDInfoLayout.alignment
                ) { rawBuffer in
                    proc_pidinfo(
                        getpid(),
                        PROC_PIDLISTFDS,
                        0,
                        rawBuffer.baseAddress,
                        bufferSize
                    )
                }

                guard usedSize > 0 else { return nil }
                return Int(usedSize) / FDInfoLayout.size
            }()

            let maximum: Int? = {
                var descriptorLimit = rlimit()
                let result = getrlimit(RLIMIT_NOFILE, &descriptorLimit)
                guard result == 0 else { return nil }
                return Int(descriptorLimit.rlim_cur)
            }()

            guard let open, let maximum else { return nil }
            return Self(open: open, maximum: maximum)
        }
    }

    /// Namespace for process task information retrieval.
    private enum ProcessTaskInfo {
        /// Collect current process task information.
        ///
        /// - Returns: Process task information, or `nil` if collection failed.
        static func snapshot() -> proc_taskallinfo? {
            var info = proc_taskallinfo()
            let size = Int32(MemoryLayout<proc_taskallinfo>.size)
            let result = proc_pidinfo(getpid(), PROC_PIDTASKALLINFO, 0, &info, size)
            guard result == size else { return nil }
            return info
        }
    }
}
#endif
