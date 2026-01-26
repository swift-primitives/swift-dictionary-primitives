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

public import Dictionary_Primitives_Core
public import Sequence_Primitives

// MARK: - Iterator

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: Copyable {
    /// Iterator for ordered dictionary.
    public struct Iterator: IteratorProtocol {
        public typealias Element = (key: Key, value: Value)

        @usableFromInline
        let _keys: Set<Key>.Ordered

        @usableFromInline
        let _valueStorage: Dictionary<Key, Value>.Ordered.ValueStorage

        @usableFromInline
        var _index: Int = 0

        @usableFromInline
        init(_ dict: borrowing Dictionary<Key, Value>.Ordered) {
            self._keys = dict._keys
            self._valueStorage = dict._valueStorage
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _index < _keys.count else { return nil }
            let key = _keys[_index]
            let value = _valueStorage._readValue(at: _index)
            _index += 1
            return (key, value)
        }
    }
}

// MARK: - Sequence.Protocol Conformance

/// Conformance to Sequence_Primitives.Sequence.Protocol.
///
/// This provides the core iteration capability. Swift.Sequence conformance
/// is declared separately as a bridge.
extension Dictionary_Primitives_Core.Dictionary.Ordered: Sequence.`Protocol` where Value: Copyable {
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        Iterator(self)
    }

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { count }
}

// MARK: - Swift.Sequence Conformance (Bridge)

/// Bridge to Swift.Sequence for `for-in` loops and stdlib algorithms.
///
/// Per [REFACTOR-002]: Swift.Sequence conformance is in a variant module
/// because it implicitly requires Element: Copyable.
extension Dictionary_Primitives_Core.Dictionary.Ordered: Swift.Sequence where Value: Copyable {}

// MARK: - Swift.Collection Conformance

extension Dictionary_Primitives_Core.Dictionary.Ordered: Swift.Collection where Value: Copyable {
    public typealias Index = Int

    @inlinable
    public var startIndex: Int { 0 }

    @inlinable
    public var endIndex: Int { count }

    @inlinable
    public subscript(position: Int) -> (key: Key, value: Value) {
        precondition(position >= 0 && position < count, "Index out of bounds")
        let key = _keys[position]
        let value = _valueStorage._readValue(at: position)
        return (key, value)
    }

    @inlinable
    public func index(after i: Int) -> Int {
        i + 1
    }
}

// MARK: - Swift.BidirectionalCollection Conformance

extension Dictionary_Primitives_Core.Dictionary.Ordered: Swift.BidirectionalCollection where Value: Copyable {
    @inlinable
    public func index(before i: Int) -> Int {
        i - 1
    }
}

// MARK: - Swift.RandomAccessCollection Conformance

extension Dictionary_Primitives_Core.Dictionary.Ordered: Swift.RandomAccessCollection where Value: Copyable {}
