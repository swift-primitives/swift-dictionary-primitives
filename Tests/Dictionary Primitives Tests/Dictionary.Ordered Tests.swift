// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Testing
@testable import Dictionary_Primitives

@Suite("Dictionary.Ordered")
struct OrderedDictionaryTests {

    // MARK: - Basic Operations

    @Test("Set and get values")
    func setAndGetValues() {
        var dict = Dictionary<String, Int>.Ordered()

        dict.values.set("apple", 1)
        dict.values.set("banana", 2)
        dict.values.set("cherry", 3)

        #expect(dict["apple"] == 1)
        #expect(dict["banana"] == 2)
        #expect(dict["cherry"] == 3)
        #expect(dict["durian"] == nil)
    }

    @Test("Subscript set and get")
    func subscriptSetAndGet() {
        var dict = Dictionary<String, Int>.Ordered()

        dict["a"] = 1
        dict["b"] = 2

        #expect(dict["a"] == 1)
        #expect(dict["b"] == 2)

        // Update
        dict["a"] = 10
        #expect(dict["a"] == 10)

        // Remove via nil
        dict["b"] = nil
        #expect(dict["b"] == nil)
        #expect(dict.count == 1)
    }

    @Test("Remove value")
    func removeValue() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["a"] = 1
        dict["b"] = 2
        dict["c"] = 3

        let removed = dict.values.remove("b")
        #expect(removed == 2)
        #expect(dict.count == 2)
        #expect(!dict.contains("b"))

        // Keys.index should be updated
        #expect(dict.keys.index("c") == 1)
    }

    @Test("Keys index lookup")
    func keysIndexLookup() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["first"] = 1
        dict["second"] = 2
        dict["third"] = 3

        #expect(dict.keys.index("first") == 0)
        #expect(dict.keys.index("second") == 1)
        #expect(dict.keys.index("third") == 2)
        #expect(dict.keys.index("fourth") == nil)
    }

    // MARK: - Order Preservation

    @Test("Insertion order preserved")
    func insertionOrderPreserved() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["charlie"] = 3
        dict["alpha"] = 1
        dict["bravo"] = 2

        let keys = Array(dict.keys)
        #expect(keys == ["charlie", "alpha", "bravo"])
    }

    @Test("Update does not change order")
    func updateDoesNotChangeOrder() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["a"] = 1
        dict["b"] = 2
        dict["c"] = 3

        // Update middle element
        dict["b"] = 20

        let keys = Array(dict.keys)
        #expect(keys == ["a", "b", "c"])
        #expect(dict["b"] == 20)
    }

    @Test("Re-insertion goes to end")
    func reinsertionGoesToEnd() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["a"] = 1
        dict["b"] = 2
        dict["c"] = 3

        dict.values.remove("b")
        dict["b"] = 20

        let keys = Array(dict.keys)
        #expect(keys == ["a", "c", "b"])
    }

    // MARK: - Nested Accessors

    @Test("Values modify")
    func valuesModify() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["counter"] = 0

        dict.values.modify("counter") { $0 += 1 }
        dict.values.modify("counter") { $0 += 1 }

        #expect(dict["counter"] == 2)
    }

    @Test("Merge keep first")
    func mergeKeepFirst() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["a"] = 1
        dict["b"] = 2

        dict.merge.keep.first([("b", 20), ("c", 3)])

        #expect(dict["a"] == 1)
        #expect(dict["b"] == 2)  // Kept first
        #expect(dict["c"] == 3)
    }

    @Test("Merge keep last")
    func mergeKeepLast() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["a"] = 1
        dict["b"] = 2

        dict.merge.keep.last([("b", 20), ("c", 3)])

        #expect(dict["a"] == 1)
        #expect(dict["b"] == 20)  // Kept last
        #expect(dict["c"] == 3)

        // Order should be preserved (b was updated, not re-inserted)
        let keys = Array(dict.keys)
        #expect(keys == ["a", "b", "c"])
    }

    // MARK: - Initialization

    @Test("Init from pairs")
    func initFromPairs() throws {
        let dict = try Dictionary<String, Int>.Ordered([
            ("a", 1),
            ("b", 2),
            ("c", 3)
        ])

        #expect(dict.count == 3)
        #expect(dict["a"] == 1)
        #expect(dict["b"] == 2)
        #expect(dict["c"] == 3)
    }

    @Test("Init throws on duplicate")
    func initThrowsOnDuplicate() {
        #expect(throws: Dictionary<String, Int>.Ordered.Error.self) {
            _ = try Dictionary<String, Int>.Ordered([
                ("a", 1),
                ("b", 2),
                ("a", 3)  // Duplicate
            ])
        }
    }

    @Test("Init with uniquing closure")
    func initWithUniquingClosure() {
        let dict = Dictionary<String, Int>.Ordered(
            [("a", 1), ("b", 2), ("a", 10)],
            uniquingKeysWith: { $0 + $1 }
        )

        #expect(dict["a"] == 11)  // 1 + 10
        #expect(dict["b"] == 2)
    }

    // MARK: - Collection Conformance

    @Test("Index access")
    func indexAccess() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["a"] = 1
        dict["b"] = 2
        dict["c"] = 3

        let pair = dict[index: 1]
        #expect(pair.key == "b")
        #expect(pair.value == 2)
    }

    @Test("Iteration")
    func iteration() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["x"] = 10
        dict["y"] = 20
        dict["z"] = 30

        var keys: [String] = []
        var values: [Int] = []
        for (key, value) in dict {
            keys.append(key)
            values.append(value)
        }

        #expect(keys == ["x", "y", "z"])
        #expect(values == [10, 20, 30])
    }

    @Test("Bidirectional iteration")
    func bidirectionalIteration() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["a"] = 1
        dict["b"] = 2
        dict["c"] = 3

        let reversed = Array(dict.reversed())
        #expect(reversed.map { $0.key } == ["c", "b", "a"])
    }

    // MARK: - Copy-on-Write
    //
    // Note: Identity-based CoW tests are not reliable for stdlib-backed storage.
    // See Set.Ordered._identity documentation. Use functional tests instead.

    @Test("CoW: mutation does not affect original")
    func cowMutationDoesNotAffectOriginal() {
        var original = Dictionary<String, Int>.Ordered()
        original["a"] = 1
        original["b"] = 2
        original["c"] = 3

        var copy = original
        copy["d"] = 4
        copy["a"] = nil

        #expect(Array(original.keys) == ["a", "b", "c"])
        #expect(Array(copy.keys) == ["b", "c", "d"])
        #expect(original.count == 3)
        #expect(copy.count == 3)
    }

    @Test("CoW: multiple copies are independent")
    func cowMultipleCopiesIndependent() {
        var original = Dictionary<String, Int>.Ordered()
        original["a"] = 1
        original["b"] = 2

        var copy1 = original
        var copy2 = original

        copy1["c"] = 3
        copy2["a"] = nil

        #expect(Array(original.keys) == ["a", "b"])
        #expect(Array(copy1.keys) == ["a", "b", "c"])
        #expect(Array(copy2.keys) == ["b"])
    }

    // MARK: - Properties

    @Test("Empty dictionary")
    func emptyDictionary() {
        let dict = Dictionary<String, Int>.Ordered()

        #expect(dict.isEmpty)
    }

    @Test("Clear")
    func clear() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["a"] = 1
        dict["b"] = 2

        dict.clear()

        #expect(dict.isEmpty)
    }

    @Test("Contains")
    func contains() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["apple"] = 1

        #expect(dict.contains("apple"))
        #expect(!dict.contains("banana"))
    }

    // MARK: - Equatable

    @Test("Equality")
    func equality() {
        var a = Dictionary<String, Int>.Ordered()
        a["x"] = 1
        a["y"] = 2

        var b = Dictionary<String, Int>.Ordered()
        b["x"] = 1
        b["y"] = 2

        var c = Dictionary<String, Int>.Ordered()
        c["y"] = 2
        c["x"] = 1  // Different order

        #expect(a == b)
        #expect(a != c)  // Order matters
    }
}

// MARK: - Invariant Stress Tests

@Suite("Dictionary.Ordered - Invariant Stress Tests")
struct OrderedDictionaryInvariantTests {

    // MARK: - Merge Idempotence

    @Test("Merge keep first is idempotent")
    func mergeKeepFirstIdempotent() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["a"] = 1
        dict["b"] = 2
        dict["c"] = 3

        let originalKeys = Array(dict.keys)
        let originalValues = (0..<dict.count).map { dict[index: $0].value }

        // Merge with self should be idempotent
        dict.merge.keep.first(dict.map { ($0.key, $0.value) })

        #expect(Array(dict.keys) == originalKeys)
        #expect((0..<dict.count).map { dict[index: $0].value } == originalValues)
    }

    @Test("Merge keep last is idempotent")
    func mergeKeepLastIdempotent() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["a"] = 1
        dict["b"] = 2
        dict["c"] = 3

        let originalKeys = Array(dict.keys)
        let originalValues = (0..<dict.count).map { dict[index: $0].value }

        // Merge with self should be idempotent
        dict.merge.keep.last(dict.map { ($0.key, $0.value) })

        #expect(Array(dict.keys) == originalKeys)
        #expect((0..<dict.count).map { dict[index: $0].value } == originalValues)
    }

    // MARK: - Merge Identity

    @Test("Merge keep first with empty is identity")
    func mergeKeepFirstEmptyIdentity() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["a"] = 1
        dict["b"] = 2

        let originalKeys = Array(dict.keys)
        let originalValues = (0..<dict.count).map { dict[index: $0].value }

        // Merge with empty should be identity
        dict.merge.keep.first([])

        #expect(Array(dict.keys) == originalKeys)
        #expect((0..<dict.count).map { dict[index: $0].value } == originalValues)
    }

    @Test("Merge keep last with empty is identity")
    func mergeKeepLastEmptyIdentity() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["a"] = 1
        dict["b"] = 2

        let originalKeys = Array(dict.keys)
        let originalValues = (0..<dict.count).map { dict[index: $0].value }

        // Merge with empty should be identity
        dict.merge.keep.last([])

        #expect(Array(dict.keys) == originalKeys)
        #expect((0..<dict.count).map { dict[index: $0].value } == originalValues)
    }

    // MARK: - Empty Dictionary Edge Cases

    @Test("Empty dictionary operations")
    func emptyDictionaryEdgeCases() {
        var empty = Dictionary<String, Int>.Ordered()

        // Operations on empty dictionary
        #expect(empty.isEmpty)
        #expect(empty.count == 0)
        #expect(empty["missing"] == nil)
        #expect(!empty.contains("missing"))
        #expect(empty.keys.index("missing") == nil)
        #expect(empty.values.remove("missing") == nil)

        // Merge into empty
        empty.merge.keep.first([("a", 1)])
        #expect(empty.count == 1)
        #expect(empty["a"] == 1)
    }

    @Test("Empty merge into non-empty")
    func emptyMergeIntoNonEmpty() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["a"] = 1
        dict["b"] = 2

        let originalKeys = Array(dict.keys)

        // Merge empty into non-empty
        let empty: [(String, Int)] = []
        dict.merge.keep.first(empty)

        #expect(Array(dict.keys) == originalKeys)
        #expect(dict.count == 2)
    }

    // MARK: - Key-Value Index Correspondence

    @Test("Key-value index correspondence after operations")
    func keyValueIndexCorrespondence() {
        var dict = Dictionary<String, Int>.Ordered()

        // Build dictionary
        for i in 0..<10 {
            dict["key\(i)"] = i * 10
        }

        // Verify correspondence
        for i in 0..<dict.count {
            let key = dict.keys[i]
            let pair = dict[index: i]
            #expect(pair.key == key)
            #expect(dict[key] == pair.value)
        }

        // Remove some elements
        dict.values.remove("key3")
        dict.values.remove("key7")

        // Verify correspondence still holds
        for i in 0..<dict.count {
            let key = dict.keys[i]
            let pair = dict[index: i]
            #expect(pair.key == key)
            #expect(dict[key] == pair.value)
        }
    }

    // MARK: - Order Preservation Under Stress

    @Test("Order preserved through many operations")
    func orderPreservedThroughManyOperations() {
        var dict = Dictionary<String, Int>.Ordered()
        var expectedOrder: [String] = []

        // Insert 50 elements
        for i in 0..<50 {
            let key = "key\(i)"
            dict[key] = i
            expectedOrder.append(key)
        }

        // Update values (should not change order)
        for i in stride(from: 0, to: 50, by: 2) {
            dict["key\(i)"] = i * 100
        }

        #expect(Array(dict.keys) == expectedOrder)

        // Remove every 5th element
        for i in stride(from: 0, to: 50, by: 5) {
            dict.values.remove("key\(i)")
            expectedOrder.removeAll { $0 == "key\(i)" }
        }

        #expect(Array(dict.keys) == expectedOrder)

        // Re-insert removed elements (should go to end)
        for i in stride(from: 0, to: 50, by: 5) {
            dict["key\(i)"] = i * 1000
            expectedOrder.append("key\(i)")
        }

        #expect(Array(dict.keys) == expectedOrder)
    }

    // MARK: - Duplicate Key Handling

    @Test("Init throws on duplicate preserves partial state correctly")
    func initThrowsOnDuplicatePartialState() {
        // When init throws, no dictionary is created
        // This test verifies the error contains correct information
        do {
            _ = try Dictionary<String, Int>.Ordered([
                ("a", 1),
                ("b", 2),
                ("c", 3),
                ("a", 10)  // Duplicate
            ])
            Issue.record("Expected error to be thrown")
        } catch let error as Dictionary<String, Int>.Ordered.Error {
            if case .duplicate(let info) = error {
                #expect(info.key == "a")
                #expect(info.first == 0)  // First occurrence at index 0
            } else {
                Issue.record("Expected duplicate error")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Pathological Merge Orders

    @Test("Merge with reversed order")
    func mergeWithReversedOrder() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["a"] = 1
        dict["b"] = 2
        dict["c"] = 3

        // Merge reversed pairs
        dict.merge.keep.last([("c", 30), ("b", 20), ("a", 10)])

        // Order should be preserved, values updated
        #expect(Array(dict.keys) == ["a", "b", "c"])
        #expect(dict["a"] == 10)
        #expect(dict["b"] == 20)
        #expect(dict["c"] == 30)
    }

    @Test("Merge with interleaved keys")
    func mergeWithInterleavedKeys() {
        var dict = Dictionary<String, Int>.Ordered()
        dict["a"] = 1
        dict["c"] = 3
        dict["e"] = 5

        // Merge interleaved keys
        dict.merge.keep.first([("b", 2), ("d", 4), ("f", 6)])

        // Original keys first, then new keys in merge order
        #expect(Array(dict.keys) == ["a", "c", "e", "b", "d", "f"])
    }
}
