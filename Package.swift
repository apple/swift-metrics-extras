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
        .testTarget(
            name: "SystemMetricsTests",
            dependencies: [
                "SystemMetrics",
                .product(name: "MetricsTestKit", package: "swift-metrics"),
            ]
        ),
    ]
)

for target in package.targets
where [.executable, .test, .regular].contains(
    target.type
) {
var settings = target.swiftSettings ?? []

        // https://www.swift.org/documentation/concurrency
        settings.append(.enableUpcomingFeature("StrictConcurrency"))

        // https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md
        // Require `any` for existential types.
        settings.append(.enableUpcomingFeature("ExistentialAny"))

        // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
        settings.append(.enableUpcomingFeature("MemberImportVisibility"))

        // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md
        settings.append(.enableUpcomingFeature("InternalImportsByDefault"))
        target.swiftSettings = settings
}
