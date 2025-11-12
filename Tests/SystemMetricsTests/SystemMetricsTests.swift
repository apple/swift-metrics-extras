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

import SystemMetrics
import CoreMetrics
import MetricsTestKit

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// A mock metrics provider for testing
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct MockMetricsProvider: SystemMetricsProvider {
    let mockData: SystemMetricsMonitor.Data?

    func data() async throws -> SystemMetricsMonitor.Data? {
        mockData
    }
}

@Suite("SystemMetrics Tests")
struct SystemMetricsTests {
    @Test("Custom labels with prefix are correctly formatted")
    func systemMetricsLabels() throws {
        let labels = SystemMetricsMonitor.Labels(
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
        let labels = SystemMetricsMonitor.Labels(
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
        #expect(configuration.labels.label(for: \.maxFileDescriptors) == "pfx_mfd")
        #expect(configuration.labels.label(for: \.openFileDescriptors) == "pfx_ofd")
        #expect(configuration.labels.label(for: \.cpuUsage) == "pfx_cpu")

        #expect(configuration.dimensions.contains(where: { $0 == ("app", "example") }))
        #expect(configuration.dimensions.contains(where: { $0 == ("environment", "production") }))

        #expect(!configuration.dimensions.contains(where: { $0 == ("environment", "staging") }))
        #expect(!configuration.dimensions.contains(where: { $0 == ("process", "example") }))
    }

    @Test("Monitor with custom provider reports metrics correctly")
    func monitorWithCustomProvider() async throws {
        // Create mock data
        let mockData = SystemMetricsMonitor.Data(
            virtualMemoryBytes: 1000,
            residentMemoryBytes: 2000,
            startTimeSeconds: 3000,
            cpuSeconds: 4000,
            maxFileDescriptors: 5000,
            openFileDescriptors: 6000,
            cpuUsage: 7.5
        )

        // Create mock provider
        let provider = MockMetricsProvider(mockData: mockData)

        // Create test metrics factory
        let testMetrics = TestMetrics()

        // Create labels
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

        // Create configuration
        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels
        )

        // Create monitor with mock provider
        let monitor = SystemMetricsMonitor(
            configuration: configuration,
            metricsFactory: testMetrics,
            dataProvider: provider
        )

        // Update metrics once
        try await monitor.updateMetrics()

        // Verify each metric was recorded with correct values
        let vmbGauge = try testMetrics.expectGauge("test_vmb")
        #expect(vmbGauge.lastValue == 1000)
        
        let rmbGauge = try testMetrics.expectGauge("test_rmb")
        #expect(rmbGauge.lastValue == 2000)
        
        let stsGauge = try testMetrics.expectGauge("test_sts")
        #expect(stsGauge.lastValue == 3000)
        
        let cptGauge = try testMetrics.expectGauge("test_cpt")
        #expect(cptGauge.lastValue == 4000)
        
        let mfdGauge = try testMetrics.expectGauge("test_mfd")
        #expect(mfdGauge.lastValue == 5000)
        
        let ofdGauge = try testMetrics.expectGauge("test_ofd")
        #expect(ofdGauge.lastValue == 6000)
        
        let cpuGauge = try testMetrics.expectGauge("test_cpu")
        #expect(cpuGauge.lastValue == 7.5)
    }

    @Test("Monitor with nil provider does not report metrics")
    func monitorWithNilProvider() async throws {
        // Create mock provider that returns nil
        let provider = MockMetricsProvider(mockData: nil)

        // Create test metrics factory
        let testMetrics = TestMetrics()

        // Create labels
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

        // Create configuration
        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels
        )

        // Create monitor with mock provider
        let monitor = SystemMetricsMonitor(
            configuration: configuration,
            metricsFactory: testMetrics,
            dataProvider: provider
        )

        // Update metrics once
        try await monitor.updateMetrics()

        // Verify no metrics were recorded
        #expect(testMetrics.recorders.count == 0)
    }

    @Test("Monitor with dimensions includes them in recorded metrics")
    func monitorWithDimensions() async throws {
        // Create mock data
        let mockData = SystemMetricsMonitor.Data(
            virtualMemoryBytes: 1000,
            residentMemoryBytes: 2000,
            startTimeSeconds: 3000,
            cpuSeconds: 4000,
            maxFileDescriptors: 5000,
            openFileDescriptors: 6000,
            cpuUsage: 7.5
        )

        // Create mock provider
        let provider = MockMetricsProvider(mockData: mockData)

        // Create test metrics factory
        let testMetrics = TestMetrics()

        // Create labels
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

        // Create configuration with dimensions
        let dimensions = [("service", "myapp"), ("environment", "production")]
        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels,
            dimensions: dimensions
        )

        // Create monitor with mock provider
        let monitor = SystemMetricsMonitor(
            configuration: configuration,
            metricsFactory: testMetrics,
            dataProvider: provider
        )

        // Update metrics once
        try await monitor.updateMetrics()

        // Verify metrics include dimensions
        let vmbGauge = try testMetrics.expectGauge("test_vmb", dimensions)
        #expect(vmbGauge.lastValue == 1000)
    }

    @Test("Monitor run() method collects metrics periodically")
    func monitorRunPeriodically() async throws {
        // Create a provider that tracks how many times it's called
        actor CallCountingProvider: SystemMetricsProvider {
            var callCount = 0
            let mockData: SystemMetricsMonitor.Data

            init(mockData: SystemMetricsMonitor.Data) {
                self.mockData = mockData
            }

            func data() async throws -> SystemMetricsMonitor.Data? {
                callCount += 1
                return mockData
            }

            func getCallCount() -> Int {
                callCount
            }
        }

        // Create mock data
        let mockData = SystemMetricsMonitor.Data(
            virtualMemoryBytes: 1000,
            residentMemoryBytes: 2000,
            startTimeSeconds: 3000,
            cpuSeconds: 4000,
            maxFileDescriptors: 5000,
            openFileDescriptors: 6000,
            cpuUsage: 7.5
        )

        // Create counting provider
        let provider = CallCountingProvider(mockData: mockData)

        // Create test metrics factory
        let testMetrics = TestMetrics()

        // Create labels
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

        // Create configuration with short interval for testing
        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .milliseconds(100),
            labels: labels
        )

        // Create monitor
        let monitor = SystemMetricsMonitor(
            configuration: configuration,
            metricsFactory: testMetrics,
            dataProvider: provider
        )

        // Run the monitor in a task and cancel after a short time
        let monitorTask = Task {
            try await monitor.run()
        }

        // Wait for a bit to let it collect a few times
        try await Task.sleep(for: .milliseconds(350))

        // Cancel the monitoring task
        monitorTask.cancel()

        // Give it a moment to finish cancellation
        try await Task.sleep(for: .milliseconds(50))

        // Verify the provider was called multiple times
        let callCount = await provider.getCallCount()
        // With 100ms interval and 350ms wait, we expect 3-4 calls
        #expect(callCount >= 3)
        #expect(callCount <= 5)

        // Verify metrics were recorded
        let vmbGauge = try testMetrics.expectGauge("test_vmb")
        #expect(vmbGauge.lastValue == 1000)
    }
}

