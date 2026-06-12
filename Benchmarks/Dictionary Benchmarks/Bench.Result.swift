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

extension Bench {
    /// One measured case: a shape × subject × scale with its full sample vector.
    struct Result {
        /// Shape identifier, e.g. `append.zero`.
        let name: Swift.String
        /// Measured subject: `tower.direct`, `tower.cow`, or `stdlib`.
        let subject: Swift.String
        /// Element scale of the case.
        let n: Swift.Int
        /// Operations folded into each timed batch (the per-op divisor).
        let opsPerBatch: Swift.Int
        /// Per-operation nanoseconds, one entry per timed sample.
        let perOpNs: [Swift.Double]
    }
}

extension Bench.Result {
    /// Sorted copy of the sample vector.
    private var sorted: [Swift.Double] { perOpNs.sorted() }

    /// Median per-op nanoseconds across samples.
    var median: Swift.Double {
        let s = sorted
        let mid = s.count / 2
        return s.count % 2 == 0 ? (s[mid - 1] + s[mid]) / 2 : s[mid]
    }

    /// Fastest sample.
    var min: Swift.Double { sorted.first ?? 0 }

    /// Slowest sample.
    var max: Swift.Double { sorted.last ?? 0 }

    /// Coefficient of variation across samples, in percent.
    var cvPercent: Swift.Double {
        let mean = perOpNs.reduce(0, +) / Swift.Double(perOpNs.count)
        guard mean > 0 else { return 0 }
        let variance = perOpNs.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Swift.Double(perOpNs.count)
        return (variance.squareRoot() / mean) * 100
    }

    /// Machine-parseable record line (one per case; raw logs feed the report).
    var record: Swift.String {
        let samplesList = perOpNs.map { Bench.fixed($0, 3) }.joined(separator: ",")
        return #"BENCH {"name":"\#(name)","subject":"\#(subject)","n":\#(n),"opsPerBatch":\#(opsPerBatch),"median_ns_per_op":\#(Bench.fixed(median, 3)),"min":\#(Bench.fixed(min, 3)),"max":\#(Bench.fixed(max, 3)),"cv_pct":\#(Bench.fixed(cvPercent, 1)),"samples":[\#(samplesList)]}"#
    }
}
