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

This makes the System Metrics API available. This adds a new method to `MetricsSystem` called `bootstrapWithSystemMetrics`. Calling this method will call `MetricsSystem.bootstrap` as well as bootstrapping System Metrics.

`bootstrapWithSystemMetrics` takes a `SystemMetrics.Configuration` object to configure the system metrics. The config has the following properties:

- interval: The interval at which `SystemMetrics` are being calculated & exported.
- dataProvider: A closure returning `SystemMetrics.Data?`. When `nil`, no metrics are exported (the default on non-Linux platforms). `SystemMetrics.Data` holds all the values mentioned above.
- labels: `SystemMetrics.Labels` hold a string label for each of the above mentioned metrics that will be used for the metric labels, along with a prefix that will be used for all above mentioned metrics.

Swift Metrics backend implementations are encouraged to provide static extensions to `SystemMetrics.Configuration` that fit the requirements of their specific backends. For example:
```swift
public extension SystemMetrics.Configuration {
    /// `SystemMetrics.Configuration` with Prometheus style labels.
    ///
    /// For more information see `SystemMetrics.Configuration`
    static let prometheus = SystemMetrics.Configuration(
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

This allows end users to add System Metrics like this:

```swift
MetricsSystem.bootstrapWithSystemMetrics(myPrometheusInstance, config: .prometheus)
```
