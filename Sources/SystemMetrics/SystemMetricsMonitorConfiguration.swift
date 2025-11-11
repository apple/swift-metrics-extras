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

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension SystemMetricsMonitor {
    /// Labels for the reported System Metrics Data.
    ///
    /// Backend implementations are encouraged to provide a static extension with
    /// defaults that suit their specific backend needs.
    public struct Labels: Sendable {
        /// Prefix to prefix all other labels with.
        let prefix: String
        /// Virtual memory size in bytes.
        let virtualMemoryBytes: String
        /// Resident memory size in bytes.
        let residentMemoryBytes: String
        /// Total user and system CPU time spent in seconds.
        let startTimeSeconds: String
        /// Total user and system CPU time spent in seconds.
        let cpuSecondsTotal: String
        /// Maximum number of open file descriptors.
        let maxFileDescriptors: String
        /// Number of open file descriptors.
        let openFileDescriptors: String
        /// CPU usage percentage.
        let cpuUsage: String

        /// Create a new `Labels` instance.
        ///
        /// - parameters:
        ///     - prefix: Prefix to prefix all other labels with.
        ///     - virtualMemoryBytes: Virtual memory size in bytes
        ///     - residentMemoryBytes: Resident memory size in bytes.
        ///     - startTimeSeconds: Total user and system CPU time spent in seconds.
        ///     - cpuSecondsTotal: Total user and system CPU time spent in seconds.
        ///     - maxFds: Maximum number of open file descriptors.
        ///     - openFds: Number of open file descriptors.
        ///     - cpuUsage: Total CPU usage percentage.
        public init(
            prefix: String,
            virtualMemoryBytes: String,
            residentMemoryBytes: String,
            startTimeSeconds: String,
            cpuSecondsTotal: String,
            maxFds: String,
            openFds: String,
            cpuUsage: String
        ) {
            self.prefix = prefix
            self.virtualMemoryBytes = virtualMemoryBytes
            self.residentMemoryBytes = residentMemoryBytes
            self.startTimeSeconds = startTimeSeconds
            self.cpuSecondsTotal = cpuSecondsTotal
            self.maxFileDescriptors = maxFds
            self.openFileDescriptors = openFds
            self.cpuUsage = cpuUsage
        }

        func label(for keyPath: KeyPath<Labels, String>) -> String {
            self.prefix + self[keyPath: keyPath]
        }
    }
    
    public struct Configuration: Sendable {
        let interval: Duration
        let labels: SystemMetricsMonitor.Labels
        let dimensions: [(String, String)]

        /// Create new instance of `SystemMetricsOptions`
        ///
        /// - parameters:
        ///     - interval: The interval at which system metrics should be updated.
        ///     - labels: The labels to use for generated system metrics.
        ///     - dimensions: The dimensions to include in generated system metrics.
        public init(
            pollInterval interval: Duration = .seconds(2),
            labels: Labels,
            dimensions: [(String, String)] = []
        ) {
            self.interval = interval
            self.labels = labels
            self.dimensions = dimensions
        }
    }
}
