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
import Logging
import Metrics
import MetricsTestKit
import OTel
import ServiceLifecycle
import SystemMetrics
import UnixSignals

struct FooService: Service {
    let logger: Logger

    func run() async throws {
        self.logger.notice("FooService starting")
        for await _ in AsyncTimerSequence(interval: .seconds(0.01), clock: .continuous)
            .cancelOnGracefulShutdown()
        {
            let j = 42
            for i in 0...1000 {
                let k = i * j
                self.logger.trace("FooService is still running", metadata: ["k": "\(k)"])
            }
        }
        self.logger.notice("FooService done")
    }
}

@main
struct Application {
    static func main() async throws {
        let logger = Logger(label: "Application")

        // Bootstrap with some custom metrics backend
        var otelConfig = OTel.Configuration.default
        otelConfig.logs.enabled = false
        otelConfig.serviceName = "ServiceIntegrationExample"
        let otelService = try OTel.bootstrap(configuration: otelConfig)

        // Create a service simulating some important work
        let service = FooService(logger: logger)
        let systemMetricsMonitor = SystemMetricsMonitor(
            configuration: .init(pollInterval: .seconds(5)),
            logger: logger
        )

        let serviceGroup = ServiceGroup(
            services: [service, systemMetricsMonitor, otelService],
            gracefulShutdownSignals: [.sigint],
            cancellationSignals: [.sigterm],
            logger: logger
        )

        try await serviceGroup.run()
    }
}
