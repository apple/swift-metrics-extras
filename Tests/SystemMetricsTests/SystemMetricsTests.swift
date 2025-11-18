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

import CoreMetrics
import Dispatch
import Foundation
import MetricsTestKit
import SystemMetricsMonitor
import Testing

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct MockMetricsProvider: SystemMetricsProvider {
    let mockData: SystemMetricsMonitor.Data?

    func data() async -> SystemMetricsMonitor.Data? {
        mockData
    }
}

@Suite("SystemMetrics Tests")
struct SystemMetricsTests {
    @Test("Custom labels with prefix are correctly formatted")
    func systemMetricsLabels() throws {
        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "pfx+",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            cpuUsage: "cpu",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd"
        )

        #expect(labels.label(for: \.virtualMemoryBytes) == "pfx+vmb")
        #expect(labels.label(for: \.residentMemoryBytes) == "pfx+rmb")
        #expect(labels.label(for: \.startTimeSeconds) == "pfx+sts")
        #expect(labels.label(for: \.cpuSecondsTotal) == "pfx+cpt")
        #expect(labels.label(for: \.cpuUsage) == "pfx+cpu")
        #expect(labels.label(for: \.maxFileDescriptors) == "pfx+mfd")
        #expect(labels.label(for: \.openFileDescriptors) == "pfx+ofd")
    }

    @Test("Configuration preserves all provided settings")
    func systemMetricsConfiguration() throws {
        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "pfx_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            cpuUsage: "cpu",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd"
        )
        let dimensions = [("app", "example"), ("environment", "production")]
        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .microseconds(123_456_789),
            labels: labels,
            dimensions: dimensions
        )

        #expect(configuration.interval == .microseconds(123_456_789))

        #expect(configuration.labels.label(for: \.virtualMemoryBytes) == "pfx_vmb")
        #expect(configuration.labels.label(for: \.residentMemoryBytes) == "pfx_rmb")
        #expect(configuration.labels.label(for: \.startTimeSeconds) == "pfx_sts")
        #expect(configuration.labels.label(for: \.cpuSecondsTotal) == "pfx_cpt")
        #expect(configuration.labels.label(for: \.cpuUsage) == "pfx_cpu")
        #expect(configuration.labels.label(for: \.maxFileDescriptors) == "pfx_mfd")
        #expect(configuration.labels.label(for: \.openFileDescriptors) == "pfx_ofd")

        #expect(configuration.dimensions.contains(where: { $0 == ("app", "example") }))
        #expect(configuration.dimensions.contains(where: { $0 == ("environment", "production") }))

        #expect(!configuration.dimensions.contains(where: { $0 == ("environment", "staging") }))
        #expect(!configuration.dimensions.contains(where: { $0 == ("process", "example") }))
    }

    @Test("Monitor with custom provider reports metrics correctly")
    func monitorWithCustomProvider() async throws {
        let mockData = SystemMetricsMonitor.Data(
            virtualMemoryBytes: 1000,
            residentMemoryBytes: 2000,
            startTimeSeconds: 3000,
            cpuSeconds: 4000,
            cpuUsage: 7.5,
            maxFileDescriptors: 5000,
            openFileDescriptors: 6000
        )

        let provider = MockMetricsProvider(mockData: mockData)
        let testMetrics = TestMetrics()

        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "test_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            cpuUsage: "cpu",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd"
        )

        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels
        )

        let monitor = SystemMetricsMonitor(
            configuration: configuration,
            metricsFactory: testMetrics,
            dataProvider: provider
        )

        try await monitor.updateMetrics()

        let vmbGauge = try testMetrics.expectGauge("test_vmb")
        #expect(vmbGauge.lastValue == 1000)

        let rmbGauge = try testMetrics.expectGauge("test_rmb")
        #expect(rmbGauge.lastValue == 2000)

        let stsGauge = try testMetrics.expectGauge("test_sts")
        #expect(stsGauge.lastValue == 3000)

        let cptGauge = try testMetrics.expectGauge("test_cpt")
        #expect(cptGauge.lastValue == 4000)

        let cpuGauge = try testMetrics.expectGauge("test_cpu")
        #expect(cpuGauge.lastValue == 7.5)

        let mfdGauge = try testMetrics.expectGauge("test_mfd")
        #expect(mfdGauge.lastValue == 5000)

        let ofdGauge = try testMetrics.expectGauge("test_ofd")
        #expect(ofdGauge.lastValue == 6000)
    }

    @Test("Monitor with nil provider does not report metrics")
    func monitorWithNilProvider() async throws {
        let provider = MockMetricsProvider(mockData: nil)
        let testMetrics = TestMetrics()

        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "test_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            cpuUsage: "cpu",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd"
        )

        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels
        )

        let monitor = SystemMetricsMonitor(
            configuration: configuration,
            metricsFactory: testMetrics,
            dataProvider: provider
        )

        try await monitor.updateMetrics()

        #expect(testMetrics.recorders.isEmpty)
    }

    @Test("Monitor with dimensions includes them in recorded metrics")
    func monitorWithDimensions() async throws {
        let mockData = SystemMetricsMonitor.Data(
            virtualMemoryBytes: 1000,
            residentMemoryBytes: 2000,
            startTimeSeconds: 3000,
            cpuSeconds: 4000,
            cpuUsage: 7.5,
            maxFileDescriptors: 5000,
            openFileDescriptors: 6000
        )

        let provider = MockMetricsProvider(mockData: mockData)
        let testMetrics = TestMetrics()

        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "test_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            cpuUsage: "cpu",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd"
        )

        let dimensions = [("service", "myapp"), ("environment", "production")]
        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels,
            dimensions: dimensions
        )

        let monitor = SystemMetricsMonitor(
            configuration: configuration,
            metricsFactory: testMetrics,
            dataProvider: provider
        )

        try await monitor.updateMetrics()

        let vmbGauge = try testMetrics.expectGauge("test_vmb", dimensions)
        #expect(vmbGauge.lastValue == 1000)
    }

    @Test("Monitor run() method collects metrics periodically")
    func monitorRunPeriodically() async throws {
        actor CallCountingProvider: SystemMetricsProvider {
            var callCount = 0
            let mockData: SystemMetricsMonitor.Data

            init(mockData: SystemMetricsMonitor.Data) {
                self.mockData = mockData
            }

            func data() async -> SystemMetricsMonitor.Data? {
                callCount += 1
                return mockData
            }

            func getCallCount() -> Int {
                callCount
            }
        }

        let mockData = SystemMetricsMonitor.Data(
            virtualMemoryBytes: 1000,
            residentMemoryBytes: 2000,
            startTimeSeconds: 3000,
            cpuSeconds: 4000,
            cpuUsage: 7.5,
            maxFileDescriptors: 5000,
            openFileDescriptors: 6000
        )

        let provider = CallCountingProvider(mockData: mockData)
        let testMetrics = TestMetrics()

        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "test_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            cpuUsage: "cpu",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd"
        )

        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .milliseconds(100),
            labels: labels
        )

        let monitor = SystemMetricsMonitor(
            configuration: configuration,
            metricsFactory: testMetrics,
            dataProvider: provider
        )

        // Run the monitor in a task and cancel after a short time
        let monitorTask = Task {
            try await monitor.run()
        }

        try await Task.sleep(for: .milliseconds(350))
        monitorTask.cancel()

        let callCount = await provider.getCallCount()
        // With 100ms interval and 350ms wait, we expect 3-4 calls
        #expect(callCount >= 3)
        #expect(callCount <= 5)

        let vmbGauge = try testMetrics.expectGauge("test_vmb")
        #expect(vmbGauge.lastValue == 1000)
    }

    @Test("Monitor with default provider uses platform implementation")
    func monitorWithDefaultProvider() async throws {
        let testMetrics = TestMetrics()

        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "test_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            cpuUsage: "cpu",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd"
        )

        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels
        )

        // No custom provider - uses SystemMetricsMonitorDataProvider internally
        let monitor = SystemMetricsMonitor(configuration: configuration, metricsFactory: testMetrics)

        try await monitor.updateMetrics()

        #if os(Linux)
        let vmbGauge = try testMetrics.expectGauge("test_vmb")
        #expect(vmbGauge.lastValue != nil)
        #expect(vmbGauge.lastValue! > 0)
        #else
        // On macOS, the provider returns nil, so no metrics should be recorded
        #expect(
            !testMetrics.recorders.contains(where: { recorder in
                recorder.label == "test_vmb"
            })
        )
        #endif
    }
}

@Suite("SystemMetrics with MetricsSystem Initialization Tests", .serialized)
struct SystemMetricsInitializationTests {
    static let sharedSetup: TestMetrics = {
        let testMetrics = TestMetrics()
        MetricsSystem.bootstrap(testMetrics)
        return testMetrics
    }()

    let testMetrics: TestMetrics = Self.sharedSetup

    @Test("Monitor uses global MetricsSystem when no factory provided")
    func monitorUsesGlobalMetricsSystem() async throws {
        let mockData = SystemMetricsMonitor.Data(
            virtualMemoryBytes: 1000,
            residentMemoryBytes: 2000,
            startTimeSeconds: 3000,
            cpuSeconds: 4000,
            cpuUsage: 7.5,
            maxFileDescriptors: 5000,
            openFileDescriptors: 6000
        )

        let provider = MockMetricsProvider(mockData: mockData)

        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "global_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            cpuUsage: "cpu",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd"
        )

        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels
        )

        // No custom factory provided - should use global MetricsSystem
        let monitor = SystemMetricsMonitor(
            configuration: configuration,
            dataProvider: provider
        )

        try await monitor.updateMetrics()

        let vmbGauge = try testMetrics.expectGauge("global_vmb")
        #expect(vmbGauge.lastValue == 1000)

        let rmbGauge = try testMetrics.expectGauge("global_rmb")
        #expect(rmbGauge.lastValue == 2000)
    }

    @Test("Monitor with default provider uses platform implementation")
    func monitorWithDefaultProvider() async throws {
        let labels = SystemMetricsMonitor.Configuration.Labels(
            prefix: "default_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            cpuUsage: "cpu",
            maxFileDescriptors: "mfd",
            openFileDescriptors: "ofd"
        )

        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels
        )

        // No custom provider - uses SystemMetricsMonitorDataProvider internally
        let monitor = SystemMetricsMonitor(configuration: configuration)

        try await monitor.updateMetrics()

        #if os(Linux)
        let vmbGauge = try testMetrics.expectGauge("default_vmb")
        #expect(vmbGauge.lastValue != nil)
        #expect(vmbGauge.lastValue! > 0)
        #else
        // On macOS, the provider returns nil, so no metrics should be recorded
        #expect(
            !testMetrics.recorders.contains(where: { recorder in
                recorder.label == "default_vmb"
            })
        )
        #endif
    }
}
