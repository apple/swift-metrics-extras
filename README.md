# Swift System Metrics

Automatically collects process-level system metrics (memory, CPU, file descriptors) and reports them through the [SwiftMetrics](https://github.com/apple/swift-metrics) API.

### Quick start

```swift
import Logging
import SystemMetrics

// Create a logger, or use one of the existing loggers
let logger = Logger(lable: "MyLogger")

// Create the monitor
let monitor = SystemMetricsMonitor(logger: logger)

// Create the service
let serviceGroup = ServiceGroup(
    services: [monitor],
    gracefulShutdownSignals: [.sigint],
    cancellationSignals: [.sigterm],
    logger: logger
)

// Start collecting metrics
try await serviceGroup.run()
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
