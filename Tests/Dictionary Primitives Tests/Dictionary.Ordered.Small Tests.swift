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

import Tagged_Primitives_Test_Support
import Testing

@testable import Dictionary_Primitives

// MARK: - Dictionary.Ordered.Small Tests
//
// Note: Small is unconditionally ~Copyable, so #expect cannot use direct
// property access syntax. Extract values to local variables first.

@Suite("Dictionary.Ordered.Small")
struct DictionaryOrderedSmallTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
}

// MARK: - Unit Tests (Inline Mode)

extension DictionaryOrderedSmallTests.Unit {

    @Test
    func `Basic insert and retrieve in inline mode`() {
        var dict = Dictionary<String, Int>.Ordered.Small<4>()

        dict.set("apple", 1)
        dict.set("banana", 2)

        dict.withValue(forKey: "apple") { value in
            #expect(value == 1)
        }
        dict.withValue(forKey: "banana") { value in
            #expect(value == 2)
        }
        let isSpilled = dict.isSpilled
        #expect(!isSpilled)
    }

    @Test
    func `Count and isEmpty in inline mode`() {
        var dict = Dictionary<String, Int>.Ordered.Small<4>()

        var isEmpty = dict.isEmpty
        var count = dict.count
        #expect(isEmpty)
        #expect(count == 0)

        dict.set("a", 1)
        isEmpty = dict.isEmpty
        count = dict.count
        let isSpilled = dict.isSpilled
        #expect(!isEmpty)
        #expect(count == 1)
        #expect(!isSpilled)
    }

    @Test
    func `Update existing key in inline mode`() {
        var dict = Dictionary<String, Int>.Ordered.Small<4>()

        dict.set("key", 1)
        dict.set("key", 100)

        dict.withValue(forKey: "key") { value in
            #expect(value == 100)
        }
        let count = dict.count
        let isSpilled = dict.isSpilled
        #expect(count == 1)
        #expect(!isSpilled)
    }

    @Test
    func `Contains in inline mode`() {
        var dict = Dictionary<String, Int>.Ordered.Small<4>()

        dict.set("exists", 42)

        let hasExists = dict.contains("exists")
        let hasMissing = dict.contains("missing")
        let isSpilled = dict.isSpilled
        #expect(hasExists)
        #expect(!hasMissing)
        #expect(!isSpilled)
    }

    @Test
    func `Remove in inline mode`() {
        var dict = Dictionary<String, Int>.Ordered.Small<4>()

        dict.set("a", 1)
        dict.set("b", 2)
        dict.set("c", 3)

        let removed = dict.remove("b")
        let count = dict.count
        let hasB = dict.contains("b")
        let isSpilled = dict.isSpilled
        #expect(removed == 2)
        #expect(count == 2)
        #expect(!hasB)
        #expect(!isSpilled)
    }

    @Test
    func `Clear in inline mode`() {
        var dict = Dictionary<String, Int>.Ordered.Small<4>()

        dict.set("a", 1)
        dict.set("b", 2)

        dict.clear()

        let isEmpty = dict.isEmpty
        let count = dict.count
        let isSpilled = dict.isSpilled
        #expect(isEmpty)
        #expect(count == 0)
        #expect(!isSpilled)
    }

    @Test
    func `WithValue at index in inline mode`() {
        var dict = Dictionary<String, Int>.Ordered.Small<4>()

        dict.set("x", 10)
        dict.set("y", 20)

        dict.withValue(atIndex: 0) { value in
            #expect(value == 10)
        }
        dict.withValue(atIndex: 1) { value in
            #expect(value == 20)
        }
        let isSpilled = dict.isSpilled
        #expect(!isSpilled)
    }
}

// MARK: - Edge Case Tests (Spill to Heap)

extension DictionaryOrderedSmallTests.EdgeCase {

    @Test
    func `Spill to heap on overflow`() {
        var dict = Dictionary<String, Int>.Ordered.Small<2>()

        dict.set("a", 1)
        dict.set("b", 2)
        var isSpilled = dict.isSpilled
        #expect(!isSpilled)

        // This should trigger spill
        dict.set("c", 3)
        isSpilled = dict.isSpilled
        let count = dict.count
        #expect(isSpilled)
        #expect(count == 3)

        // Values should still be accessible
        dict.withValue(forKey: "a") { #expect($0 == 1) }
        dict.withValue(forKey: "b") { #expect($0 == 2) }
        dict.withValue(forKey: "c") { #expect($0 == 3) }
    }

    @Test
    func `Operations after spill`() {
        var dict = Dictionary<String, Int>.Ordered.Small<2>()

        dict.set("a", 1)
        dict.set("b", 2)
        dict.set("c", 3)  // Spills here

        let isSpilled = dict.isSpilled
        #expect(isSpilled)

        // Continue adding
        dict.set("d", 4)
        dict.set("e", 5)

        let count = dict.count
        #expect(count == 5)
        dict.withValue(forKey: "d") { #expect($0 == 4) }
        dict.withValue(forKey: "e") { #expect($0 == 5) }
    }

    @Test
    func `Update in heap mode`() {
        var dict = Dictionary<String, Int>.Ordered.Small<2>()

        dict.set("a", 1)
        dict.set("b", 2)
        dict.set("c", 3)  // Spills

        let isSpilled = dict.isSpilled
        #expect(isSpilled)

        dict.set("b", 200)
        dict.withValue(forKey: "b") { #expect($0 == 200) }
        let count = dict.count
        #expect(count == 3)
    }

    @Test
    func `Remove in heap mode`() {
        var dict = Dictionary<String, Int>.Ordered.Small<2>()

        dict.set("a", 1)
        dict.set("b", 2)
        dict.set("c", 3)  // Spills

        var isSpilled = dict.isSpilled
        #expect(isSpilled)

        let removed = dict.remove("b")
        let count = dict.count
        let hasB = dict.contains("b")
        isSpilled = dict.isSpilled
        #expect(removed == 2)
        #expect(count == 2)
        #expect(!hasB)
        #expect(isSpilled)  // Should remain spilled
    }

    @Test
    func `Contains in heap mode`() {
        var dict = Dictionary<String, Int>.Ordered.Small<2>()

        dict.set("a", 1)
        dict.set("b", 2)
        dict.set("c", 3)  // Spills

        let isSpilled = dict.isSpilled
        let hasA = dict.contains("a")
        let hasB = dict.contains("b")
        let hasC = dict.contains("c")
        let hasMissing = dict.contains("missing")
        #expect(isSpilled)
        #expect(hasA)
        #expect(hasB)
        #expect(hasC)
        #expect(!hasMissing)
    }

    @Test
    func `Clear in heap mode`() {
        var dict = Dictionary<String, Int>.Ordered.Small<2>()

        dict.set("a", 1)
        dict.set("b", 2)
        dict.set("c", 3)  // Spills

        var isSpilled = dict.isSpilled
        #expect(isSpilled)

        dict.clear()

        let isEmpty = dict.isEmpty
        let count = dict.count
        #expect(isEmpty)
        #expect(count == 0)
        // Note: clear keeps heap mode, doesn't go back to inline
    }

    @Test
    func `WithValue at index in heap mode`() {
        var dict = Dictionary<String, Int>.Ordered.Small<2>()

        dict.set("x", 10)
        dict.set("y", 20)
        dict.set("z", 30)  // Spills

        let isSpilled = dict.isSpilled
        #expect(isSpilled)

        dict.withValue(atIndex: 0) { #expect($0 == 10) }
        dict.withValue(atIndex: 1) { #expect($0 == 20) }
        dict.withValue(atIndex: 2) { #expect($0 == 30) }
    }
}

// MARK: - Integration Tests

extension DictionaryOrderedSmallTests.Integration {

    @Test
    func `Mixed inline and heap operations`() {
        var dict = Dictionary<String, Int>.Ordered.Small<3>()

        // Inline mode
        dict.set("a", 1)
        dict.set("b", 2)
        var isSpilled = dict.isSpilled
        #expect(!isSpilled)

        // Remove in inline mode
        dict.remove("a")
        var count = dict.count
        #expect(count == 1)

        // Add more, still inline
        dict.set("c", 3)
        dict.set("d", 4)
        isSpilled = dict.isSpilled
        #expect(!isSpilled)

        // One more triggers spill
        dict.set("e", 5)
        isSpilled = dict.isSpilled
        count = dict.count
        #expect(isSpilled)
        #expect(count == 4)

        // Verify all values
        let hasA = dict.contains("a")
        #expect(!hasA)
        dict.withValue(forKey: "b") { #expect($0 == 2) }
        dict.withValue(forKey: "c") { #expect($0 == 3) }
        dict.withValue(forKey: "d") { #expect($0 == 4) }
        dict.withValue(forKey: "e") { #expect($0 == 5) }
    }

    @Test
    func `Single element capacity`() {
        var dict = Dictionary<String, Int>.Ordered.Small<1>()

        dict.set("only", 42)
        var isSpilled = dict.isSpilled
        var count = dict.count
        #expect(!isSpilled)
        #expect(count == 1)

        dict.set("second", 100)  // Spills immediately
        isSpilled = dict.isSpilled
        count = dict.count
        #expect(isSpilled)
        #expect(count == 2)

        dict.withValue(forKey: "only") { #expect($0 == 42) }
        dict.withValue(forKey: "second") { #expect($0 == 100) }
    }

    @Test
    func `Values preserved across spill`() {
        var dict = Dictionary<String, Int>.Ordered.Small<4>()

        // Fill inline capacity
        for i in 0..<4 {
            dict.set("key\(i)", i * 10)
        }
        var isSpilled = dict.isSpilled
        #expect(!isSpilled)

        // Spill
        dict.set("overflow", 999)
        isSpilled = dict.isSpilled
        #expect(isSpilled)

        // All original values preserved
        for i in 0..<4 {
            dict.withValue(forKey: "key\(i)") { value in
                #expect(value == i * 10)
            }
        }
        dict.withValue(forKey: "overflow") { #expect($0 == 999) }
    }
}
