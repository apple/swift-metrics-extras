// swift-tools-version:5.3
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
        .testTarget(
            name: "SystemMetricsTests",
            dependencies: [
                "SystemMetrics",
            ]
        ),
    ]
)
