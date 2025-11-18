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

import Logging
import Metrics
import MetricsTestKit
import ServiceLifecycle
import SystemMetricsMonitor
import UnixSignals

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension SystemMetricsMonitor: Service {
    // SystemMetricsMonitor already conforms to the Service protocol
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct FooService: Service {
    func run() async throws {
        print("FooService starting")
        try await Task.sleep(for: .seconds(30))
        print("FooService done")
    }
}

@main
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct Application {
    static let logger = Logger(label: "Application")

    static func main() async throws {
        // Bootstrap with some custom metrics backend
        let testMetrics = TestMetrics()
        MetricsSystem.bootstrap(testMetrics)

        let service = FooService()
        let systemMetricsMonitor = SystemMetricsMonitor(configuration: .prometheus)
        let anotherSystemMetricsMonitor = SystemMetricsMonitor(configuration: .prometheus, metricsFactory: testMetrics)

        let serviceGroup = ServiceGroup(
            services: [service, systemMetricsMonitor, anotherSystemMetricsMonitor],
            gracefulShutdownSignals: [.sigterm],
            logger: logger
        )

        try await serviceGroup.run()
    }
}
