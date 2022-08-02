// swift-tools-version:5.5
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
        .library(name: "SystemMetrics", targets: ["SystemMetrics"]),
        .library(name: "MetricsTestUtils", targets: ["MetricsTestUtils"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.3.2"),
    ],
    targets: [
        .target(
            name: "SystemMetrics",
            dependencies: [
                .product(name: "CoreMetrics", package: "swift-metrics"),
            ]
        ),
        .target(
            name: "MetricsTestUtils",
            dependencies: [
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "CoreMetrics", package: "swift-metrics"),
            ]
        ),
        .testTarget(
            name: "SystemMetricsTests",
            dependencies: [
                "SystemMetrics",
            ]
        ),
    ]
)
