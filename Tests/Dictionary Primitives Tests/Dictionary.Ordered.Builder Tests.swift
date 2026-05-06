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

// MARK: - Test Suite Structure

@Suite("Dictionary.Ordered.Builder")
struct DictionaryOrderedBuilderTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite struct StaticMethods {}
}

// MARK: - Helpers

extension DictionaryOrderedBuilderTests {
    fileprivate static func collected<K: Hash.`Protocol` & Copyable, V: Copyable & Equatable>(
        _ dict: borrowing Dictionary<K, V>.Ordered
    ) -> [(K, V)] {
        var result: [(K, V)] = []
        let keys = dict._keys
        try! keys.forEach { key in
            if let v = dict[key] {
                result.append((key, v))
            }
        }
        return result
    }
}

// MARK: - Unit Tests

extension DictionaryOrderedBuilderTests.Unit {

    @Test
    func `Single key-value expression`() {
        let dict = Dictionary<String, Int>.Ordered {
            ("alpha", 1)
        }
        #expect(dict["alpha"] == 1)
    }

    @Test
    func `Multiple pairs preserve insertion order`() {
        let dict = Dictionary<String, Int>.Ordered {
            ("first", 1)
            ("second", 2)
            ("third", 3)
        }
        let entries = DictionaryOrderedBuilderTests.collected(dict)
        #expect(entries.map { $0.0 } == ["first", "second", "third"])
        #expect(entries.map { $0.1 } == [1, 2, 3])
    }

    @Test
    func `Duplicate keys - last write wins`() {
        let dict = Dictionary<String, Int>.Ordered {
            ("a", 1)
            ("b", 2)
            ("a", 99)  // duplicate — overwrites
        }
        #expect(dict["a"] == 99)
        #expect(dict["b"] == 2)
    }

    @Test
    func `Optional pair - some`() {
        let pair: (String, Int)? = ("x", 42)
        let dict = Dictionary<String, Int>.Ordered { pair }
        #expect(dict["x"] == 42)
    }

    @Test
    func `Optional pair - none`() {
        let pair: (String, Int)? = nil
        let dict = Dictionary<String, Int>.Ordered { pair }
        #expect(dict.isEmpty)
    }

    @Test
    func `Empty block`() {
        let dict = Dictionary<String, Int>.Ordered {}
        #expect(dict.isEmpty)
    }

    @Test
    func `Int keys`() {
        let dict = Dictionary<Int, String>.Ordered {
            (1, "one")
            (2, "two")
            (3, "three")
        }
        #expect(dict[2] == "two")
    }
}

// MARK: - Control Flow

extension DictionaryOrderedBuilderTests.Unit {

    @Test
    func `Conditional include`() {
        let include = true
        let dict = Dictionary<String, Int>.Ordered {
            ("a", 1)
            if include {
                ("b", 2)
            }
            ("c", 3)
        }
        #expect(dict["b"] == 2)
        #expect(dict["c"] == 3)
    }

    @Test
    func `Conditional exclude`() {
        let include = false
        let dict = Dictionary<String, Int>.Ordered {
            ("a", 1)
            if include {
                ("b", 2)
            }
            ("c", 3)
        }
        #expect(dict["b"] == nil)
        #expect(dict["a"] == 1)
        #expect(dict["c"] == 3)
    }

    @Test
    func `For loop generates pairs`() {
        let dict = Dictionary<Int, Int>.Ordered {
            for i in 1...5 {
                (i, i * 10)
            }
        }
        for i in 1...5 {
            #expect(dict[i] == i * 10)
        }
    }
}

// MARK: - Edge Cases

extension DictionaryOrderedBuilderTests.EdgeCase {

    @Test
    func `Many entries`() {
        let dict = Dictionary<Int, Int>.Ordered {
            for i in 0..<20 {
                (i, i * 2)
            }
        }
        for i in 0..<20 {
            #expect(dict[i] == i * 2)
        }
    }

    @Test
    func `All same key collapses`() {
        let dict = Dictionary<String, Int>.Ordered {
            ("k", 1)
            ("k", 2)
            ("k", 3)
            ("k", 99)
        }
        #expect(dict["k"] == 99)
    }
}

// MARK: - Integration

extension DictionaryOrderedBuilderTests.Integration {

    @Test
    func `Builder result accepts further sets`() {
        var dict = Dictionary<String, Int>.Ordered {
            ("a", 1)
            ("b", 2)
        }
        dict.set("c", 3)
        #expect(dict["c"] == 3)
        #expect(dict["a"] == 1)
    }

    @Test
    func `Builder result supports lookup`() {
        let dict = Dictionary<String, Int>.Ordered {
            ("apple", 100)
            ("banana", 200)
        }
        #expect(dict["apple"] == 100)
        #expect(dict["banana"] == 200)
        #expect(dict["cherry"] == nil)
    }
}

// MARK: - Static Method Tests

extension DictionaryOrderedBuilderTests.StaticMethods {

    @Test
    func `buildExpression single pair`() {
        let result = Dictionary<String, Int>.Ordered.Builder.buildExpression(("a", 1))
        #expect(result.count == 1)
        #expect(result[0].0 == "a")
        #expect(result[0].1 == 1)
    }

    @Test
    func `buildPartialBlock accumulated and next`() {
        let result = Dictionary<String, Int>.Ordered.Builder.buildPartialBlock(
            accumulated: [("a", 1), ("b", 2)],
            next: [("c", 3)]
        )
        #expect(result.count == 3)
    }

    @Test
    func `buildArray flattens nested arrays`() {
        let result = Dictionary<String, Int>.Ordered.Builder.buildArray([
            [("a", 1)],
            [("b", 2), ("c", 3)],
        ])
        #expect(result.count == 3)
    }
}
