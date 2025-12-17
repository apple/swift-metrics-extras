# Swift System Metrics

Automatically collects process-level system metrics (memory, CPU, file descriptors) and reports them through the [SwiftMetrics](https://github.com/apple/swift-metrics) API.

## Collected Metrics

The following metrics are collected and reported as gauges:

- **Virtual Memory** (`process_virtual_memory_bytes`) - Virtual memory size in bytes
- **Resident Memory** (`process_resident_memory_bytes`) - Resident Set Size (RSS) in bytes
- **CPU Time** (`process_cpu_seconds_total`) - Total user and system CPU time spent in seconds
- **Process Start Time** (`process_start_time_seconds`) - Process start time since Unix epoch in seconds
- **Open File Descriptors** (`process_open_fds`) - Current number of open file descriptors
- **Max File Descriptors** (`process_max_fds`) - Maximum number of open file descriptors allowed

## Quick start

```swift
import Logging
import SystemMetrics

// Create a logger, or use one of the existing loggers
let logger = Logger(label: "MyLogger")

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

See the [SystemMetrics documentation](https://swiftpackageindex.com/apple/swift-metrics-extras/documentation/systemmetrics) for details.

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

## Example & Grafana Dashboard

A complete working example with a pre-built Grafana dashboard is available in [Examples/ServiceIntegration](Examples/ServiceIntegration). The example includes:

- `SwiftServiceLifecycle` integration.
- `SwiftMetrics` configured to export the metrics.
- Docker Compose setup with Grafana container.
- A provisioned Grafana dashboard visualizing all the collected metrics.
