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

public import Buffer_Linear_Primitive
public import Buffer_Linear_Bounded_Primitive
public import Dictionary_Primitives_Core
public import Index_Primitives
internal import Sequence_Primitives

// MARK: - Iterator

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded where Value: Copyable {
    /// Iterator for bounded ordered dictionary.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        public typealias Element = (key: Key, value: Value)

        @usableFromInline
        let _keys: Set<Key>.Ordered

        @usableFromInline
        let _values: Buffer<Value>.Linear.Bounded

        @usableFromInline
        var _index: Index_Primitives.Index<Key>

        @usableFromInline
        let _count: Index_Primitives.Index<Key>.Count

        @usableFromInline
        var _element: Element? = nil

        @usableFromInline
        init(_ dict: borrowing Dictionary<Key, Value>.Ordered.Bounded) {
            self._keys = dict._keys
            self._values = dict._values
            self._index = .zero
            self._count = dict.count
        }

        @_lifetime(&self)
        @inlinable
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            let ptr = unsafe withUnsafeMutablePointer(to: &_element) { p in
                unsafe UnsafePointer<Element>(
                    unsafe UnsafeRawPointer(p).assumingMemoryBound(to: Element.self)
                )
            }
            guard maximumCount > .zero else {
                let span = unsafe Span(_unsafeStart: ptr, count: 0)
                return unsafe _overrideLifetime(span, mutating: &self)
            }
            guard let value = next() else {
                let span = unsafe Span(_unsafeStart: ptr, count: 0)
                return unsafe _overrideLifetime(span, mutating: &self)
            }
            _element = value
            let span = unsafe Span(_unsafeStart: ptr, count: 1)
            return unsafe _overrideLifetime(span, mutating: &self)
        }

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
extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Sequence.`Protocol` where Value: Copyable {
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
extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Swift.Sequence where Value: Copyable {}

// MARK: - Swift.Collection Conformance

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Swift.Collection where Value: Copyable {
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

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Swift.BidirectionalCollection where Value: Copyable {
    @inlinable
    public func index(before i: Int) -> Int {
        i - 1
    }
}

// MARK: - Swift.RandomAccessCollection Conformance

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Swift.RandomAccessCollection where Value: Copyable {}

// MARK: - Sequence.Clearable Conformance

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Sequence.Clearable where Value: Copyable {
    /// Removes all key-value pairs from the dictionary.
    ///
    /// This enables `.forEach.consuming { }` pattern via `Property.Inout` extension.
    @inlinable
    public mutating func removeAll() {
        clear()
    }
}
