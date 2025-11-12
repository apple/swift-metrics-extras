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

#if os(Linux)
import Foundation
import Testing
import Glibc

import SystemMetrics

@Suite("Linux Data Provider Tests")
struct LinuxDataProviderTests {
    @Test("Linux system metrics generation provides all required metrics")
    func systemMetricsGeneration() async throws {
        let _metrics = SystemMetricsMonitorDataProvider.linuxSystemMetrics()
        #expect(_metrics != nil)
        let metrics = _metrics!
        #expect(metrics.virtualMemoryBytes != 0)
        #expect(metrics.residentMemoryBytes != 0)
        #expect(metrics.startTimeSeconds != 0)
        #expect(metrics.maxFileDescriptors != 0)
        #expect(metrics.openFileDescriptors != 0)
    }

    @Test("CPU usage calculator accurately computes percentage")
    func cpuUsageCalculator() throws {
        let calculator = SystemMetricsMonitorDataProvider.CPUUsageCalculator()
        var usage = calculator.getUsagePercentage(ticksSinceSystemBoot: 0, cpuTicks: 0)
        #expect(!usage.isNaN)
        #expect(usage == 0)

        usage = calculator.getUsagePercentage(ticksSinceSystemBoot: 20, cpuTicks: 10)
        #expect(!usage.isNaN)
        #expect(usage == 50)
    }

    @Test("Resident memory bytes reflects actual allocations")
    func residentMemoryBytes() throws {
        let pageByteCount = sysconf(Int32(_SC_PAGESIZE))
        let allocationSize = 10_000 * pageByteCount

        let warmups = 20
        for _ in 0..<warmups {
            let bytes = UnsafeMutableRawBufferPointer.allocate(byteCount: allocationSize, alignment: 1)
            defer { bytes.deallocate() }
            bytes.initializeMemory(as: UInt8.self, repeating: .zero)
        }

        guard let startResidentMemoryBytes = SystemMetricsMonitorDataProvider.linuxSystemMetrics()?.residentMemoryBytes else {
            Issue.record("Could not get resident memory usage.")
            return
        }

        let bytes = UnsafeMutableRawBufferPointer.allocate(byteCount: allocationSize, alignment: 1)
        defer { bytes.deallocate() }
        bytes.initializeMemory(as: UInt8.self, repeating: .zero)

        guard let residentMemoryBytes = SystemMetricsMonitorDataProvider.linuxSystemMetrics()?.residentMemoryBytes else {
            Issue.record("Could not get resident memory usage.")
            return
        }

        /// According to the man page for proc_pid_stat(5) the value is
        /// advertised as inaccurate.  It refers to proc_pid_statm(5), which
        /// itself states:
        ///
        ///     Some of these values are inaccurate because of a kernel-
        ///     internal scalability optimization.  If accurate values are
        ///     required, use /proc/pid/smaps or /proc/pid/smaps_rollup
        ///     instead, which are much slower but provide accurate,
        ///     detailed information.
        ///
        /// Deferring discussion on whether we should extend this package to
        /// produce these slower-to-retrieve, more-accurate values, we check
        /// that the RSS value is within 1% of the expected allocation increase.
        let difference = residentMemoryBytes - startResidentMemoryBytes
        let accuracy = allocationSize / 100
        #expect(abs(difference - allocationSize) <= accuracy)
    }

    @Test("CPU seconds measurement reflects actual CPU usage")
    func cpuSeconds() throws {
        let bytes = Array(repeating: UInt8.zero, count: 10)
        var hasher = Hasher()

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < 1 {
            bytes.hash(into: &hasher)
        }

        let metrics = SystemMetricsMonitorDataProvider.linuxSystemMetrics()
        #expect(metrics != nil)

        // We can only set expectations for the lower limit for the CPU usage time,
        // other threads executing other tests can add more CPU usage
        #expect(metrics!.cpuSeconds > 0)
    }

    @Test("Data provider returns valid metrics via protocol")
    func dataProviderProtocol() async throws {
        let labels = SystemMetricsMonitor.Labels(
            prefix: "test_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            maxFds: "mfd",
            openFds: "ofd",
            cpuUsage: "cpu"
        )
        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels
        )

        let provider = SystemMetricsMonitorDataProvider(configuration: configuration)
        let data = try await provider.data()

        #expect(data != nil)
        let metrics = data!
        #expect(metrics.virtualMemoryBytes > 0)
        #expect(metrics.residentMemoryBytes > 0)
        #expect(metrics.startTimeSeconds > 0)
        #expect(metrics.maxFileDescriptors > 0)
        #expect(metrics.openFileDescriptors > 0)
    }
}
#endif
