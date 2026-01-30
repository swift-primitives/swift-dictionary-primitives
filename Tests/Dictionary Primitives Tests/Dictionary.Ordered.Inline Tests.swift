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

// MARK: - Dictionary.Ordered.Inline Tests
//
// Note: Inline is unconditionally ~Copyable, so #expect cannot use direct
// property access syntax. Extract values to local variables first.

@Suite("Dictionary.Ordered.Inline")
struct DictionaryOrderedInlineTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
}

// MARK: - Unit Tests

extension DictionaryOrderedInlineTests.Unit {

    @Test
    func `Basic insert and retrieve`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<8>()

        try! dict.set("apple", 1)
        try! dict.set("banana", 2)
        try! dict.set("cherry", 3)

        dict.withValue(forKey: "apple") { value in
            #expect(value == 1)
        }
        dict.withValue(forKey: "banana") { value in
            #expect(value == 2)
        }
        dict.withValue(forKey: "cherry") { value in
            #expect(value == 3)
        }
        let hasDurian = dict.withValue(forKey: "durian") { _ in }
        #expect(hasDurian == nil)
    }

    @Test
    func `Count and isEmpty`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<4>()

        var isEmpty = dict.isEmpty
        var count = dict.count
        #expect(isEmpty)
        #expect(count == 0)

        try! dict.set("a", 1)
        isEmpty = dict.isEmpty
        count = dict.count
        #expect(!isEmpty)
        #expect(count == 1)

        try! dict.set("b", 2)
        count = dict.count
        #expect(count == 2)
    }

    @Test
    func `Update existing key`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<4>()

        try! dict.set("key", 1)
        dict.withValue(forKey: "key") { value in
            #expect(value == 1)
        }

        // Update same key
        try! dict.set("key", 100)
        dict.withValue(forKey: "key") { value in
            #expect(value == 100)
        }

        // Count should remain 1
        let count = dict.count
        #expect(count == 1)
    }

    @Test
    func `Contains key`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<4>()

        try! dict.set("exists", 42)

        let hasExists = dict.contains("exists")
        let hasMissing = dict.contains("missing")
        #expect(hasExists)
        #expect(!hasMissing)
    }

    @Test
    func `Index of key`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<4>()

        try! dict.set("first", 1)
        try! dict.set("second", 2)
        try! dict.set("third", 3)

        #expect(dict.index(of: "first") == 0)
        #expect(dict.index(of: "second") == 1)
        #expect(dict.index(of: "third") == 2)
        #expect(dict.index(of: "missing") == nil)
    }

    @Test
    func `Remove and shift`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<8>()

        try! dict.set("a", 1)
        try! dict.set("b", 2)
        try! dict.set("c", 3)
        try! dict.set("d", 4)

        // Remove middle element
        let removed = dict.remove("b")
        let count = dict.count
        let hasB = dict.contains("b")
        #expect(removed == 2)
        #expect(count == 3)
        #expect(!hasB)

        // Indices should have shifted
        #expect(dict.index(of: "a") == 0)
        #expect(dict.index(of: "c") == 1)
        #expect(dict.index(of: "d") == 2)
    }

    @Test
    func `Remove first element`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<4>()

        try! dict.set("a", 1)
        try! dict.set("b", 2)
        try! dict.set("c", 3)

        let removed = dict.remove("a")
        let count = dict.count
        #expect(removed == 1)
        #expect(count == 2)
        #expect(dict.index(of: "b") == 0)
        #expect(dict.index(of: "c") == 1)
    }

    @Test
    func `Remove last element`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<4>()

        try! dict.set("a", 1)
        try! dict.set("b", 2)
        try! dict.set("c", 3)

        let removed = dict.remove("c")
        let count = dict.count
        #expect(removed == 3)
        #expect(count == 2)
        #expect(dict.index(of: "a") == 0)
        #expect(dict.index(of: "b") == 1)
    }

    @Test
    func `Remove non-existent key`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<4>()

        try! dict.set("a", 1)

        let removed = dict.remove("missing")
        let count = dict.count
        #expect(removed == nil)
        #expect(count == 1)
    }

    @Test
    func `Clear`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<4>()

        try! dict.set("a", 1)
        try! dict.set("b", 2)
        try! dict.set("c", 3)

        dict.clear()

        let isEmpty = dict.isEmpty
        let count = dict.count
        let hasA = dict.contains("a")
        #expect(isEmpty)
        #expect(count == 0)
        #expect(!hasA)
    }

    @Test
    func `WithValue at index`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<4>()

        try! dict.set("x", 10)
        try! dict.set("y", 20)
        try! dict.set("z", 30)

        dict.withValue(atIndex: 0) { value in
            #expect(value == 10)
        }
        dict.withValue(atIndex: 1) { value in
            #expect(value == 20)
        }
        dict.withValue(atIndex: 2) { value in
            #expect(value == 30)
        }
    }

    @Test
    func `isFull property`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<2>()

        var isFull = dict.isFull
        #expect(!isFull)

        try! dict.set("a", 1)
        isFull = dict.isFull
        #expect(!isFull)

        try! dict.set("b", 2)
        isFull = dict.isFull
        #expect(isFull)
    }
}

// MARK: - Edge Case Tests

extension DictionaryOrderedInlineTests.EdgeCase {

    @Test
    func `Overflow throws error`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<2>()

        try! dict.set("a", 1)
        try! dict.set("b", 2)

        #expect(throws: Dictionary<String, Int>.Ordered.Inline<2>.Error.self) {
            try dict.set("c", 3)
        }
    }

    @Test
    func `Update at capacity does not throw`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<2>()

        try! dict.set("a", 1)
        try! dict.set("b", 2)

        // Updating existing key should not throw even at capacity
        try! dict.set("a", 100)
        dict.withValue(forKey: "a") { value in
            #expect(value == 100)
        }
    }

    @Test
    func `Single element operations`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<1>()

        try! dict.set("only", 42)
        var count = dict.count
        var isFull = dict.isFull
        #expect(count == 1)
        #expect(isFull)

        dict.withValue(forKey: "only") { value in
            #expect(value == 42)
        }

        let removed = dict.remove("only")
        let isEmpty = dict.isEmpty
        #expect(removed == 42)
        #expect(isEmpty)
    }

    @Test
    func `Reinsert after remove`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<3>()

        try! dict.set("a", 1)
        try! dict.set("b", 2)

        dict.remove("a")
        try! dict.set("a", 100)

        // 'a' should be at the end now
        #expect(dict.index(of: "b") == 0)
        #expect(dict.index(of: "a") == 1)
        dict.withValue(forKey: "a") { value in
            #expect(value == 100)
        }
    }

    @Test
    func `Empty dictionary operations`() {
        var dict = Dictionary<String, Int>.Ordered.Inline<4>()

        let isEmpty = dict.isEmpty
        let count = dict.count
        let hasAny = dict.contains("any")
        let indexAny = dict.index(of: "any")
        let removeAny = dict.remove("any")
        let withAny = dict.withValue(forKey: "any") { _ in }

        #expect(isEmpty)
        #expect(count == 0)
        #expect(!hasAny)
        #expect(indexAny == nil)
        #expect(removeAny == nil)
        #expect(withAny == nil)
    }
}
