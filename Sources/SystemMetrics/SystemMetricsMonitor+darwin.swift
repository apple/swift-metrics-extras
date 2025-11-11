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

#if os(macOS)
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension SystemMetricsMonitor {
    /// Collect current system metrics data on macOS.
    func collectMetricsData() -> SystemMetricsMonitor.Data? {
#warning("System Metrics are not implemented on non-Linux platforms yet.")
        return nil
    }
}
#endif
