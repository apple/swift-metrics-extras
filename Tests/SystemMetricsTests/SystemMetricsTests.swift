//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2018-2020 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Dispatch
import Foundation
import Testing

@testable import SystemMetrics

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

@Suite("SystemMetrics Tests")
struct SystemMetricsTests {
    @Test("Linux system metrics generation provides all required metrics")
    func systemMetricsGeneration() async throws {
        #if os(Linux)
        let _metrics = SystemMetrics.linuxSystemMetrics()
        #expect(_metrics != nil)
        let metrics = _metrics!
        #expect(metrics.virtualMemoryBytes != 0)
        #expect(metrics.residentMemoryBytes != 0)
        #expect(metrics.startTimeSeconds != 0)
        #expect(metrics.maxFileDescriptors != 0)
        #expect(metrics.openFileDescriptors != 0)
        #else
        #expect(Bool(true), "Skipping on non-Linux platforms")
        #endif
    }

    @Test("Custom labels with prefix are correctly formatted")
    func systemMetricsLabels() throws {
        let labels = SystemMetrics.Labels(
            prefix: "pfx+",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            maxFds: "mfd",
            openFds: "ofd",
            cpuUsage: "cpu"
        )

        #expect(labels.label(for: \.virtualMemoryBytes) == "pfx+vmb")
        #expect(labels.label(for: \.residentMemoryBytes) == "pfx+rmb")
        #expect(labels.label(for: \.startTimeSeconds) == "pfx+sts")
        #expect(labels.label(for: \.cpuSecondsTotal) == "pfx+cpt")
        #expect(labels.label(for: \.maxFileDescriptors) == "pfx+mfd")
        #expect(labels.label(for: \.openFileDescriptors) == "pfx+ofd")
        #expect(labels.label(for: \.cpuUsage) == "pfx+cpu")
    }

    @Test("Configuration preserves all provided settings")
    func systemMetricsConfiguration() throws {
        let labels = SystemMetrics.Labels(
            prefix: "pfx_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            maxFds: "mfd",
            openFds: "ofd",
            cpuUsage: "cpu"
        )
        let dimensions = [("app", "example"), ("environment", "production")]
        let configuration = SystemMetrics.Configuration(
            pollInterval: .microseconds(123_456_789),
            labels: labels,
            dimensions: dimensions
        )

        #expect(configuration.interval == .microseconds(123_456_789))

        #expect(configuration.labels.label(for: \.virtualMemoryBytes) == "pfx_vmb")
        #expect(configuration.labels.label(for: \.residentMemoryBytes) == "pfx_rmb")
        #expect(configuration.labels.label(for: \.startTimeSeconds) == "pfx_sts")
        #expect(configuration.labels.label(for: \.cpuSecondsTotal) == "pfx_cpt")
        #expect(configuration.labels.label(for: \.maxFileDescriptors) == "pfx_mfd")
        #expect(configuration.labels.label(for: \.openFileDescriptors) == "pfx_ofd")
        #expect(configuration.labels.label(for: \.cpuUsage) == "pfx_cpu")

        #expect(configuration.dimensions.contains(where: { $0 == ("app", "example") }))
        #expect(configuration.dimensions.contains(where: { $0 == ("environment", "production") }))

        #expect(!configuration.dimensions.contains(where: { $0 == ("environment", "staging") }))
        #expect(!configuration.dimensions.contains(where: { $0 == ("process", "example") }))
    }

    @Test("CPU usage calculator accurately computes percentage")
    func cpuUsageCalculator() throws {
        #if os(Linux)
        let calculator = SystemMetrics.CPUUsageCalculator()
        var usage = calculator.getUsagePercentage(ticksSinceSystemBoot: 0, cpuTicks: 0)
        #expect(!usage.isNaN)
        #expect(usage == 0)

        usage = calculator.getUsagePercentage(ticksSinceSystemBoot: 20, cpuTicks: 10)
        #expect(!usage.isNaN)
        #expect(usage == 50)
        #else
        #expect(Bool(true), "Skipping on non-Linux platforms")
        #endif
    }

    @Test("Linux resident memory bytes reflects actual allocations")
    func linuxResidentMemoryBytes() throws {
        #if os(Linux)

        let pageByteCount = sysconf(Int32(_SC_PAGESIZE))
        let allocationSize = 10_000 * pageByteCount

        let warmups = 20
        for _ in 0..<warmups {
            let bytes = UnsafeMutableRawBufferPointer.allocate(byteCount: allocationSize, alignment: 1)
            defer { bytes.deallocate() }
            bytes.initializeMemory(as: UInt8.self, repeating: .zero)
        }

        guard let startResidentMemoryBytes = SystemMetrics.linuxSystemMetrics()?.residentMemoryBytes else {
            Issue.record("Could not get resident memory usage.")
            return
        }

        let bytes = UnsafeMutableRawBufferPointer.allocate(byteCount: allocationSize, alignment: 1)
        defer { bytes.deallocate() }
        bytes.initializeMemory(as: UInt8.self, repeating: .zero)

        guard let residentMemoryBytes = SystemMetrics.linuxSystemMetrics()?.residentMemoryBytes else {
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

        #else
        #expect(Bool(true), "Skipping on non-Linux platforms")
        #endif
    }

    @Test("Linux CPU seconds measurement reflects actual CPU usage")
    func linuxCPUSeconds() throws {
        #if os(Linux)

        let bytes = Array(repeating: UInt8.zero, count: 10)
        var hasher = Hasher()

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < 1 {
            bytes.hash(into: &hasher)
        }

        let metrics = SystemMetrics.linuxSystemMetrics()
        #expect(metrics != nil)

        // We can only set expectations for the lower limit for the CPU usage time,
        // other threads executing other tests can add more CPU usage
        #expect(metrics!.cpuSeconds > 0)

        #else
        #expect(Bool(true), "Skipping on non-Linux platforms")
        #endif
    }
}
