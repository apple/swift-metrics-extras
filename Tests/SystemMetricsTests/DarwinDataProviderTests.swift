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
import Foundation
import Testing

import SystemMetrics

@Suite("Darwin Data Provider Tests")
struct DarwinDataProviderTests {
    @Test("Data provider returns nil on macOS (not yet implemented)")
    func dataProviderReturnsNil() async throws {
        let labels = SystemMetricsMonitor.Labels(
            prefix: "test_",
            virtualMemoryBytes: "vmb",
            residentMemoryBytes: "rmb",
            startTimeSeconds: "sts",
            cpuSecondsTotal: "cpt",
            maxFds: "mfd",
            openFds: "ofd",
            cpuUsage: "cpu"
        )
        let configuration = SystemMetricsMonitor.Configuration(
            pollInterval: .seconds(1),
            labels: labels
        )

        let provider = SystemMetricsMonitorDataProvider(configuration: configuration)
        let data = await provider.data()

        // Currently returns nil because macOS implementation is not yet available
        #expect(data == nil)
    }
}
#endif
