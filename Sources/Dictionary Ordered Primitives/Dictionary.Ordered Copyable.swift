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
public import Index_Primitives

// MARK: - Iterator

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: Copyable {
    /// Iterator for ordered dictionary.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        public typealias Element = (key: Key, value: Value)

        @usableFromInline
        let _keys: Set<Key>.Ordered

        @usableFromInline
        let _values: Buffer<Value>.Linear

        @usableFromInline
        var _index: Index_Primitives.Index<Key>

        @usableFromInline
        let _count: Index_Primitives.Index<Key>.Count

        @usableFromInline
        var _spanBuffer: [Element] = []

        @usableFromInline
        init(_ dict: borrowing Dictionary<Key, Value>.Ordered) {
            self._keys = dict._keys
            self._values = dict._values
            self._index = .zero
            self._count = dict.count
        }

        @_lifetime(&self)
        @inlinable
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            _spanBuffer.removeAll(keepingCapacity: true)
            var remaining = Int(maximumCount.rawValue)
            while remaining > 0, _index < _count {
                let key = _keys[_index]
                let value = _values[_index.retag(Value.self)]
                _index = _index + .one
                _spanBuffer.append((key, value))
                remaining -= 1
            }
            return _spanBuffer.span
        }

        @_lifetime(self: immortal)
        @inlinable
        public mutating func next() -> Element? {
            guard _index < _count else { return nil }
            let key = _keys[_index]
            let value = _values[_index.retag(Value.self)]
            _index = _index + .one
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
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// MARK: - Swift.Sequence Conformance (Bridge)

/// Bridge to Swift.Sequence for `for-in` loops and stdlib algorithms.
///
/// Per [REFACTOR-002]: Swift.Sequence conformance is in a variant module
/// because it implicitly requires Element: Copyable.
extension Dictionary_Primitives_Core.Dictionary.Ordered: Swift.Sequence where Value: Copyable {}

// MARK: - Typed Element Access (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: Copyable {
    /// Returns the key-value pair at the typed index, with typed error on bounds failure.
    ///
    /// - Parameter index: The typed index of the pair to access.
    /// - Returns: The key-value pair at the index.
    /// - Throws: ``Dictionary/Ordered/Error/bounds(_:)`` if the index is out of bounds.
    @inlinable
    public func element(at index: Index_Primitives.Index<Key>) throws(__DictionaryOrderedError<Key>) -> (key: Key, value: Value) {
        guard index < _keys.count else {
            throw .bounds(.init(index: index, count: _keys.count))
        }
        return (key: _keys[index], value: _values[index.retag(Value.self)])
    }
}

// MARK: - Swift.Collection Conformance

extension Dictionary_Primitives_Core.Dictionary.Ordered: Swift.Collection where Value: Copyable {
    public typealias Index = Int

    @inlinable
    public var startIndex: Int { 0 }

    @inlinable
    public var endIndex: Int { Int(bitPattern: count) }

    @inlinable
    public subscript(position: Int) -> (key: Key, value: Value) {
        let countInt = Int(bitPattern: count)
        precondition(position >= 0 && position < countInt, "Index out of bounds")
        let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(position)))
        let key = _keys[keyIndex]
        let valueIndex = Index_Primitives.Index<Value>(Ordinal(UInt(position)))
        let value = _values[valueIndex]
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

// MARK: - Sequence.Clearable Conformance

extension Dictionary_Primitives_Core.Dictionary.Ordered: Sequence.Clearable where Value: Copyable {
    /// Removes all key-value pairs from the dictionary.
    ///
    /// This enables `.forEach.consuming { }` pattern via `Property.View` extension.
    @inlinable
    public mutating func removeAll() {
        clear(keepingCapacity: false)
    }
}
