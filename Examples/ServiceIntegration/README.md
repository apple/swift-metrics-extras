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

## Running the Example

From the `swift-metrics-extras` package root run:

```bash
docker-compose -f Examples/ServiceIntegration/docker-compose.yaml up --build
```

This will build and run 2 containers: `grafana` and `systemmetricsmonitor`.

## Grafana Dashboard

This example includes a preconfigured Grafana dashboard for the collected metrics.
Once the example is running, access Grafana at http://localhost:3000 and navigate to the "Process System Metrics" dashboard.
The dashboard provides four visualizations that map to the metrics collected by ``SystemMetricsMonitor``:

1. Service Uptime Timeline based on the reported `process_start_time_seconds`.

1. CPU Usage % calculated as `rate(process_cpu_seconds_total)`.

1. Residential Memory (`process_resident_memory_bytes`) and Virtual Memory (`process_virtual_memory_bytes`) consumption.

1. Open File Descriptors (`process_open_fds`) and Max File Descriptors (`process_max_fds`)
