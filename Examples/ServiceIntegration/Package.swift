// swift-tools-version:6.0
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

import PackageDescription

let package = Package(
    name: "ServiceIntegrationExample",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .watchOS(.v9),
        .tvOS(.v16),
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.3.2"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-otel/swift-otel", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "ServiceIntegrationExample",
            dependencies: [
                .product(name: "SystemMetrics", package: "swift-metrics-extras"),
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "MetricsTestKit", package: "swift-metrics"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "UnixSignals", package: "swift-service-lifecycle"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "OTel", package: "swift-otel"),
            ],
            path: "Sources"
        )
    ]
)
