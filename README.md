# SwiftMetricsExtras

Additional metrics utilities complementing the core [SwiftMetrics](https://github.com/apple/swift-metrics) API.

## SystemMetricsMonitor

Automatically collects and reports process-level system metrics (memory, CPU, file descriptors).

### Quick Start

```swift
import SystemMetrics

let configuration = SystemMetricsMonitor.Configuration(
    pollInterval: .seconds(2),
    labels: .init(
        prefix: "process_",
        virtualMemoryBytes: "virtual_memory_bytes",
        residentMemoryBytes: "resident_memory_bytes",
        startTimeSeconds: "start_time_seconds",
        cpuSecondsTotal: "cpu_seconds_total",
        maxFds: "max_fds",
        openFds: "open_fds",
        cpuUsage: "cpu_usage"
    )
)

let monitor = SystemMetricsMonitor(configuration: configuration)
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

Then add SystemMetrics to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "SystemMetrics", package: "swift-metrics-extras")
    ]
)
```
