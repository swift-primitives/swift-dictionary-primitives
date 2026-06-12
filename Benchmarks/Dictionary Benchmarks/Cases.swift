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

import Dictionary_Primitives
import Dictionary_Primitive
import Column_Primitives
import Hash_Primitives
import Hash_Primitives_Standard_Library_Integration
import Hash_Indexed_Primitive
import Buffer_Primitive
import Buffer_Linear_Primitive
import Storage_Contiguous_Primitives
import Memory_Heap_Primitives
import Memory_Allocator_Primitive
import Shared_Primitive
import Index_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Ordinal_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Cardinal_Primitives

// The ratified columns, spelled as the package's own test suite spells them.

typealias EntryColumn<K: Hash.Key & ~Copyable, V: ~Copyable> =
    Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>

typealias MoveDict<K: Hash.Key & ~Copyable, V: ~Copyable> = Dictionary<EntryColumn<K, V>>

typealias CoWDict<K: Hash.Key, V> = Dictionary<Shared<Hash.Entry<K, V>, EntryColumn<K, V>>>

extension Bench {
    /// The order-preserving remove curve uses denser scales (see set-ordered).
    static let curveSizes: [Int] = [16, 256, 4_096, 65_536]

    /// Typed count from a runtime size via the non-throwing `UInt` lane.
    static func count<E>(_ n: Int) -> Index_Primitives.Index<E>.Count {
        Index_Primitives.Index<E>.Count(Cardinal(UInt(n)))
    }

    /// Shapes per the inventory (vs `Swift.Dictionary`, the unordered
    /// baseline), mirroring the set-ordered matrix at entry granularity:
    /// `insert.zero` build · `lookup.hit`/`lookup.miss` via `withValue(forKey:)`
    /// vs stdlib subscript · `frontEvict.steady`/`backEvict.steady` (one op =
    /// one removeValue+insert pair; front pays the order-preserving shift) ·
    /// `iterate.sum` over values in insertion order vs stdlib's bucket scan.
    static func dictionaryCases() -> [Result] {
        var results: [Result] = []

        for n in sizes {
            let reps = Swift.max(1, structureOpsTarget / n)
            let buildOps = reps * n
            let seed = opaque(0)

            results.append(Result(
                name: "insert.zero", subject: "tower.direct", n: n, opsPerBatch: buildOps,
                perOpNs: sample(opsPerBatch: buildOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var d = MoveDict<Int, Int>(minimumCapacity: .zero)
                        for i in 0..<n { _ = d.insert(key: i &+ seed, value: i) }
                        acc &+= d.withValue(forKey: seed) { $0 } ?? 0
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "insert.zero", subject: "tower.cow", n: n, opsPerBatch: buildOps,
                perOpNs: sample(opsPerBatch: buildOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var d = CoWDict<Int, Int>(minimumCapacity: .zero)
                        for i in 0..<n { _ = d.insert(key: i &+ seed, value: i) }
                        acc &+= d.withValue(forKey: seed) { $0 } ?? 0
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "insert.zero", subject: "stdlib", n: n, opsPerBatch: buildOps,
                perOpNs: sample(opsPerBatch: buildOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var d = Swift.Dictionary<Int, Int>()
                        for i in 0..<n { d[i &+ seed] = i }
                        acc &+= d[seed] ?? 0
                    }
                    sink(acc)
                }
            ))

            // Lookup setup: keys 0..<n → value = key; hits 0..<n, misses n..<2n.
            let passes = Swift.max(1, (elementOpsTarget / 4) / n)
            let lookupOps = passes * n

            var d = MoveDict<Int, Int>(minimumCapacity: count(n))
            for i in 0..<n { _ = d.insert(key: i, value: i) }
            var c = CoWDict<Int, Int>(minimumCapacity: count(n))
            for i in 0..<n { _ = c.insert(key: i, value: i) }
            var sd = Swift.Dictionary<Int, Int>(minimumCapacity: n)
            for i in 0..<n { sd[i] = i }

            for (label, lo) in [("lookup.hit", 0), ("lookup.miss", n)] {
                results.append(Result(
                    name: label, subject: "tower.direct", n: n, opsPerBatch: lookupOps,
                    perOpNs: sample(opsPerBatch: lookupOps) {
                        var sum = 0
                        for _ in 0..<passes {
                            for k in lo..<(lo + n) { sum &+= d.withValue(forKey: k) { $0 } ?? 0 }
                        }
                        sink(sum)
                    }
                ))

                results.append(Result(
                    name: label, subject: "tower.cow", n: n, opsPerBatch: lookupOps,
                    perOpNs: sample(opsPerBatch: lookupOps) {
                        var sum = 0
                        for _ in 0..<passes {
                            for k in lo..<(lo + n) { sum &+= c.withValue(forKey: k) { $0 } ?? 0 }
                        }
                        sink(sum)
                    }
                ))

                results.append(Result(
                    name: label, subject: "stdlib", n: n, opsPerBatch: lookupOps,
                    perOpNs: sample(opsPerBatch: lookupOps) {
                        var sum = 0
                        for _ in 0..<passes {
                            for k in lo..<(lo + n) { sum &+= sd[k] ?? 0 }
                        }
                        sink(sum)
                    }
                ))
            }

            let iterOps = passes * n

            results.append(Result(
                name: "iterate.sum", subject: "tower.direct", n: n, opsPerBatch: iterOps,
                perOpNs: sample(opsPerBatch: iterOps) {
                    var sum = 0
                    for _ in 0..<passes {
                        d.forEach { _, value in sum &+= value }
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "iterate.sum", subject: "tower.cow", n: n, opsPerBatch: iterOps,
                perOpNs: sample(opsPerBatch: iterOps) {
                    var sum = 0
                    for _ in 0..<passes {
                        c.forEach { _, value in sum &+= value }
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "iterate.sum", subject: "stdlib", n: n, opsPerBatch: iterOps,
                perOpNs: sample(opsPerBatch: iterOps) {
                    var sum = 0
                    for _ in 0..<passes {
                        for (_, value) in sd { sum &+= value }
                    }
                    sink(sum)
                }
            ))
        }

        // Flat churn (single rolling row; same Hash.Indexed combinator => the
        // B-7 sweep applies here too) + the wipe rows over the FIXED removeAll
        // Shared door (the c51d879 grant note: the wipe-class rows measure the
        // fixed door — the correct baseline).
        for n in curveSizes {
            let pairs = Swift.max(16, copiedSlotsTarget / n)

            var d = MoveDict<Int, Int>(minimumCapacity: count(n))
            for i in 0..<n { _ = d.insert(key: i, value: i) }
            var low = 0
            var high = n

            results.append(Result(
                name: "churn.steady", subject: "tower.direct", n: n, opsPerBatch: pairs,
                perOpNs: sample(opsPerBatch: pairs) {
                    var acc = 0
                    for _ in 0..<pairs {
                        acc &+= d.removeValue(forKey: low) ?? 0
                        _ = d.insert(key: high, value: high)
                        low &+= 1
                        high &+= 1
                    }
                    sink(acc)
                }
            ))

            var c = CoWDict<Int, Int>(minimumCapacity: count(n))
            for i in 0..<n { _ = c.insert(key: i, value: i) }
            var clow = 0
            var chigh = n

            results.append(Result(
                name: "churn.steady", subject: "tower.cow", n: n, opsPerBatch: pairs,
                perOpNs: sample(opsPerBatch: pairs) {
                    var acc = 0
                    for _ in 0..<pairs {
                        acc &+= c.removeValue(forKey: clow) ?? 0
                        _ = c.insert(key: chigh, value: chigh)
                        clow &+= 1
                        chigh &+= 1
                    }
                    sink(acc)
                }
            ))

            var sd = Swift.Dictionary<Int, Int>(minimumCapacity: n)
            for i in 0..<n { sd[i] = i }
            var slow = 0
            var shigh = n
            let stdPairs = 1 << 15

            results.append(Result(
                name: "churn.steady", subject: "stdlib", n: n, opsPerBatch: stdPairs,
                perOpNs: sample(opsPerBatch: stdPairs) {
                    var acc = 0
                    for _ in 0..<stdPairs {
                        acc &+= sd.removeValue(forKey: slow) ?? 0
                        sd[shigh] = shigh
                        slow &+= 1
                        shigh &+= 1
                    }
                    sink(acc)
                }
            ))
        }

        for n in [1_024, 65_536] {
            let reps = Swift.max(8, structureOpsTarget / n)
            let wipeOps = reps * n
            let seed = opaque(0)

            results.append(Result(
                name: "buildWipe.keep", subject: "tower.direct", n: n, opsPerBatch: wipeOps,
                perOpNs: sample(opsPerBatch: wipeOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var d = MoveDict<Int, Int>(minimumCapacity: count(n))
                        for i in 0..<n { _ = d.insert(key: i &+ seed, value: i) }
                        d.removeAll(keepingCapacity: true)
                        acc &+= d.isEmpty ? 1 : 0
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "buildWipe.keep", subject: "tower.cow", n: n, opsPerBatch: wipeOps,
                perOpNs: sample(opsPerBatch: wipeOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var c = CoWDict<Int, Int>(minimumCapacity: count(n))
                        for i in 0..<n { _ = c.insert(key: i &+ seed, value: i) }
                        c.removeAll(keepingCapacity: true)
                        acc &+= c.isEmpty ? 1 : 0
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "buildWipe.keep", subject: "stdlib", n: n, opsPerBatch: wipeOps,
                perOpNs: sample(opsPerBatch: wipeOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var sd = Swift.Dictionary<Int, Int>(minimumCapacity: n)
                        for i in 0..<n { sd[i &+ seed] = i }
                        sd.removeAll(keepingCapacity: true)
                        acc &+= sd.isEmpty ? 1 : 0
                    }
                    sink(acc)
                }
            ))
        }

        return results
    }
}
