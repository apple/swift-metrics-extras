# System Metrics Monitor

Automatically collects process-level system metrics (memory, CPU, file descriptors) and reports them through the [SwiftMetrics](https://github.com/apple/swift-metrics) API.

### Quick Start

```swift
import Logging
import SystemMetrics

let logger = Logger(lable: "MyLogger")
let monitor = SystemMetricsMonitor(logger: logger)
try await monitor.run()
```

See the [SystemMetrics documentation](Sources/SystemMetrics/Docs.docc/index.md) for details.

## Installation

Add SwiftMetricsExtras as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-metrics-extras.git", from: "1.0.0")
]
```

Then add ``SystemMetrics`` to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "SystemMetrics", package: "swift-metrics-extras")
    ]
)
```
