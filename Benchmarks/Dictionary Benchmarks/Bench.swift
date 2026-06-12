// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// REPLICATED measurement core — canonical source: swift-array-primitives/
// Benchmarks/Array Benchmarks (the W1-proven harness shape, seat-ratified).
// Keep edits synchronized; the W3 baselines doc records the shared method.

import Synchronization

/// Measurement core for the family-tier benchmarks (arc-bench W1, the R4-probe
/// shape generalized): release-only executable, `ContinuousClock` batch timing,
/// opaque sinks against constant folding, per-op nanoseconds with the full
/// sample vector reported so variance is never hidden behind a single number.
enum Bench {

    // MARK: - Configuration

    /// Element scales: small / mid / large (skill guidance; trees used 10k–50k).
    static let sizes: [Int] = [16, 1_024, 65_536]

    /// Timed samples per case (median = 5th of 9).
    static let samples = 9

    /// Untimed warmup batches before sampling.
    static let warmup = 2

    /// Per-element shapes: total element operations targeted per sample.
    static let elementOpsTarget = 1 << 21

    /// Span bulk shapes run at memset-class speed (~0.07 ns/elem), so they
    /// need a larger target to keep every sample above the ~0.5 ms floor
    /// (the W1 run-1 lesson: 2M-op samples were ~150 µs and DVFS-noisy).
    static let spanOpsTarget = 1 << 24

    /// Whole-structure shapes (build / drain): total slots targeted per sample.
    static let structureOpsTarget = 1 << 18

    /// Detach / clone shapes: total copied slots targeted per sample.
    static let copiedSlotsTarget = 1 << 22

    // MARK: - Optimizer barriers

    /// Accumulated sink state; printed at exit so no measured work is dead.
    /// `Mutex` keeps the barrier safe-construct-only; `sink` runs once per
    /// batch (never inside a measured loop body), so the lock cost is noise.
    private static let drain = Mutex<Int>(0)

    /// Opaque sink: keeps `x` (and everything feeding it) observable.
    @inline(never)
    static func sink(_ x: Int) {
        drain.withLock { $0 = $0 &+ x }
    }

    /// Opaque source: hides `x` from constant propagation into measured loops.
    @inline(never)
    static func opaque(_ x: Int) -> Int {
        x
    }

    /// Prints the accumulated sink so the optimizer cannot prove it unobserved.
    static func flushSink() {
        print("sink: \(drain.withLock { $0 })")
    }

    // MARK: - Formatting (Foundation-free fixed-decimal rendering)

    /// Renders `value` with `decimals` fraction digits (no Foundation).
    static func fixed(_ value: Double, _ decimals: Int) -> String {
        var scale = 1.0
        for _ in 0..<decimals { scale *= 10 }
        let scaled = (value * scale).rounded()
        guard scaled.isFinite else { return "\(value)" }
        let negative = scaled < 0
        let units = Int(scaled.magnitude)
        let whole = units / Int(scale)
        let fraction = units % Int(scale)
        var fractionText = "\(fraction)"
        while fractionText.count < decimals {
            fractionText = "0" + fractionText
        }
        let sign = negative ? "-" : ""
        return decimals == 0 ? "\(sign)\(whole)" : "\(sign)\(whole).\(fractionText)"
    }

    // MARK: - Sampling

    /// Burns ~100 ms of real array work before the first case so the first
    /// measured batch does not absorb process ramp-up (W1 run-1 lesson: the
    /// binary's first case read ~14% hot-to-cold spread across runs).
    static func globalWarmup() {
        let clock = ContinuousClock()
        let start = clock.now
        var acc = 0
        while clock.now - start < .milliseconds(100) {
            var warm: [Int] = []
            for i in 0..<4_096 { warm.append(i) }
            acc &+= warm[opaque(0)]
        }
        sink(acc)
    }

    /// Runs `batch` untimed `warmup` times, then `samples` timed batches.
    /// Returns per-op nanoseconds, one entry per sample. The closure is
    /// non-escaping by design: move-only state may live in the caller's frame.
    static func sample(opsPerBatch: Int, _ batch: () -> Void) -> [Double] {
        for _ in 0..<warmup {
            batch()
        }
        let clock = ContinuousClock()
        var perOp: [Double] = []
        perOp.reserveCapacity(samples)
        for _ in 0..<samples {
            let elapsed = clock.measure(batch)
            perOp.append((elapsed / .nanoseconds(1)) / Double(opsPerBatch))
        }
        return perOp
    }
}
