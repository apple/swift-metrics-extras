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
.package(url: "https://github.com/apple/swift-metrics-extras.git", from: "0.1.0"),
```

and to your application/library target, add the specific module you would like to depend on to your dependencies:

```swift
.target(name: "BestExampleApp", dependencies: ["ExampleExtraMetrics"]),
```

## Modules

Swift Metrics Extras ships the following extra modules:

- [System Metrics](Sources/SystemMetrics)
- [MetricsTestUtils](Sources/MetricsTestUtils)
