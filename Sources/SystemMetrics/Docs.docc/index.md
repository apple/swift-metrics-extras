# ``SystemMetrics``

Collect and report process-level system metrics in your application.

## Overview

``SystemMetricsMonitor`` automatically collects key process metrics and reports them through the Swift Metrics API.

### Available metrics

The following metrics are collected:

- **Virtual Memory**: Total virtual memory allocated by the process (in bytes), reported as `process_virtual_memory_bytes`.
- **Resident Memory**: Physical memory currently used by the process (in bytes), reported as `process_resident_memory_bytes`.
- **Start Time**: Process start time since Unix epoch (in seconds), reported as `process_start_time_seconds`.
- **CPU Time**: Cumulative CPU time consumed (in seconds), reported as `process_cpu_seconds_total`.
- **Max File Descriptors**: Maximum number of file descriptors the process can open, reported as `process_max_fds`.
- **Open File Descriptors**: Number of file descriptors currently open, reported as `process_open_fds`.

> Note: These metrics are currently implemented on Linux platforms only.

## Getting started

### Basic usage

After adding `swift-metrics-extras` as a dependency, import the `SystemMetrics` module:

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

The monitor will collect and report metrics periodically using the global `MetricsSystem`.

## Configuration

Polling interval can be configured through the ``SystemMetricsMonitor/Configuration``:

```swift
let systemMetricsMonitor = SystemMetricsMonitor(
    configuration: .init(pollInterval: .seconds(5)),
    logger: logger
)
```

## Using custom Metrics Factory

``SystemMetricsMonitor`` can be initialized with a specific metrics factory, so it does not rely on the global `MetricsSystem`:

```swift
let monitor = SystemMetricsMonitor(metricsFactory: myPrometheusMetricsFactory, logger: logger)
```

## Swift Service Lifecycle integration

[Swift Service Lifecycle](https://github.com/swift-server/swift-service-lifecycle) provides a convenient way to manage background service tasks, which is compatible with the `SystemMetricsMonitor`:

```swift
import SystemMetrics
import ServiceLifecycle
import UnixSignals
import Metrics

@main
struct Application {
    static func main() async throws {
        let logger = Logger(label: "Application")
        let metrics = MyMetricsBackendImplementation()
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
