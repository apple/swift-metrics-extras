# SwiftMetricsExtras

Extra packages complementing the core [SwiftMetrics](https://github.com/apple/swift-metrics) API.

Almost all production server software needs to emit metrics information for observability. Because it's unlikely that all parties can agree on one specific metrics backend implementation, this API is designed to establish a standard that can be implemented by various metrics libraries which then post the metrics data to backends like [Prometheus](https://prometheus.io/), [Graphite](https://graphiteapp.org), publish over [statsd](https://github.com/statsd/statsd), write to disk, etc.

This is the beginning of a community-driven open-source project actively seeking contributions, be it code, documentation, or ideas. Apart from contributing to SwiftMetrics itself, we need metrics compatible libraries which send the metrics over to backend such as the ones mentioned above. What SwiftMetrics provides today is covered in the [API docs](https://apple.github.io/swift-metrics/), but it will continue to evolve with community input.

## What makes a good contribution to Metrics Extras?

Not good: 

- Most metrics contributions depend or implement some specific metrics backend–such implementations should have their own repository and are not good candidates for this repository.

Good: 

- However, if you have some useful metrics helpers, such as e.g. gathering cloud provider specific metrics independent of actual metrics backend which they would be emitted to,
or other such metric system agnostic metrics additions–such additions are perfect examples of contributions very welcome to this package. 

### Adding the dependency

To add a dependency on the extras package, you need to declare it in your `Package.swift`:

```swift
.package(url: "https://github.com/apple/swift-metrics-metrics.git", "1.0.0" ..< "3.0.0"),
```

and to your application/library target, add the specific module you would like to depend on to your dependencies:

```swift
.target(name: "BestExampleApp", dependencies: ["ExampleExtraMetrics"]),
```

## Modules

Swift Metrics Extras ships the following extra modules:

- [System Metrics](Sources/SystemMetrics)
- ...

### System Metrics

The System Metrics package provides default process metrics for applications. The following metrics are exposed:

- Virtual memory in Bytes.
- Resident memory in Bytes.
- Application start time in Seconds.
- Total CPU seconds.
- Maximum number of file descriptors.
- Number of file descriptors currently in use.

***NOTE:*** Currently these metrics are only implemented on Linux platforms, and not on Darwin or Windows.

#### Using System Metrics

After [adding swift-metrics-extras as a dependency](#adding-the-dependency) you can import the `SystemMetrics` module.

```swift
import SystemMetrics
```

This makes the System Metrics API available. This adds a new method to `MetricsSystem` called `bootstrapWithSystemMetrics`. Calling this method will call `MetricsSystem.bootstrap` as well as bootstrapping System Metrics.

`bootstrapWithSystemMetrics` takes a `SystemMetrics.Configuration` object to configure the system metrics. The config has the following properties:

- interval: The interval at which SystemMetrics are being calculated & exported.
- dataProvider: A closure returing `SystemMetrics.Data?`. When `nil` no metrics are exported (the default on non-linux platforms). `SystemMetrics.Data` holds all the values mentioned above.
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