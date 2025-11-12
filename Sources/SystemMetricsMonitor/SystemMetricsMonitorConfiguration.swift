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
        package let prefix: String
        /// Virtual memory size in bytes.
        package let virtualMemoryBytes: String
        /// Resident memory size in bytes.
        package let residentMemoryBytes: String
        /// Total user and system CPU time spent in seconds.
        package let startTimeSeconds: String
        /// Total user and system CPU time spent in seconds.
        package let cpuSecondsTotal: String
        /// CPU usage percentage.
        package let cpuUsage: String
        /// Maximum number of open file descriptors.
        package let maxFileDescriptors: String
        /// Number of open file descriptors.
        package let openFileDescriptors: String

        /// Create a new `Labels` instance.
        ///
        /// - parameters:
        ///     - prefix: Prefix to prefix all other labels with.
        ///     - virtualMemoryBytes: Virtual memory size in bytes
        ///     - residentMemoryBytes: Resident memory size in bytes.
        ///     - startTimeSeconds: Total user and system CPU time spent in seconds.
        ///     - cpuSecondsTotal: Total user and system CPU time spent in seconds.
        ///     - cpuUsage: Total CPU usage percentage.
        ///     - maxFds: Maximum number of open file descriptors.
        ///     - openFds: Number of open file descriptors.
        public init(
            prefix: String,
            virtualMemoryBytes: String,
            residentMemoryBytes: String,
            startTimeSeconds: String,
            cpuSecondsTotal: String,
            cpuUsage: String,
            maxFds: String,
            openFds: String
        ) {
            self.prefix = prefix
            self.virtualMemoryBytes = virtualMemoryBytes
            self.residentMemoryBytes = residentMemoryBytes
            self.startTimeSeconds = startTimeSeconds
            self.cpuSecondsTotal = cpuSecondsTotal
            self.cpuUsage = cpuUsage
            self.maxFileDescriptors = maxFds
            self.openFileDescriptors = openFds
        }

        package func label(for keyPath: KeyPath<Labels, String>) -> String {
            self.prefix + self[keyPath: keyPath]
        }
    }

    public struct Configuration: Sendable {
        package let interval: Duration
        package let labels: SystemMetricsMonitor.Labels
        package let dimensions: [(String, String)]

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
