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
@testable import SystemMetrics
import XCTest
#if os(Linux)
import Glibc
#endif

class SystemMetricsTest: XCTestCase {
    func testSystemMetricsGeneration() throws {
        #if os(Linux)
        let _metrics = SystemMetrics.linuxSystemMetrics()
        #else
        let _metrics = SystemMetrics.noopSystemMetrics()
        throw XCTSkip()
        #endif
        XCTAssertNotNil(_metrics)
        let metrics = _metrics!
        XCTAssertNotNil(metrics.virtualMemoryBytes)
        XCTAssertNotNil(metrics.residentMemoryBytes)
        XCTAssertNotNil(metrics.startTimeSeconds)
        XCTAssertNotNil(metrics.cpuSeconds)
        XCTAssertNotNil(metrics.maxFileDescriptors)
        XCTAssertNotNil(metrics.openFileDescriptors)
    }

    func testSystemMetricsLabels() throws {
        let labels = SystemMetrics.Labels(prefix: "pfx+", virtualMemoryBytes: "vmb", residentMemoryBytes: "rmb", startTimeSeconds: "sts", cpuSecondsTotal: "cpt", maxFds: "mfd", openFds: "ofd")

        XCTAssertEqual(labels.label(for: \.virtualMemoryBytes), "pfx+vmb")
        XCTAssertEqual(labels.label(for: \.residentMemoryBytes), "pfx+rmb")
        XCTAssertEqual(labels.label(for: \.startTimeSeconds), "pfx+sts")
        XCTAssertEqual(labels.label(for: \.cpuSecondsTotal), "pfx+cpt")
        XCTAssertEqual(labels.label(for: \.maxFileDescriptors), "pfx+mfd")
        XCTAssertEqual(labels.label(for: \.openFileDescriptors), "pfx+ofd")
    }

    func testSystemMetricsConfiguration() throws {
        let labels = SystemMetrics.Labels(prefix: "pfx_", virtualMemoryBytes: "vmb", residentMemoryBytes: "rmb", startTimeSeconds: "sts", cpuSecondsTotal: "cpt", maxFds: "mfd", openFds: "ofd")
        let dimensions = [("app", "example"), ("environment", "production")]
        let configuration = SystemMetrics.Configuration(pollInterval: .microseconds(123_456_789), labels: labels, dimensions: dimensions)

        XCTAssertTrue(configuration.interval == .microseconds(123_456_789))

        XCTAssertNotNil(configuration.dataProvider)

        XCTAssertEqual(configuration.labels.label(for: \.virtualMemoryBytes), "pfx_vmb")
        XCTAssertEqual(configuration.labels.label(for: \.residentMemoryBytes), "pfx_rmb")
        XCTAssertEqual(configuration.labels.label(for: \.startTimeSeconds), "pfx_sts")
        XCTAssertEqual(configuration.labels.label(for: \.cpuSecondsTotal), "pfx_cpt")
        XCTAssertEqual(configuration.labels.label(for: \.maxFileDescriptors), "pfx_mfd")
        XCTAssertEqual(configuration.labels.label(for: \.openFileDescriptors), "pfx_ofd")

        XCTAssertTrue(configuration.dimensions.contains(where: { $0 == ("app", "example") }))
        XCTAssertTrue(configuration.dimensions.contains(where: { $0 == ("environment", "production") }))

        XCTAssertFalse(configuration.dimensions.contains(where: { $0 == ("environment", "staging") }))
        XCTAssertFalse(configuration.dimensions.contains(where: { $0 == ("process", "example") }))
    }
}
