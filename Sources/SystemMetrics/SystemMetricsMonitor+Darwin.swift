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

#if canImport(Darwin)
extension SystemMetricsMonitorDataProvider: SystemMetricsProvider {
    /// Collect current system metrics data on macOS.
    ///
    /// - Note: System metrics collection is not yet implemented for macOS.
    ///         This method always returns `nil`.
    /// - Returns: `nil` until macOS support is implemented.
    package func data() async -> SystemMetricsMonitor.Data? {
        #warning("System Metrics are not implemented on non-Linux platforms yet.")
        return nil
    }
}
#endif
