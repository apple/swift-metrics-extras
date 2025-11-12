# ``SystemMetrics``

The System Metrics module provides default process metrics for applications.

## Overview

The following metrics are exposed:

- Virtual memory in Bytes.
- Resident memory in Bytes.
- Application start time in Seconds.
- Total CPU seconds.
- Maximum number of file descriptors.
- Number of file descriptors currently in use.

> Note: Currently these metrics are only implemented on Linux platforms, and not on Darwin or Windows.

## Using System Metrics

After adding `swift-metrics-extras` as a dependency you can import the `SystemMetrics` module.

```swift
import SystemMetrics
```

This makes the `SystemMetricsMonitor` object available. It can be constructed with a `SystemMetricsMonitor.Configuration` object to configure the system metrics. The config has the following properties:

- interval: The interval at which `SystemMetricsMonitor` collects system metrics and exports them via the `MetricsSubsystem`.
- labels: `SystemMetricsMonitor.Labels` hold a string label for each of the above mentioned metrics that will be used for the metric labels, along with a prefix that will be used for all above mentioned metrics.
- dimensions: Extra dimension labels attached to each metric.

`SystemMetricsMonitor` can also be initialized with an optional `MetricsFactory`. If not provided a global factory from `MetricsSubsystem` will be used.

Swift Metrics backend implementations are encouraged to provide static extensions to `SystemMetricsMonitor.Configuration` that fit the requirements of their specific backends. For example:
```swift
public extension SystemMetricsMonitor.Configuration {
    /// `SystemMetricsMonitor.Configuration` with Prometheus style labels.
    ///
    /// For more information see `SystemMetricsMonitor.Configuration`
    static let prometheus = SystemMetricsMonitor.Configuration(
        labels: .init(
            prefix: "process_",
            virtualMemoryBytes: "virtual_memory_bytes",
            residentMemoryBytes: "resident_memory_bytes",
            startTimeSeconds: "start_time_seconds",
            cpuSecondsTotal: "cpu_seconds_total",
            maxFds: "max_fds",
            openFds: "open_fds"
        )
    )
}
```

This allows end users to setup System Metrics Monitor like this:

```swift
let systemMetricsMonitor = SystemMetricsMonitor(configuration: .prometheus, metricsFactory: myPrometheusMetricsFactory)
```

## Topics

### Contributing

- <doc:Proposals>
