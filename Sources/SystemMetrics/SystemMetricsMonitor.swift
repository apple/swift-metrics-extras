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
import AsyncAlgorithms
import CoreMetrics
import Foundation

/// A protocol for providing system metrics data.
///
/// Types conforming to this protocol can provide system metrics data
/// to a `SystemMetricsMonitor`. This allows for flexible data collection
/// strategies, including custom implementations for testing.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public protocol SystemMetricsProvider {
    /// Retrieve current system metrics data.
    ///
    /// - Returns: Current system metrics, or `nil` if collection failed
    ///            or is unsupported on the current platform.
    func data() async -> SystemMetricsMonitor.Data?
}

/// A monitor that periodically collects and reports system metrics.
///
/// `SystemMetricsMonitor` provides a way to automatically collect process-level system metrics
/// (such as memory usage, CPU time) and report them through the Swift Metrics API.
///
/// Example usage:
/// ```swift
/// let labels = SystemMetricsMonitor.Labels(
///     prefix: "process_",
///     virtualMemoryBytes: "virtual_memory_bytes",
///     residentMemoryBytes: "resident_memory_bytes",
///     startTimeSeconds: "start_time_seconds",
///     cpuSecondsTotal: "cpu_seconds_total",
///     maxFds: "max_fds",
///     openFds: "open_fds",
///     cpuUsage: "cpu_usage"
/// )
/// let configuration = SystemMetricsMonitor.Configuration(
///     pollInterval: .seconds(2),
///     labels: labels
/// )
/// let monitor = SystemMetricsMonitor(configuration: configuration)
/// try await monitor.run()
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct SystemMetricsMonitor {
    /// Configuration for the system metrics monitor.
    let configuration: SystemMetricsMonitor.Configuration

    /// Optional metrics factory for testing. If nil, uses `MetricsSystem.factory`.
    let metricsFactory: MetricsFactory?

    /// The provider responsible for collecting system metrics data.
    let dataProvider: SystemMetricsProvider

    /// Create a new `SystemMetricsMonitor` with a custom metrics factory and data provider.
    ///
    /// This initializer is primarily useful for testing, allowing you to inject
    /// both a custom metrics factory and a custom data provider.
    ///
    /// - Parameters:
    ///   - configuration: The configuration for the monitor.
    ///   - metricsFactory: The metrics factory to use for creating metrics.
    ///   - dataProvider: The provider to use for collecting system metrics data.
    public init(
        configuration: SystemMetricsMonitor.Configuration,
        metricsFactory: MetricsFactory,
        dataProvider: SystemMetricsProvider
    ) {
        self.configuration = configuration
        self.metricsFactory = metricsFactory
        self.dataProvider = dataProvider
    }

    /// Create a new `SystemMetricsMonitor` with a custom data provider.
    ///
    /// - Parameters:
    ///   - configuration: The configuration for the monitor.
    ///   - dataProvider: The provider to use for collecting system metrics data.
    public init(configuration: SystemMetricsMonitor.Configuration, dataProvider: SystemMetricsProvider) {
        self.configuration = configuration
        self.metricsFactory = nil
        self.dataProvider = dataProvider
    }

    /// Create a new `SystemMetricsMonitor` using the global metrics factory.
    ///
    /// - Parameters:
    ///   - configuration: The configuration for the monitor.
    public init(configuration: SystemMetricsMonitor.Configuration) {
        self.configuration = configuration
        self.metricsFactory = nil
        // Create a temporary instance to use as the default provider
        let temp = SystemMetricsMonitorDataProvider(configuration: configuration)
        self.dataProvider = temp
    }

    /// Collect and report system metrics once.
    ///
    /// This method collects current system metrics and reports them as gauges
    /// using the configured labels and dimensions. If metric collection fails
    /// or is unsupported on the current platform, this method returns without
    /// reporting any metrics.
    package func updateMetrics() async throws {
        guard let metrics = await self.dataProvider.data() else { return }
        let effectiveMetricsFactory = self.metricsFactory ?? MetricsSystem.factory
        Gauge(
            label: self.configuration.labels.label(for: \.virtualMemoryBytes),
            dimensions: self.configuration.dimensions,
            factory: effectiveMetricsFactory
        ).record(
            metrics.virtualMemoryBytes
        )
        Gauge(
            label: self.configuration.labels.label(for: \.residentMemoryBytes),
            dimensions: self.configuration.dimensions,
            factory: effectiveMetricsFactory
        ).record(
            metrics.residentMemoryBytes
        )
        Gauge(
            label: self.configuration.labels.label(for: \.startTimeSeconds),
            dimensions: self.configuration.dimensions,
            factory: effectiveMetricsFactory
        ).record(
            metrics.startTimeSeconds
        )
        Gauge(
            label: self.configuration.labels.label(for: \.cpuSecondsTotal),
            dimensions: self.configuration.dimensions,
            factory: effectiveMetricsFactory
        ).record(
            metrics.cpuSeconds
        )
        Gauge(
            label: self.configuration.labels.label(for: \.maxFileDescriptors),
            dimensions: self.configuration.dimensions,
            factory: effectiveMetricsFactory
        ).record(
            metrics.maxFileDescriptors
        )
        Gauge(
            label: self.configuration.labels.label(for: \.openFileDescriptors),
            dimensions: self.configuration.dimensions,
            factory: effectiveMetricsFactory
        ).record(
            metrics.openFileDescriptors
        )
        Gauge(
            label: self.configuration.labels.label(for: \.cpuUsage),
            dimensions: self.configuration.dimensions,
            factory: effectiveMetricsFactory
        ).record(
            metrics.cpuUsage
        )
    }

    /// Start the monitoring loop, collecting and reporting metrics at the configured interval.
    ///
    /// This method runs indefinitely, periodically collecting and reporting system metrics
    /// according to the poll interval specified in the configuration. It will only return
    /// if the async task is cancelled.
    public func run() async throws {
        for await _ in AsyncTimerSequence(interval: self.configuration.interval, clock: .continuous) {
            try await self.updateMetrics()
        }
    }
}

/// Default implementation of `SystemMetricsProvider` for collecting system metrics data.
///
/// This provider collects process-level metrics from the operating system.
/// It is used as the default data provider when no custom provider is specified.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
package struct SystemMetricsMonitorDataProvider {
    let configuration: SystemMetricsMonitor.Configuration

    package init(configuration: SystemMetricsMonitor.Configuration) {
        self.configuration = configuration
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension SystemMetricsMonitor {
    /// System Metric data.
    ///
    /// The current list of metrics exposed is a superset of the Prometheus Client Library Guidelines:
    /// https://prometheus.io/docs/instrumenting/writing_clientlibs/#standard-and-runtime-collectors
    public struct Data: Sendable {
        /// Virtual memory size in bytes.
        var virtualMemoryBytes: Int
        /// Resident memory size in bytes.
        var residentMemoryBytes: Int
        /// Start time of the process since unix epoch in seconds.
        var startTimeSeconds: Int
        /// Total user and system CPU time spent in seconds.
        var cpuSeconds: Int
        /// Maximum number of open file descriptors.
        var maxFileDescriptors: Int
        /// Number of open file descriptors.
        var openFileDescriptors: Int
        /// CPU usage percentage.
        var cpuUsage: Double

        /// Create a new `Data` instance.
        ///
        /// - parameters:
        ///     - virtualMemoryBytes: Virtual memory size in bytes
        ///     - residentMemoryBytes: Resident memory size in bytes.
        ///     - startTimeSeconds: Total user and system CPU time spent in seconds.
        ///     - cpuSeconds: Total user and system CPU time spent in seconds.
        ///     - maxFileDescriptors: Maximum number of open file descriptors.
        ///     - openFileDescriptors: Number of open file descriptors.
        ///     - cpuUsage: Total CPU usage percentage.
        public init(
            virtualMemoryBytes: Int,
            residentMemoryBytes: Int,
            startTimeSeconds: Int,
            cpuSeconds: Int,
            maxFileDescriptors: Int,
            openFileDescriptors: Int,
            cpuUsage: Double
        ) {
            self.virtualMemoryBytes = virtualMemoryBytes
            self.residentMemoryBytes = residentMemoryBytes
            self.startTimeSeconds = startTimeSeconds
            self.cpuSeconds = cpuSeconds
            self.maxFileDescriptors = maxFileDescriptors
            self.openFileDescriptors = openFileDescriptors
            self.cpuUsage = cpuUsage
        }
    }
}
