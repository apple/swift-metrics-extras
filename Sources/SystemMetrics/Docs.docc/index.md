# ``SystemMetrics``

Collect and report process-level system metrics for the applications.

## Overview

The ``SystemMetricsMonitor`` automatically collects key process metrics and reports them through the Swift Metrics API.

### Available Metrics

The following metrics are collected:

- **Virtual Memory**: Total virtual memory allocated by the process (in bytes)
- **Resident Memory**: Physical memory currently used by the process (in bytes)
- **Start Time**: Process start time since Unix epoch (in seconds)
- **CPU Time**: Cumulative CPU time consumed (in seconds)
- **CPU Usage**: Current CPU usage percentage
- **Max File Descriptors**: Maximum number of file descriptors the process can open
- **Open File Descriptors**: Number of file descriptors currently open

> Note: These metrics are currently implemented on Linux platforms only.

## Getting Started

### Basic Usage

After adding `swift-metrics-extras` as a dependency, import the `SystemMetricsMonitor` module:

```swift
import SystemMetrics
```

Create and start a monitor with default settings and a logger:

```swift
// Import and create a logger, or use one of the existing loggers
import Logging
let logger = Logger(label: "MyService")

// Create the monitor
let monitor = SystemMetricsMonitor(logger: logger)

// Start collecting metrics
try await monitor.run()
```

The monitor will collect and report metrics periodically using the global `MetricsSystem`.

## Configuration

Polling interval can be configured through the ``SystemMetricsMonitor.Configuration``:

```swift
```

## Using custom Metrics Factory

``SystemMetricsMonitor`` can be initialized with a specific metrics factory, so it does not rely on the global `MetricsSystem`:

```swift
let monitor = SystemMetricsMonitor(metricsFactory: myPrometheusMetricsFactory, logger: logger)
try await monitor.run()
```

## Swift Service Lifecycle Integration

[swift-service-lifecycle](https://github.com/swift-server/swift-service-lifecycle) provides a convenient way to manage background service tasks, which is compatible with the `SystemMetricsMonitor`:

```swift
import SystemMetrics
import ServiceLifecycle
import UnixSignals
import Metrics

@main
struct Application {
    static let logger = Logger(label: "Application")
    static let metrics = MyMetricsBackendImplementation()

    static func main() async throws {
        MetricsSystem.bootstrap(metrics)

        let service = FooService()
        let systemMetricsMonitor = SystemMetricsMonitor(logger: logger)

        let serviceGroup = ServiceGroup(
            services: [service, systemMetricsMonitor],
            gracefulShutdownSignals: [.sigint],
            cancellationSignals: [.sigterm],
            logger: logger
        )

        try await serviceGroup.run()
    }
}
```
