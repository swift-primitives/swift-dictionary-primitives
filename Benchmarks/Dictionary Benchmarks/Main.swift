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

/// Family-tier benchmark for swift-dictionary-primitives (arc-bench W2).
///
/// MEASUREMENT DISCIPLINE: `rm -rf .build`, build `-c release`, run the
/// binary directly; never `swift test` (the W1-ratified instrument).
@main
enum Main {
    static func main() {
        print("=== swift-dictionary-primitives — family-tier benchmark (W2) ===")
        print("config: sizes=\(Bench.sizes) curveSizes=\(Bench.curveSizes) samples=\(Bench.samples) warmup=\(Bench.warmup)")
        print("targets/sample: element=\(Bench.elementOpsTarget) structure=\(Bench.structureOpsTarget) copiedSlots=\(Bench.copiedSlotsTarget)")
        print("subjects: tower.direct=Dictionary<Hash.Indexed<…>> (flat) · tower.cow=Dictionary<Shared<Entry,…>> (flat) · stdlib=Swift.Dictionary (UNORDERED baseline)")
        print("churn: one op = one remove+insert pair (flat); wipe rows measure the FIXED removeAll Shared door (c51d879)")
        print("")
        Bench.globalWarmup()

        var results: [Bench.Result] = []
        let groupResults = Bench.dictionaryCases()
        for result in groupResults {
            print(result.record)
        }
        results.append(contentsOf: groupResults)

        print("")
        print(summaryTable(results))
        Bench.flushSink()
    }

    /// Aligned median (cv%) table; raw vectors live in the BENCH lines above.
    static func summaryTable(_ results: [Bench.Result]) -> String {
        let subjects = ["tower.direct", "tower.cow", "stdlib"]
        var rowKeys: [String] = []
        var cells: [String: [String: String]] = [:]
        for r in results {
            let key = "\(r.name) n=\(r.n)"
            if cells[key] == nil {
                rowKeys.append(key)
                cells[key] = [:]
            }
            cells[key]![r.subject] = "\(Bench.fixed(r.median, 2)) (\(Bench.fixed(r.cvPercent, 1))%)"
        }

        let nameWidth = rowKeys.map(\.count).max() ?? 0
        let columnWidth = 22
        var lines: [String] = []
        lines.append(pad("shape", nameWidth) + subjects.map { pad($0, columnWidth) }.joined())
        lines.append(String(repeating: "-", count: nameWidth + columnWidth * subjects.count))
        for key in rowKeys {
            let row = subjects.map { pad(cells[key]?[$0] ?? "-", columnWidth) }.joined()
            lines.append(pad(key, nameWidth) + row)
        }
        lines.append("")
        lines.append("unit: ns/op, median across \(Bench.samples) samples (cv%); per-op = batch / opsPerBatch")
        lines.append("evict rows: one op = one remove+insert pair at the row's n")
        return lines.joined(separator: "\n")
    }

    static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text + " " : text + String(repeating: " ", count: width - text.count)
    }
}
