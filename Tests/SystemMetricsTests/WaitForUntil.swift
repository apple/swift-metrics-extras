//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2018-2020 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation

struct TimeoutError: Error {}
struct OperationFinishedPrematurelyError: Error {}

func wait(
    noLongerThan duration: Duration,
    for condition: @escaping @Sendable () async throws -> Bool,
    `while` operation: @escaping @Sendable () async throws -> Void
) async throws -> Bool {
    try await withThrowingTaskGroup(of: Bool.self) { group in
        // Start the operation
        group.addTask {
            try await operation()
            throw OperationFinishedPrematurelyError()
        }

        // Add timeout
        group.addTask {
            try await Task.sleep(for: duration)
            throw TimeoutError()
        }

        // Keep monitoring the condition
        group.addTask {
            var conditionResult = try await condition()
            while !conditionResult {
                try await Task.sleep(for: .seconds(0.5))
                conditionResult = try await condition()
            }
            return conditionResult
        }

        // Who is the first — timeout, condition or faulty operation?
        let conditionMet = try await group.next()
        group.cancelAll()
        if let conditionMet = conditionMet {
            return conditionMet
        }
        return false
    }
}
