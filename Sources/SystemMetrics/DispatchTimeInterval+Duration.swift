//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2018-2025 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Dispatch

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension DispatchTimeInterval {
    var asDuration: Duration {
        switch self {
        case .seconds(let value):
            .seconds(value)
        case .milliseconds(let value):
            .milliseconds(value)
        case .microseconds(let value):
            .microseconds(value)
        case .nanoseconds(let value):
            .nanoseconds(value)
        case .never:
            .seconds(.infinity)
        @unknown default:
            .seconds(2)
        }
    }
}
