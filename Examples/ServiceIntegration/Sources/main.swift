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
import SystemMetrics
import UnixSignals

struct FooService: Service {
    let logger: Logger

    func run() async throws {
        self.logger.notice("FooService starting")
        try await Task.sleep(for: .seconds(30))
        self.logger.notice("FooService done")
    }
}

@main
struct Application {
    static func main() async throws {
        var logger = Logger(label: "Application")

        // Let's see some logs from the SystemMetricsMonitor
        // while the FooService is running
        logger.logLevel = .trace

        // Bootstrap with some custom metrics backend
        let testMetrics = TestMetrics()
        MetricsSystem.bootstrap(testMetrics)

        let service = FooService(logger: logger)
        let systemMetricsMonitor = SystemMetricsMonitor(
            configuration: .init(pollInterval: .seconds(5)),
            logger: logger
        )

        let serviceGroup = ServiceGroup(
            services: [service, systemMetricsMonitor],
            gracefulShutdownSignals: [.sigint],
            cancellationSignals: [.sigterm],
            logger: logger
        )

        try await serviceGroup.run()
    }
}
