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

#if os(macOS)
import Foundation
import Testing
import Darwin

import SystemMetrics

// This suite is serialized, as the tests involve exercising and
// measuring process metrics, so running them concurrently can
// make measurements flaky.

@Suite("Darwin Data Provider Tests", .serialized)
struct DarwinDataProviderTests {

    // MARK: - Test Cases

    @Test("Darwin system metrics generation provides all required metrics")
    func systemMetricsGeneration() throws {
        let metrics = try readMetrics()
        #expect(metrics.virtualMemoryBytes != 0)
        #expect(metrics.residentMemoryBytes != 0)
        #expect(metrics.startTimeSeconds != 0)
        #expect(metrics.maxFileDescriptors != 0)
        #expect(metrics.openFileDescriptors != 0)
    }

    @Test("Resident memory size reflects allocations")
    func residentMemory() throws {
        let allocationSize = 10_000 * pageSize

        let bytesBefore = try readMetric(\.residentMemoryBytes)

        var address = try #require(vmAlloc(allocationSize))
        defer { vmFree(&address, size: allocationSize) }

        // In order for the memory to become resident, we need to access it
        memset(UnsafeMutableRawPointer(bitPattern: address), 0xA2, Int(allocationSize))

        let bytesDuring = try readMetric(\.residentMemoryBytes)
        #expect(bytesDuring > bytesBefore)

        vmFree(&address, size: allocationSize)
        #expect(address == 0)

        let bytesAfter = try readMetric(\.residentMemoryBytes)
        #expect(bytesAfter < bytesDuring)

        // Within 10% of original
        #expect(bytesAfter <= Int(Double(bytesBefore) * 1.1))
    }

    @Test("CPU seconds measurement reflects actual CPU usage")
    func cpuSeconds() throws {
        let cpuSecondsBefore = try readMetric(\.cpuSeconds)
        burnCPUSeconds(1)
        let cpuSecondsAfter = try readMetric(\.cpuSeconds)

        // We can only set expectations for the lower limit for the CPU usage time,
        // other threads executing other tests can add more CPU usage
        #expect((cpuSecondsAfter - cpuSecondsBefore) > 0.1)
    }

    @Test("CPU time is accurate, compared to an alternate API")
    func cpuSecondsMatchAlternative() throws {
        // This test collects `cpuSeconds` using an alternate API
        // and compares it to the values provided in the metrics data.

        // No need to measure the "before" state - that's covered in another test.
        burnCPUSeconds(1)

        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)

        let measuredCPU = try readMetric(\.cpuSeconds)

        func secondsFromComponents(_ seconds: Int, _ microseconds: Int32) -> Double {
            Double(seconds) + Double(microseconds) / Double(USEC_PER_SEC)
        }

        let expectedUserCPU = secondsFromComponents(usage.ru_utime.tv_sec, usage.ru_utime.tv_usec)
        let expectedSystemCPU = secondsFromComponents(usage.ru_stime.tv_sec, usage.ru_stime.tv_usec)
        let expectedCPU = expectedUserCPU + expectedSystemCPU

        #expect(abs(expectedCPU - measuredCPU) < 0.1)
    }

    @Test("Process start time is accurate, compared to an alternate API")
    func processStartMatchesAlternative() throws {
        // This test collects `startTimeSeconds` using an alternate API
        // and compares it to the value provided in the metrics data.

        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var proc = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        let result = sysctl(&mib, UInt32(mib.count), &proc, &size, nil, 0)
        guard result == 0 else {
            Issue.record("sysctl failed")
            return
        }

        let expectedStartTime = proc.kp_proc.p_starttime.tv_sec
        let metricsStartTime = try readMetric(\.startTimeSeconds)

        // We're ignoring sub-second precision in the test-generated
        // timestamp, so allow for the metrics data to round up or down.
        #expect(abs(metricsStartTime - expectedStartTime) <= 1)
    }

    @Test("File descriptor counts are accurate")
    func openFileDescriptors() throws {
        let openBefore = try readMetric(\.openFileDescriptors)

        let fd = open("/dev/null", O_RDONLY)
        guard fd >= 0 else {
            Issue.record("Failed to open /dev/null")
            return
        }
        defer { close(fd) }

        let openDuring = try readMetric(\.openFileDescriptors)
        #expect(openDuring == openBefore + 1)
    }

    @Test("Data provider returns valid metrics via protocol")
    func dataProviderProtocol() async throws {
        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "test_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd"
        )
        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels
        )

        let provider = SystemMetricsMonitorDataProvider(configuration: configuration)
        let data = await provider.data()
        let metrics = try #require(data)
        #expect(metrics.virtualMemoryBytes > 0)
        #expect(metrics.residentMemoryBytes > 0)
        #expect(metrics.startTimeSeconds > 0)
        #expect(metrics.maxFileDescriptors > 0)
        #expect(metrics.openFileDescriptors > 0)
    }

    // MARK: - Helpers

    private let pageSize = sysconf(Int32(_SC_PAGESIZE))

    /// Reads the current system metrics snapshot.
    ///
    /// - Returns: The current system metrics data.
    /// - Throws: If metrics collection fails or returns `nil`.
    private func readMetrics() throws -> SystemMetricsMonitor.Data {
        return try #require(SystemMetricsMonitorDataProvider.darwinSystemMetrics())
    }

    /// Reads a specific metric value for the given key path.
    ///
    /// - Parameter keyPath: The key path to the desired metric value.
    /// - Returns: The value of the specified metric.
    /// - Throws: If metrics collection fails.
    private func readMetric<Result>(
        _ keyPath: KeyPath<SystemMetricsMonitor.Data, Result>
    ) throws -> Result {
        let metrics = try readMetrics()
        return metrics[keyPath: keyPath]
    }

    /// Performs CPU-intensive work for the specified duration.
    ///
    /// - Parameter seconds: Wall-clock time to spend consuming CPU.
    private func burnCPUSeconds(_ seconds: TimeInterval) {
        let bytes = Array(repeating: UInt8.zero, count: 10)
        var hasher = Hasher()

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < seconds {
            bytes.hash(into: &hasher)
        }
    }

    /// Allocates virtual memory using `vm_allocate`.
    ///
    /// These tests use the `vm_allocate`/`vm_deallocate` functions rather than
    /// Swift's `UnsafeMutablePointer.allocate(_:)` family because they make it
    /// easier to observe memory metrics changing when allocations are freed.
    ///
    /// - Parameter size: The number of bytes to allocate.
    /// - Returns: The allocated address, or `nil` if allocation failed.
    private func vmAlloc(_ size: Int) -> vm_address_t? {
        var address: vm_address_t = 0
        let result = vm_allocate(mach_task_self_, &address, vm_size_t(size), VM_FLAGS_ANYWHERE)
        guard result == KERN_SUCCESS else {
            Issue.record("vm_allocate failed")
            return nil
        }
        precondition(address > 0)
        return address
    }

    /// Deallocates virtual memory allocated with `vmAlloc(_:)`.
    ///
    /// This function is idempotent - calling it with the same inout
    /// reference multiple times is safe, as the address is zeroed
    /// upon deallocation.
    ///
    /// - Parameters:
    ///   - address: The address to deallocate (will be set to 0).
    ///   - size: The size of the allocation in bytes.
    private func vmFree(_ address: inout vm_address_t, size: Int) {
        let toFree = address
        address = 0
        guard toFree != 0 else { return }
        vm_deallocate(mach_task_self_, toFree, vm_size_t(size))
    }
}
#endif
