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

import Testing
@testable import Dictionary_Primitives
import Index_Primitives_Test_Support
import Identity_Primitives_Test_Support

// MARK: - Dictionary (Unordered, Slab-Backed) Tests
//
// [TEST-004] Generic type specializations use parallel namespace pattern due to
// Swift Testing discovery limitation. See swiftlang/swift-testing#1508.
//
// Note: Dictionary (unordered) is conditionally Copyable when Value: Copyable,
// but uses REFERENCE SEMANTICS — copies share Storage.Slab. No CoW is implemented.
// Copy independence tests belong on Dictionary.Ordered (which has CoW).

@Suite("Dictionary")
struct DictionaryTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
}

// MARK: - Unit Tests

extension DictionaryTests.Unit {

    @Test
    func `init creates empty dictionary`() {
        let dict = Dictionary<String, Int>()
        #expect(dict.isEmpty == true)
        #expect(dict.count == .zero)
    }

    @Test
    func `set and contains`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict.set("b", 2)
        #expect(dict.contains("a") == true)
        #expect(dict.contains("b") == true)
        #expect(dict.contains("c") == false)
        #expect(dict.count == 2)
    }

    @Test
    func `remove returns removed value`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict.set("b", 2)

        let removed = dict.remove("a")
        #expect(removed == 1)
        #expect(dict.contains("a") == false)
        #expect(dict.count == 1)
    }

    @Test
    func `remove nonexistent key returns nil`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        let removed = dict.remove("b")
        #expect(removed == nil)
        #expect(dict.count == 1)
    }

    @Test
    func `set overwrites existing value`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict.set("a", 99)
        #expect(dict.count == 1)

        var found = false
        dict.forEach { key, value in
            if key == "a" {
                #expect(value == 99)
                found = true
            }
        }
        #expect(found == true)
    }

    @Test
    func `forEach visits all elements`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict.set("b", 2)
        dict.set("c", 3)

        var keys: [String] = []
        var values: [Int] = []
        dict.forEach { key, value in
            keys.append(key)
            values.append(value)
        }
        #expect(keys.sorted() == ["a", "b", "c"])
        #expect(values.sorted() == [1, 2, 3])
    }

    @Test
    func `withValue accesses value for key`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 42)

        let result = dict.withValue(forKey: "a") { value in
            value
        }
        #expect(result == 42)

        let missing = dict.withValue(forKey: "b") { value in
            value
        }
        #expect(missing == nil)
    }

    @Test
    func `clear removes all entries`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict.set("b", 2)
        dict.set("c", 3)
        dict.clear(keepingCapacity: true)

        #expect(dict.isEmpty == true)
        #expect(dict.count == .zero)
    }
}

// MARK: - Swift.Sequence Tests

extension DictionaryTests.Unit {

    @Test
    func `for-in loop iterates all elements`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict.set("b", 2)
        dict.set("c", 3)

        var pairs: [(String, Int)] = []
        for (key, value) in dict {
            pairs.append((key, value))
        }
        #expect(pairs.count == 3)
        #expect(Swift.Set(pairs.map(\.0)) == ["a", "b", "c"])
        #expect(Swift.Set(pairs.map(\.1)) == [1, 2, 3])
    }

    @Test
    func `makeIterator produces valid iterator`() {
        var dict = Dictionary<String, Int>()
        dict.set("x", 10)

        var iter = dict.makeIterator()
        let first = iter.next()
        #expect(first != nil)
        #expect(first!.key == "x")
        #expect(first!.value == 10)

        let second = iter.next()
        #expect(second == nil)
    }

    @Test
    func `for-in on empty dictionary produces no iterations`() {
        let dict = Dictionary<String, Int>()
        var count = 0
        for _ in dict {
            count += 1
        }
        #expect(count == 0)
    }
}

// MARK: - Subscript Tests

extension DictionaryTests.Unit {

    @Test
    func `subscript get returns value or nil`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)

        #expect(dict["a"] == 1)
        #expect(dict["b"] == nil)
    }

    @Test
    func `subscript set inserts value`() {
        var dict = Dictionary<String, Int>()
        dict["a"] = 1
        #expect(dict.count == 1)
        #expect(dict["a"] == 1)
    }

    @Test
    func `subscript set nil removes value`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict["a"] = nil
        #expect(dict.contains("a") == false)
        #expect(dict.count == .zero)
    }

    @Test
    func `subscript set overwrites existing`() {
        var dict = Dictionary<String, Int>()
        dict["a"] = 1
        dict["a"] = 99
        #expect(dict["a"] == 99)
        #expect(dict.count == 1)
    }
}

// MARK: - Drain Tests

extension DictionaryTests.Unit {

    @Test
    func `drain removes all entries`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict.set("b", 2)
        dict.set("c", 3)

        var entries: [(String, Int)] = []
        dict.drain { entry in
            entries.append((entry.key, entry.value))
        }
        #expect(dict.isEmpty == true)
        #expect(entries.count == 3)
        #expect(Swift.Set(entries.map(\.0)) == ["a", "b", "c"])
    }

    @Test
    func `drain on empty dictionary is no-op`() {
        var dict = Dictionary<String, Int>()
        var count = 0
        dict.drain { _ in count += 1 }
        #expect(count == 0)
        #expect(dict.isEmpty == true)
    }
}

// MARK: - Sequence.Clearable Tests

extension DictionaryTests.Unit {

    @Test
    func `removeAll clears dictionary`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict.set("b", 2)
        dict.removeAll()
        #expect(dict.isEmpty == true)
        #expect(dict.count == .zero)
    }
}

// MARK: - Edge Cases

extension DictionaryTests.EdgeCase {

    @Test
    func `growth preserves all elements`() {
        var dict = Dictionary<String, Int>()
        let n = 100
        for i in 0..<n {
            dict.set("key\(i)", i)
        }
        #expect(dict.count == Index<String>.Count(Cardinal(UInt(n))))

        for i in 0..<n {
            #expect(dict.contains("key\(i)") == true)
            #expect(dict["key\(i)"] == i)
        }
    }

    @Test
    func `insert-remove-reinsert cycle`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        _ = dict.remove("a")
        dict.set("a", 2)
        #expect(dict["a"] == 2)
        #expect(dict.count == 1)
    }

    @Test
    func `multiple insert-remove cycles`() {
        var dict = Dictionary<String, Int>()
        for cycle in 0..<5 {
            for i in 0..<20 {
                dict.set("k\(i)", cycle * 20 + i)
            }
            for i in stride(from: 0, to: 20, by: 2) {
                _ = dict.remove("k\(i)")
            }
        }

        // After 5 cycles: odd keys have latest values, even keys removed
        for i in stride(from: 1, to: 20, by: 2) {
            #expect(dict.contains("k\(i)") == true)
        }
        for i in stride(from: 0, to: 20, by: 2) {
            #expect(dict.contains("k\(i)") == false)
        }
    }
}

// MARK: - Integration Tests

extension DictionaryTests.Integration {

    @Test
    func `mixed operations: set, remove, iterate`() {
        var dict = Dictionary<String, Int>()

        // Insert
        dict.set("a", 1)
        dict.set("b", 2)
        dict.set("c", 3)

        // Remove
        _ = dict.remove("b")

        // Update
        dict.set("d", 4)
        dict.set("a", 99)

        // Verify state
        #expect(dict.count == 3)
        #expect(dict["a"] == 99)
        #expect(dict["d"] == 4)
        #expect(dict.contains("b") == false)

        // Iterate
        var keys: [String] = []
        for (key, _) in dict {
            keys.append(key)
        }
        #expect(keys.sorted() == ["a", "c", "d"])
    }

    @Test
    func `heavy insert-remove preserves invariants`() {
        var dict = Dictionary<String, Int>()

        // Insert 200 elements
        for i in 0..<200 {
            dict.set("k\(i)", i)
        }
        #expect(dict.count == Index<String>.Count(Cardinal(200 as UInt)))

        // Remove even-indexed elements
        for i in stride(from: 0, to: 200, by: 2) {
            _ = dict.remove("k\(i)")
        }

        // Verify only odd-indexed elements remain
        #expect(dict.count == Index<String>.Count(Cardinal(100 as UInt)))
        for i in stride(from: 1, to: 200, by: 2) {
            #expect(dict.contains("k\(i)") == true)
            #expect(dict["k\(i)"] == i)
        }
        for i in stride(from: 0, to: 200, by: 2) {
            #expect(dict.contains("k\(i)") == false)
        }
    }

    @Test
    func `subscript-based workflow`() {
        var dict = Dictionary<String, Int>()

        // Build via subscript
        dict["x"] = 10
        dict["y"] = 20
        dict["z"] = 30

        // Read via subscript
        #expect(dict["x"] == 10)
        #expect(dict["y"] == 20)
        #expect(dict["z"] == 30)

        // Update via subscript
        dict["y"] = 99

        // Remove via subscript
        dict["x"] = nil

        #expect(dict.count == 2)
        #expect(dict["x"] == nil)
        #expect(dict["y"] == 99)
        #expect(dict["z"] == 30)
    }
}
