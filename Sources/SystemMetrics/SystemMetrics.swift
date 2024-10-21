//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2018-2023 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import CoreMetrics
import Dispatch

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif


extension MetricsSystem {
    fileprivate static var systemMetricsProvider: SystemMetricsProvider?

    /// `bootstrapWithSystemMetrics` is an one-time configuration function which globally selects the desired metrics backend
    /// implementation, and enables system level metrics. `bootstrapWithSystemMetrics` can be called at maximum once in any given program,
    /// calling it more than once will lead to undefined behaviour, most likely a crash.
    ///
    /// - parameters:
    ///     - factory: A factory that given an identifier produces instances of metrics handlers such as `CounterHandler`, `RecorderHandler` and `TimerHandler`.
    ///     - config: Used to configure `SystemMetrics`.
    public static func bootstrapWithSystemMetrics(_ factory: MetricsFactory, config: SystemMetrics.Configuration) {
        self.bootstrap(factory)
        self.bootstrapSystemMetrics(config)
    }

    /// `bootstrapSystemMetrics` is an one-time configuration function which globally enables system level metrics.
    /// `bootstrapSystemMetrics` can be called at maximum once in any given program, calling it more than once will lead to
    /// undefined behaviour, most likely a crash.
    ///
    /// - parameters:
    ///     - config: Used to configure `SystemMetrics`.
    public static func bootstrapSystemMetrics(_ config: SystemMetrics.Configuration) {
        self.withWriterLock {
            precondition(self.systemMetricsProvider == nil, "System metrics already bootstrapped.")
            self.systemMetricsProvider = SystemMetricsProvider(config: config)
        }
    }

    internal class SystemMetricsProvider {
        fileprivate let queue = DispatchQueue(label: "com.apple.CoreMetrics.SystemMetricsHandler", qos: .background)
        fileprivate let timeInterval: DispatchTimeInterval
        fileprivate let dataProvider: SystemMetrics.DataProvider
        fileprivate let labels: SystemMetrics.Labels
        fileprivate let dimensions: [(String, String)]
        fileprivate let timer: DispatchSourceTimer

        init(config: SystemMetrics.Configuration) {
            self.timeInterval = config.interval
            self.dataProvider = config.dataProvider
            self.labels = config.labels
            self.dimensions = config.dimensions
            self.timer = DispatchSource.makeTimerSource(queue: self.queue)

            self.timer.setEventHandler(handler: DispatchWorkItem(block: { [weak self] in
                guard let self = self, let metrics = self.dataProvider() else { return }
                Gauge(label: self.labels.label(for: \.virtualMemoryBytes), dimensions: self.dimensions).record(metrics.virtualMemoryBytes)
                Gauge(label: self.labels.label(for: \.residentMemoryBytes), dimensions: self.dimensions).record(metrics.residentMemoryBytes)
                Gauge(label: self.labels.label(for: \.startTimeSeconds), dimensions: self.dimensions).record(metrics.startTimeSeconds)
                Gauge(label: self.labels.label(for: \.cpuSecondsTotal), dimensions: self.dimensions).record(metrics.cpuSeconds)
                Gauge(label: self.labels.label(for: \.maxFileDescriptors), dimensions: self.dimensions).record(metrics.maxFileDescriptors)
                Gauge(label: self.labels.label(for: \.openFileDescriptors), dimensions: self.dimensions).record(metrics.openFileDescriptors)
                Gauge(label: self.labels.label(for: \.cpuUsage), dimensions: self.dimensions).record(metrics.cpuUsage)
            }))

            self.timer.schedule(deadline: .now() + self.timeInterval, repeating: self.timeInterval)

            if #available(OSX 10.12, *) {
                self.timer.activate()
            } else {
                self.timer.resume()
            }
        }

        deinit {
            self.timer.cancel()
        }
    }
}

public enum SystemMetrics {
    /// Provider used by `SystemMetrics` to get the requested `SystemMetrics.Data`.
    ///
    /// Defaults are currently only provided for linux. (`SystemMetrics.linuxSystemMetrics`)
    public typealias DataProvider = () -> SystemMetrics.Data?

    /// Configuration used to bootstrap `SystemMetrics`.
    ///
    /// Backend implementations are encouraged to extend `SystemMetrics.Configuration` with a static extension with
    /// defaults that suit their specific backend needs.
    public struct Configuration {
        let interval: DispatchTimeInterval
        let dataProvider: SystemMetrics.DataProvider
        let labels: SystemMetrics.Labels
        let dimensions: [(String, String)]

        /// Create new instance of `SystemMetricsOptions`
        ///
        /// - parameters:
        ///     - pollInterval: The interval at which system metrics should be updated.
        ///     - dataProvider: The provider to get SystemMetrics data from. If none is provided this defaults to
        ///                     `SystemMetrics.linuxSystemMetrics` on Linux platforms and `SystemMetrics.noopSystemMetrics`
        ///                     on all other platforms.
        ///     - labels: The labels to use for generated system metrics.
        public init(pollInterval interval: DispatchTimeInterval = .seconds(2), dataProvider: SystemMetrics.DataProvider? = nil, labels: Labels, dimensions: [(String, String)] = []) {
            self.interval = interval
            if let dataProvider = dataProvider {
                self.dataProvider = dataProvider
            } else {
                #if os(Linux)
                self.dataProvider = SystemMetrics.linuxSystemMetrics
                #else
                self.dataProvider = SystemMetrics.noopSystemMetrics
                #endif
            }
            self.labels = labels
            self.dimensions = dimensions
        }
    }

    /// Labels for the reported System Metrics Data.
    ///
    /// Backend implementations are encouraged to provide a static extension with
    /// defaults that suit their specific backend needs.
    public struct Labels {
        /// Prefix to prefix all other labels with.
        let prefix: String
        /// Virtual memory size in bytes.
        let virtualMemoryBytes: String
        /// Resident memory size in bytes.
        let residentMemoryBytes: String
        /// Total user and system CPU time spent in seconds.
        let startTimeSeconds: String
        /// Total user and system CPU time spent in seconds.
        let cpuSecondsTotal: String
        /// Maximum number of open file descriptors.
        let maxFileDescriptors: String
        /// Number of open file descriptors.
        let openFileDescriptors: String
        /// CPU usage percentage.
        let cpuUsage: String

        /// Create a new `Labels` instance.
        ///
        /// - parameters:
        ///     - prefix: Prefix to prefix all other labels with.
        ///     - virtualMemoryBytes: Virtual memory size in bytes
        ///     - residentMemoryBytes: Resident memory size in bytes.
        ///     - startTimeSeconds: Total user and system CPU time spent in seconds.
        ///     - cpuSecondsTotal: Total user and system CPU time spent in seconds.
        ///     - maxFds: Maximum number of open file descriptors.
        ///     - openFds: Number of open file descriptors.
        ///     - cpuUsage: Total CPU usage percentage.
        public init(
            prefix: String,
            virtualMemoryBytes: String,
            residentMemoryBytes: String,
            startTimeSeconds: String,
            cpuSecondsTotal: String,
            maxFds: String,
            openFds: String,
            cpuUsage: String
        ) {
            self.prefix = prefix
            self.virtualMemoryBytes = virtualMemoryBytes
            self.residentMemoryBytes = residentMemoryBytes
            self.startTimeSeconds = startTimeSeconds
            self.cpuSecondsTotal = cpuSecondsTotal
            self.maxFileDescriptors = maxFds
            self.openFileDescriptors = openFds
            self.cpuUsage = cpuUsage
        }

        func label(for keyPath: KeyPath<Labels, String>) -> String {
            return self.prefix + self[keyPath: keyPath]
        }
    }

    /// System Metric data.
    ///
    /// The current list of metrics exposed is a superset of the Prometheus Client Library Guidelines:
    /// https://prometheus.io/docs/instrumenting/writing_clientlibs/#standard-and-runtime-collectors
    public struct Data {
        /// Virtual memory size in bytes.
        var virtualMemoryBytes: Int
        /// Resident memory size in bytes.
        var residentMemoryBytes: Int
        /// Start time of the process since unix epoch in seconds.
        var startTimeSeconds: Int
        /// Total user and system CPU time spent in seconds.
        var cpuSeconds: Int
        /// Maximum number of open file descriptors.
        var maxFileDescriptors: Int
        /// Number of open file descriptors.
        var openFileDescriptors: Int
        /// CPU usage percentage.
        var cpuUsage: Double
    }

    #if os(Linux)
    /// Minimal file reading implementation so we don't have to depend on Foundation.
    /// Designed only for the narrow use case of this library.
    final class CFile {
        let path: String

        private var file: UnsafeMutablePointer<FILE>?

        init(_ path: String) {
            self.path = path
        }

        deinit {
            assert(self.file == nil)
        }

        func open() {
            guard let f = fopen(path, "r") else {
                return
            }
            self.file = f
        }

        func close() {
            if let f = self.file {
                self.file = nil
                let success = fclose(f) == 0
                assert(success)
            }
        }

        func readLine() -> String? {
            guard let f = self.file else {
                return nil
            }
            var buff = [CChar](repeating: 0, count: 1024)
            let hasNewLine = buff.withUnsafeMutableBufferPointer { ptr -> Bool in
                guard fgets(ptr.baseAddress, Int32(ptr.count), f) != nil else {
                    if feof(f) != 0 {
                        return false
                    } else {
                        preconditionFailure("Error reading line")
                    }
                }
                return true
            }
            if !hasNewLine {
                return nil
            }
            return String(cString: buff)
        }

        func readFull() -> String {
            var s = ""
            func loop() -> String {
                if let l = readLine() {
                    s += l
                    return loop()
                }
                return s
            }
            return loop()
        }
    }

    /// A type that can calculate CPU usage for a given process.
    ///
    /// CPU usage is calculated as the number of CPU ticks used by this process between measurements.
    /// - Note: the first measurement will be calculated since the process' start time, since there's no
    /// previous measurement to take as reference.
    internal struct CPUUsageCalculator {
        /// The number of ticks after system boot that the last CPU usage stat was taken.
        private var previousTicksSinceSystemBoot: Int = 0
        /// The number of ticks the process actively used the CPU for, as of the previous CPU usage measurement.
        private var previousCPUTicks: Int = 0

        mutating func getUsagePercentage(ticksSinceSystemBoot: Int, cpuTicks: Int) -> Double {
            defer {
                self.previousTicksSinceSystemBoot = ticksSinceSystemBoot
                self.previousCPUTicks = cpuTicks
            }
            let ticksBetweenMeasurements = ticksSinceSystemBoot - self.previousTicksSinceSystemBoot
            guard ticksBetweenMeasurements > 0 else {
                return 0
            }

            let cpuTicksBetweenMeasurements = cpuTicks - self.previousCPUTicks
            return Double(cpuTicksBetweenMeasurements) * 100 / Double(ticksBetweenMeasurements)
        }
    }

    private static let systemStartTimeInSecondsSinceEpoch: Int? = {
        let systemStatFile = CFile("/proc/stat")
        systemStatFile.open()
        defer {
            systemStatFile.close()
        }
        while let line = systemStatFile.readLine() {
            if line.starts(with: "btime"),
               let systemUptimeInSecondsSinceEpochString = line
               .split(separator: " ")
               .last?
               .split(separator: "\n")
               .first,
               let systemUptimeInSecondsSinceEpoch = Int(systemUptimeInSecondsSinceEpochString)
            {
                return systemUptimeInSecondsSinceEpoch
            }
        }
        return nil
    }()

    private static var cpuUsageCalculator = CPUUsageCalculator()

    internal static func linuxSystemMetrics() -> SystemMetrics.Data? {
        enum StatIndices {
            static let virtualMemoryBytes = 20
            static let residentMemoryBytes = 21
            static let startTimeTicks = 19
            static let utimeTicks = 11
            static let stimeTicks = 12
        }

        let ticks = Int(_SC_CLK_TCK)

        let statFile = CFile("/proc/self/stat")
        statFile.open()
        defer {
            statFile.close()
        }

        let uptimeFile = CFile("/proc/uptime")
        uptimeFile.open()
        defer {
            uptimeFile.close()
        }

        // Read both files as close as possible to each other to get an accurate CPU usage metric.
        let statFileContents = statFile.readFull()
        let uptimeFileContents = uptimeFile.readFull()

        guard
            let statString = statFileContents
            .split(separator: ")")
            .last
        else { return nil }
        let stats = String(statString)
            .split(separator: " ")
            .map(String.init)
        guard
            let virtualMemoryBytes = Int(stats[safe: StatIndices.virtualMemoryBytes]),
            let rss = Int(stats[safe: StatIndices.residentMemoryBytes]),
            let startTimeTicks = Int(stats[safe: StatIndices.startTimeTicks]),
            let utimeTicks = Int(stats[safe: StatIndices.utimeTicks]),
            let stimeTicks = Int(stats[safe: StatIndices.stimeTicks])
        else { return nil }
        let residentMemoryBytes = rss * Int(_SC_PAGESIZE)
        let processStartTimeInSeconds = startTimeTicks / ticks
        let cpuTicks = utimeTicks + stimeTicks
        let cpuSeconds = cpuTicks / ticks

        guard let systemStartTimeInSecondsSinceEpoch = SystemMetrics.systemStartTimeInSecondsSinceEpoch else {
            return nil
        }
        let startTimeInSecondsSinceEpoch = systemStartTimeInSecondsSinceEpoch + processStartTimeInSeconds

        var cpuUsage: Double = 0
        if cpuTicks > 0 {
            guard let uptimeString = uptimeFileContents.split(separator: " ").first,
                  let uptimeSeconds = Float(uptimeString),
                  uptimeSeconds.isFinite
            else { return nil }
            let uptimeTicks = Int(ceilf(uptimeSeconds)) * ticks
            cpuUsage = SystemMetrics.cpuUsageCalculator.getUsagePercentage(ticksSinceSystemBoot: uptimeTicks, cpuTicks: cpuTicks)
        }

        var _rlim = rlimit()
        guard withUnsafeMutablePointer(to: &_rlim, { ptr in
            #if canImport(Musl)
            getrlimit(RLIMIT_NOFILE, ptr) == 0
            #else
            getrlimit(__rlimit_resource_t(RLIMIT_NOFILE.rawValue), ptr) == 0
            #endif
        }) else { return nil }

        let maxFileDescriptors = Int(_rlim.rlim_max)

        guard let dir = opendir("/proc/self/fd") else { return nil }
        defer {
            closedir(dir)
        }
        var openFileDescriptors = 0
        while readdir(dir) != nil { openFileDescriptors += 1 }

        return .init(
            virtualMemoryBytes: virtualMemoryBytes,
            residentMemoryBytes: residentMemoryBytes,
            startTimeSeconds: startTimeInSecondsSinceEpoch,
            cpuSeconds: cpuSeconds,
            maxFileDescriptors: maxFileDescriptors,
            openFileDescriptors: openFileDescriptors,
            cpuUsage: cpuUsage
        )
    }

    #else
    #warning("System Metrics are not implemented on non-Linux platforms yet.")
    #endif

    internal static func noopSystemMetrics() -> SystemMetrics.Data? {
        return nil
    }
}

extension Array where Element == String {
    fileprivate subscript(safe index: Int) -> String {
        guard index >= 0, index < endIndex else {
            return ""
        }

        return self[index]
    }
}
