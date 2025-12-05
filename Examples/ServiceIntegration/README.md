# Service Integration Example

This example demonstrates how to integrate `SystemMetricsMonitor` with `swift-service-lifecycle` to automatically collect and report system metrics for your service.

## Overview

The example shows:
- How to use `SystemMetricsMonitor` as a `Service` within a `ServiceGroup`
- How to integrate it with the global `MetricsSystem` using `MetricsSystem.bootstrap()`

## Alternative Usage

Instead of using the global `MetricsSystem.bootstrap()`, you can inject a custom `MetricsFactory` directly:

```swift
let customMetrics = MyMetricsBackendImplementation()
let systemMetricsMonitor = SystemMetricsMonitor(
    metricsFactory: customMetrics,
    logger: logger
)
```

This approach decouples the monitor from global state and allows you to use different metrics backends for different components.
