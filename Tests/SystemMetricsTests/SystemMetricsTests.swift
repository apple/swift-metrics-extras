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
import XCTest

@testable import SystemMetrics

#if os(Linux)
import Glibc
#endif

class SystemMetricsTest: XCTestCase {
    func testSystemMetricsGeneration() throws {
        #if os(Linux)
        let _metrics = SystemMetrics.linuxSystemMetrics()
        XCTAssertNotNil(_metrics)
        let metrics = _metrics!
        XCTAssertNotNil(metrics.virtualMemoryBytes)
        XCTAssertNotNil(metrics.residentMemoryBytes)
        XCTAssertNotNil(metrics.startTimeSeconds)
        XCTAssertNotNil(metrics.cpuSeconds)
        XCTAssertNotNil(metrics.maxFileDescriptors)
        XCTAssertNotNil(metrics.openFileDescriptors)
        XCTAssertNotNil(metrics.cpuUsage)
        #else
        throw XCTSkip()
        #endif
    }

    func testSystemMetricsLabels() throws {
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

        XCTAssertEqual(labels.label(for: \.virtualMemoryBytes), "pfx+vmb")
        XCTAssertEqual(labels.label(for: \.residentMemoryBytes), "pfx+rmb")
        XCTAssertEqual(labels.label(for: \.startTimeSeconds), "pfx+sts")
        XCTAssertEqual(labels.label(for: \.cpuSecondsTotal), "pfx+cpt")
        XCTAssertEqual(labels.label(for: \.maxFileDescriptors), "pfx+mfd")
        XCTAssertEqual(labels.label(for: \.openFileDescriptors), "pfx+ofd")
        XCTAssertEqual(labels.label(for: \.cpuUsage), "pfx+cpu")
    }

    func testSystemMetricsConfiguration() throws {
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

        XCTAssertTrue(configuration.interval == .microseconds(123_456_789))

        XCTAssertNotNil(configuration.dataProvider)

        XCTAssertEqual(configuration.labels.label(for: \.virtualMemoryBytes), "pfx_vmb")
        XCTAssertEqual(configuration.labels.label(for: \.residentMemoryBytes), "pfx_rmb")
        XCTAssertEqual(configuration.labels.label(for: \.startTimeSeconds), "pfx_sts")
        XCTAssertEqual(configuration.labels.label(for: \.cpuSecondsTotal), "pfx_cpt")
        XCTAssertEqual(configuration.labels.label(for: \.maxFileDescriptors), "pfx_mfd")
        XCTAssertEqual(configuration.labels.label(for: \.openFileDescriptors), "pfx_ofd")
        XCTAssertEqual(configuration.labels.label(for: \.cpuUsage), "pfx_cpu")

        XCTAssertTrue(configuration.dimensions.contains(where: { $0 == ("app", "example") }))
        XCTAssertTrue(configuration.dimensions.contains(where: { $0 == ("environment", "production") }))

        XCTAssertFalse(configuration.dimensions.contains(where: { $0 == ("environment", "staging") }))
        XCTAssertFalse(configuration.dimensions.contains(where: { $0 == ("process", "example") }))
    }

    func testCPUUsageCalculator() throws {
        #if os(Linux)
        let calculator = SystemMetrics.CPUUsageCalculator()
        var usage = calculator.getUsagePercentage(ticksSinceSystemBoot: 0, cpuTicks: 0)
        XCTAssertFalse(usage.isNaN)
        XCTAssertEqual(usage, 0)

        usage = calculator.getUsagePercentage(ticksSinceSystemBoot: 20, cpuTicks: 10)
        XCTAssertFalse(usage.isNaN)
        XCTAssertEqual(usage, 50)
        #else
        throw XCTSkip()
        #endif
    }

    func testLinuxResidentMemoryBytes() throws {
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
            XCTFail("Could not get resident memory usage.")
            return
        }

        let bytes = UnsafeMutableRawBufferPointer.allocate(byteCount: allocationSize, alignment: 1)
        defer { bytes.deallocate() }
        bytes.initializeMemory(as: UInt8.self, repeating: .zero)

        guard let residentMemoryBytes = SystemMetrics.linuxSystemMetrics()?.residentMemoryBytes else {
            XCTFail("Could not get resident memory usage.")
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
        XCTAssertEqual(residentMemoryBytes - startResidentMemoryBytes, allocationSize, accuracy: allocationSize / 100)

        #else
        throw XCTSkip()
        #endif
    }

    func testLinuxCPUSeconds() throws {
        #if os(Linux)

        let bytes = Array(repeating: UInt8.zero, count: 10)
        var hasher = Hasher()

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < 1 {
            bytes.hash(into: &hasher)
        }

        XCTAssertEqual(SystemMetrics.linuxSystemMetrics()?.cpuSeconds, 1)

        #else
        throw XCTSkip()
        #endif
    }
}
