// swift-tools-version:6.0
//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the Swift Metrics API project authors
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
    name: "swift-metrics-extras",
    products: [
        .library(name: "SystemMetrics", targets: ["SystemMetrics"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.3.2"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "SystemMetrics",
            dependencies: [
                .product(name: "CoreMetrics", package: "swift-metrics"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ]
        ),
        .executableTarget(
            name: "ServiceIntegrationExample",
            dependencies: [
                "SystemMetrics",
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "MetricsTestKit", package: "swift-metrics"),
            ]
        ),
        .testTarget(
            name: "SystemMetricsTests",
            dependencies: [
                "SystemMetrics",
                .product(name: "MetricsTestKit", package: "swift-metrics"),
            ]
        ),
    ]
)

for target in package.targets {
    var settings = target.swiftSettings ?? []
    settings.append(.enableExperimentalFeature("StrictConcurrency=complete"))
    target.swiftSettings = settings
}

// ---    STANDARD CROSS-REPO SETTINGS DO NOT EDIT   --- //
for target in package.targets {
    switch target.type {
    case .regular, .test, .executable:
        var settings = target.swiftSettings ?? []
        // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
        settings.append(.enableUpcomingFeature("MemberImportVisibility"))
        target.swiftSettings = settings
    case .macro, .plugin, .system, .binary:
        ()  // not applicable
    @unknown default:
        ()  // we don't know what to do here, do nothing
    }
}
// --- END: STANDARD CROSS-REPO SETTINGS DO NOT EDIT --- //
