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
import Foundation
import CoreMetrics

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct SystemMetricsMonitor {
    let configuration: SystemMetricsMonitor.Configuration
    let metricsFactory: MetricsFactory?
    
    init(configuration: SystemMetricsMonitor.Configuration, metricsFactory: MetricsFactory) {
        self.configuration = configuration
        self.metricsFactory = metricsFactory
    }

    init(configuration: SystemMetricsMonitor.Configuration) {
        self.configuration = configuration
        self.metricsFactory = nil
    }
    
    package func updateMetrics() async throws {
        guard let metrics = self.collectMetricsData() else { return }
        let effectiveMetricsFactory = self.metricsFactory ?? MetricsSystem.factory
        Gauge(label: self.configuration.labels.label(for: \.virtualMemoryBytes), dimensions: self.configuration.dimensions, factory: effectiveMetricsFactory).record(
            metrics.virtualMemoryBytes
        )
        Gauge(label: self.configuration.labels.label(for: \.residentMemoryBytes), dimensions: self.configuration.dimensions, factory: effectiveMetricsFactory).record(
            metrics.residentMemoryBytes
        )
        Gauge(label: self.configuration.labels.label(for: \.startTimeSeconds), dimensions: self.configuration.dimensions, factory: effectiveMetricsFactory).record(
            metrics.startTimeSeconds
        )
        Gauge(label: self.configuration.labels.label(for: \.cpuSecondsTotal), dimensions: self.configuration.dimensions, factory: effectiveMetricsFactory).record(
            metrics.cpuSeconds
        )
        Gauge(label: self.configuration.labels.label(for: \.maxFileDescriptors), dimensions: self.configuration.dimensions, factory: effectiveMetricsFactory).record(
            metrics.maxFileDescriptors
        )
        Gauge(label: self.configuration.labels.label(for: \.openFileDescriptors), dimensions: self.configuration.dimensions, factory: effectiveMetricsFactory).record(
            metrics.openFileDescriptors
        )
        Gauge(label: self.configuration.labels.label(for: \.cpuUsage), dimensions: self.configuration.dimensions, factory: effectiveMetricsFactory).record(
            metrics.cpuUsage
        )
    }
    
    func run() async throws {
        for await _ in AsyncTimerSequence(interval: self.configuration.interval, clock: .continuous) {
            try await self.updateMetrics()
        }
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
    }
}
