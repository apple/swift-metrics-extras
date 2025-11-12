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
extension SystemMetricsMonitor.Configuration {
    /// Prometheus-style metric configuration
    public static let prometheus = SystemMetricsMonitor.Configuration(
        pollInterval: .seconds(2),
        labels: .init(
            prefix: "process_",
            virtualMemoryBytes: "virtual_memory_bytes",
            residentMemoryBytes: "resident_memory_bytes",
            startTimeSeconds: "start_time_seconds",
            cpuSecondsTotal: "cpu_seconds_total",
            cpuUsage: "cpu_usage",
            maxFds: "max_fds",
            openFds: "open_fds"
        )
    )
}
