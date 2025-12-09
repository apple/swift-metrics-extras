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

extension SystemMetricsMonitor {
    /// This object controls the behaviour of the ``SystemMetricsMonitor``.
    public struct Configuration: Sendable {
        /// Default SystemMetricsMonitor configuration.
        ///
        /// See individual property documentation for specific default values.
        public static let `default`: Self = .init()

        /// Interval between system metrics data scrapping
        public var interval: Duration

        /// String labels associated with the metrics
        package let labels: SystemMetricsMonitor.Configuration.Labels

        /// Additional dimensions attached to every metric
        package let dimensions: [(String, String)]

        /// Create new instance of ``Configuration``
        ///
        /// - Parameters:
        ///     - interval: The interval at which system metrics should be updated.
        public init(
            pollInterval interval: Duration = .seconds(2)
        ) {
            self.interval = interval
            self.labels = .init()
            self.dimensions = []
        }

        /// Create new instance of ``SystemMetricsMonitor.Configuration``
        ///
        /// - Parameters:
        ///     - interval: The interval at which system metrics should be updated.
        ///     - labels: The labels to use for generated system metrics.
        ///     - dimensions: The dimensions to include in generated system metrics.
        package init(
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

extension SystemMetricsMonitor.Configuration {
    /// Labels for the reported System Metrics Data.
    ///
    /// Backend implementations are encouraged to provide a static extension with
    /// defaults that suit their specific backend needs.
    package struct Labels: Sendable {
        /// Prefix to prefix all other labels with.
        package var prefix: String = "process_"
        /// Label for virtual memory size in bytes.
        package var virtualMemoryBytes: String = "virtual_memory_bytes"
        /// Label for resident memory size in bytes.
        package var residentMemoryBytes: String = "resident_memory_bytes"
        /// Label for total user and system CPU time spent in seconds.
        package var startTimeSeconds: String = "start_time_seconds"
        /// Label for total user and system CPU time spent in seconds.
        package var cpuSecondsTotal: String = "cpu_seconds_total"
        /// Label for maximum number of open file descriptors.
        package var maxFileDescriptors: String = "max_fds"
        /// Label for number of open file descriptors.
        package var openFileDescriptors: String = "open_fds"

        /// Construct a label for a metric as a concatenation of prefix and the corresponding label.
        ///
        /// - Parameters:
        ///     - for: a property to construct the label for
        package func label(for keyPath: KeyPath<Labels, String>) -> String {
            self.prefix + self[keyPath: keyPath]
        }

        /// Create a new `Labels` instance with default values.
        ///
        package init() {
        }

        /// Create a new `Labels` instance.
        ///
        /// - Parameters:
        ///     - prefix: Prefix to prefix all other labels with.
        ///     - virtualMemoryBytes: Lable for virtual memory size in bytes
        ///     - residentMemoryBytes: Lable for resident memory size in bytes.
        ///     - startTimeSeconds: Lable for total user and system CPU time spent in seconds.
        ///     - cpuSecondsTotal: Lable for total user and system CPU time spent in seconds.
        ///     - maxFileDescriptors: Lable for maximum number of open file descriptors.
        ///     - openFileDescriptors: Lable for number of open file descriptors.
        package init(
            prefix: String,
            virtualMemoryBytes: String,
            residentMemoryBytes: String,
            startTimeSeconds: String,
            cpuSecondsTotal: String,
            maxFileDescriptors: String,
            openFileDescriptors: String
        ) {
            self.prefix = prefix
            self.virtualMemoryBytes = virtualMemoryBytes
            self.residentMemoryBytes = residentMemoryBytes
            self.startTimeSeconds = startTimeSeconds
            self.cpuSecondsTotal = cpuSecondsTotal
            self.maxFileDescriptors = maxFileDescriptors
            self.openFileDescriptors = openFileDescriptors
        }
    }
}
