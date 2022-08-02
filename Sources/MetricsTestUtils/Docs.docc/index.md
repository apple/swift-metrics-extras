# ``MetricsTestUtils``

The MetricsTestUtils module provides a metrics backend that can be used to test metrics emitted by your application.

## Overview

This module allows for writing assertions on existing metrics objects. 
First, import the module in your XCTest (or other test runner):

```swift
import XCTest
import Metrics
import MetricsTestUtils
```

Then bootstrap the metrics system in your test using the `bootstrapInternal` method which allows overriding existing bootstraps:

```swift
final class SWIMNIOMetricsTests: XCTestCase {
    var testMetrics: TestMetrics!

    override func setUp() {
        super.setUp()

        self.testMetrics = TestMetrics()
        MetricsSystem.bootstrapInternal(self.testMetrics)
    }

    override func tearDown() {
        super.tearDown()
        
        self.testMetrics.clear()
        MetricsSystem.bootstrapInternal(NOOPMetricsHandler.instance)
    }
}
```

After the test completes, remember to bootstrap with a `Metrics/NOOPMetricsHandler` again.

### Asserting on metrics

Next, you'll be able to run some code-under-test as usual, and then assert against metrics it has emitted like this:

```swift
func test_example() throws {
    let lib = SomeLibrary()
    lib.doThings()
    lib.causeMetrics()
    
    // Unwrap a Timer into a `TestTimer`
    let roundTripTime = try! self.testMetrics.expectTimer(lib.metrics.someTimer)
    
    // Write assertions against the TestTimer
    XCTAssertNotNil(roundTripTime.lastValue) // some roundtrip time should have been reported
    for rtt in roundTripTime.values {
        print("  ping rtt recorded: \(TimeAmount.nanoseconds(rtt).prettyDescription)")
    }
}
```

The ``TestMetrics`` factory allows unwrapping any metrics type (`Timer`, `Counter`, etc), 
into an equivalent ``TestTimer``, ``TestCounter``, ``TestRecorder``.

Once such test metric has been obtained, you can inspect any metrics that were reported into it.
Most types offer a useful `lastValue` as well as a sequence of `values` which represents all 
metric values reported into this metrics object.

## Topics

### Bootstrapping

- ``TestMetrics``

### Test Metrics

- ``TestCounter``
- ``TestTimer``
- ``TestRecorder``
