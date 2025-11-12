# ``SystemMetrics``

Collect and report process-level system metrics for the applications.

## Overview

The SystemMetrics module automatically collects key process metrics and reports them through the Swift Metrics API.

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
import SystemMetricsMonitor
```

Create and start a monitor with default settings:

```swift
let labels = SystemMetricsMonitor.Labels(
    prefix: "process_",
    virtualMemoryBytes: "virtual_memory_bytes",
    residentMemoryBytes: "resident_memory_bytes",
    startTimeSeconds: "start_time_seconds",
    cpuSecondsTotal: "cpu_seconds_total",
    cpuUsage: "cpu_usage",
    maxFds: "max_fds",
    openFds: "open_fds"
)

let configuration = SystemMetricsMonitor.Configuration(
    pollInterval: .seconds(2),
    labels: labels
)

let monitor = SystemMetricsMonitor(configuration: configuration)

// Start collecting metrics
try await monitor.run()
```

The monitor will collect and report metrics every 2 seconds using the global `MetricsSystem`.

## Configuration

### Labels

Customize metric labels to namespace the metrics:

```swift
let labels = SystemMetricsMonitor.Labels(
    prefix: "app_",
    virtualMemoryBytes: "virt_mem",
    residentMemoryBytes: "res_mem",
    startTimeSeconds: "start_ts",
    cpuSecondsTotal: "cpu_total",
    cpuUsage: "cpu_pct",
    maxFds: "fds_max",
    openFds: "fds_open"
)
```

### Dimensions

Add dimensions to all metrics for filtering and aggregation:

```swift
let configuration = SystemMetricsMonitor.Configuration(
    pollInterval: .seconds(2),
    labels: labels,
    dimensions: [
        ("service", "api-server"),
        ("environment", "production"),
        ("instance", "api-1")
    ]
)
```

## Metrics Backend Integration

Metrics backend implementations are encouraged to provide static extensions for common configurations:

```swift
public extension SystemMetricsMonitor.Configuration {
    /// Prometheus-style metric configuration
    static let prometheus = SystemMetricsMonitor.Configuration(
        pollInterval: .seconds(2),
        labels: .init(
            prefix: "process_",
            virtualMemoryBytes: "virtual_memory_bytes",
            residentMemoryBytes: "resident_memory_bytes",
            startTimeSeconds: "start_time_seconds",
            cpuSecondsTotal: "cpu_seconds_total",
            cpuUsage: "cpu_usage",
            maxFds: "max_fds",
            openFds: "open_fds"
        )
    )
}
```

This enables users to configure the monitor with minimal boilerplate:

```swift
let monitor = SystemMetricsMonitor(configuration: .prometheus, metricsFactory: myPrometheusMetricsFactory)
try await monitor.run()
```

## Swift Service Lifecycle Integration

[swift-service-lifecycle](https://github.com/swift-server/swift-service-lifecycle) provides a convinient way of managing background service tasks, which is compatible with the `SystemMetricsMonitor`:

```swift
import SystemMetricsMonitor
import ServiceLifecycle
import UnixSignals
import Metrics

extension SystemMetricsMonitor: Service {
    // SystemMetricsMonitor already conforms to the Service protocol
}

@main
struct Application {
    static let logger = Logger(label: "Application")
    static let metrics = MyMetricsBackendImplementation()
    
    static func main() async throws {
        MetricsSystem.bootstrap(metrics)

        let service = FooService()
        let systemMetricsMonitor = SystemMetricsMonitor(configuration: .prometheus)
        
        let serviceGroup = ServiceGroup(
            services: [service, systemMetricsMonitor],
            gracefulShutdownSignals: [.sigterm],
            logger: logger
        )
        
        try await serviceGroup.run()
    }
}
```
