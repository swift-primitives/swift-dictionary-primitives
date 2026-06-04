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

import Buffer_Slab_Primitive
import Testing

@testable import Dictionary_Primitives

// MARK: - Dictionary Copy-on-Write Divergence Tests
//
// Dictionary (unordered) implements per-plane copy-on-write (see
// `Dictionary+CoW.swift`). A copy SHARES each plane's `Buffer.Slab` box until a
// mutation diverges exactly the plane(s) it mutates:
//
//   - a values-only mutation (update of an existing key) diverges `_values` and
//     leaves the shared `_keys` box intact (correct — keys are not written);
//   - a both-plane mutation (insert of a new key, remove, clear, drain) diverges
//     both `_keys` and `_values`.
//
// These tests verify, separately for each plane:
//   1. divergence — mutating the original does not affect a prior copy;
//   2. the unique-instance no-op — mutating a never-copied dictionary does NOT
//      deep-copy (the slab's `ensureUnique()` returns `false` / the plane stays
//      uniquely referenced);
//   3. ARC sanity — divergence does not double-free or leak.
//
// The `_keys` / `_values` planes are `public` stored properties, so the
// per-plane uniqueness probes (`isUnique()` / `ensureUnique()`) are exercised
// directly under `@testable`.
//
// SCOPE NOTE (hash-table dual): the both-plane ops (insert / remove / clear /
// drain) also mutate the shared `_hashTable` plane, whose `Hash.Table` backing
// does NOT yet route `ensureUnique()`. The keys-plane / both-plane divergence
// tests below encode the INTENDED end-state contract; their EMPIRICAL green
// additionally requires `Hash.Table` to adopt the dual CoW routing in the
// hash-table package (see `Dictionary+CoW.swift` "Scope boundary"). The
// values-only divergence tests are fully sound today (the update path touches
// neither `_keys` nor `_hashTable`). The empirical run is in any case blocked
// on the ratified collection↔iterator drift; verification here is COMPILE-only.

@Suite("Dictionary Copy-on-Write")
struct DictionaryCoWTests {

    // MARK: - Values-plane divergence (values-only mutation)

    @Test
    func `updating an existing key on the original does not affect a copy`() {
        var original = Dictionary<String, Int>()
        original.set("a", 1)
        original.set("b", 2)

        let copy = original

        // Update of an EXISTING key mutates only the values plane.
        original.set("a", 99)

        #expect(copy["a"] == 1)          // copy unaffected
        #expect(copy["b"] == 2)
        #expect(original["a"] == 99)     // original diverged
        #expect(original["b"] == 2)
    }

    @Test
    func `subscript-set update on the original does not affect a copy`() {
        var original = Dictionary<String, Int>()
        original["x"] = 10
        original["y"] = 20

        let copy = original
        original["x"] = 999              // values-only mutation via subscript

        #expect(copy["x"] == 10)
        #expect(copy["y"] == 20)
        #expect(original["x"] == 999)
    }

    @Test
    func `values-only update leaves the keys plane shared`() {
        var original = Dictionary<String, Int>()
        original.set("a", 1)
        original.set("b", 2)

        var copy = original

        // Before any mutation both planes are shared.
        #expect(original._keys.isUnique() == false)
        #expect(original._values.isUnique() == false)
        // `isUnique()` is mutating; re-fetch the shared state for `copy`.
        #expect(copy._keys.isUnique() == false)
        #expect(copy._values.isUnique() == false)

        // A pure update diverges ONLY the values plane.
        original.set("a", 7)

        // Values plane diverged on the original …
        #expect(original._values.isUnique() == true)
        // … but the keys plane stays shared between original and copy
        // (do-NOT-over-route: a values-only mutation must not touch keys).
        #expect(original._keys.isUnique() == false)
    }

    // MARK: - Keys-plane divergence (both-plane mutation)

    @Test
    func `inserting a new key on the original does not affect a copy`() {
        var original = Dictionary<String, Int>()
        original.set("a", 1)
        original.set("b", 2)

        let copy = original

        // Insert of a NEW key mutates both planes.
        original.set("c", 3)

        #expect(copy.contains("c") == false)   // copy unaffected (keys plane)
        #expect(copy.count == 2)
        #expect(original.contains("c") == true) // original diverged
        #expect(original.count == 3)
    }

    @Test
    func `removing a key on the original does not affect a copy`() {
        var original = Dictionary<String, Int>()
        original.set("a", 1)
        original.set("b", 2)
        original.set("c", 3)

        let copy = original

        // Remove mutates both planes.
        _ = original.remove("b")

        #expect(copy.contains("b") == true)    // copy unaffected
        #expect(copy["b"] == 2)
        #expect(copy.count == 3)
        #expect(original.contains("b") == false)  // original diverged
        #expect(original.count == 2)
    }

    @Test
    func `clear keeping capacity on the original does not affect a copy`() {
        var original = Dictionary<String, Int>()
        original.set("a", 1)
        original.set("b", 2)

        let copy = original
        original.clear(keepingCapacity: true)

        #expect(copy.count == 2)               // copy unaffected
        #expect(copy.contains("a") == true)
        #expect(original.isEmpty == true)      // original diverged
    }

    @Test
    func `drain on the original does not affect a copy`() {
        var original = Dictionary<String, Int>()
        original.set("a", 1)
        original.set("b", 2)

        let copy = original
        original.drain { _ in }

        #expect(copy.count == 2)               // copy unaffected
        #expect(copy.contains("a") == true)
        #expect(copy.contains("b") == true)
        #expect(original.isEmpty == true)      // original diverged
    }

    @Test
    func `both-plane mutation diverges both planes`() {
        var original = Dictionary<String, Int>()
        original.set("a", 1)
        original.set("b", 2)

        _ = original   // establish a copy to share both boxes
        let copy = original

        #expect(original._keys.isUnique() == false)
        #expect(original._values.isUnique() == false)

        // Insert of a new key mutates both planes → both diverge.
        original.set("z", 26)

        #expect(original._keys.isUnique() == true)
        #expect(original._values.isUnique() == true)

        // The copy is untouched.
        #expect(copy.contains("z") == false)
        #expect(copy.count == 2)
    }

    // MARK: - Unique-instance no-op (never-copied dictionary does not deep-copy)

    @Test
    func `mutating a never-copied dictionary does not deep-copy the keys plane`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)

        // Never copied → each plane is uniquely referenced. ensureUnique() must
        // observe uniqueness and install NO fresh box (returns false).
        #expect(dict._keys.ensureUnique() == false)
    }

    @Test
    func `mutating a never-copied dictionary does not deep-copy the values plane`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)

        #expect(dict._values.ensureUnique() == false)
    }

    @Test
    func `never-copied planes stay uniquely referenced across mutations`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict.set("b", 2)
        _ = dict.remove("a")
        dict.set("a", 99)

        // No copy was ever taken → both planes remain uniquely referenced; no
        // mutation triggered a deep copy.
        #expect(dict._keys.isUnique() == true)
        #expect(dict._values.isUnique() == true)
    }

    // MARK: - ARC sanity

    @Test
    func `divergence after dropping the original keeps the copy valid`() {
        var original: Dictionary<String, Int>? = Dictionary<String, Int>()
        original!.set("a", 1)
        original!.set("b", 2)

        var copy = original!

        // Mutate the copy (diverges the copy's planes), then drop the original.
        copy.set("c", 3)
        original = nil

        #expect(copy.count == 3)
        #expect(copy.contains("a") == true)
        #expect(copy.contains("c") == true)
    }

    @Test
    func `dropping a diverged original does not double-free the copy`() {
        var original: Dictionary<String, Int>? = Dictionary<String, Int>()
        original!.set("a", 1)
        original!.set("b", 2)

        var copy: Dictionary<String, Int>? = original!

        // Diverge the original (both planes get fresh boxes), then drop both.
        original!.set("c", 3)
        original = nil
        #expect(copy!.count == 2)
        copy = nil
        // No crash = ARC correctly manages each plane's diverged box lifetime.
    }

    @Test
    func `independent divergence of multiple copies`() {
        var a = Dictionary<String, Int>()
        a.set("k", 0)

        var b = a
        var c = a

        a.set("a", 1)   // diverges a
        b.set("b", 2)   // diverges b
        c.set("c", 3)   // diverges c

        #expect(a.contains("a") == true)
        #expect(a.contains("b") == false)
        #expect(a.contains("c") == false)

        #expect(b.contains("b") == true)
        #expect(b.contains("a") == false)

        #expect(c.contains("c") == true)
        #expect(c.contains("a") == false)
    }
}
