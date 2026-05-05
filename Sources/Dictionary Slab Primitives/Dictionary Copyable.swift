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
internal import Index_Primitives
internal import Sequence_Primitives

// MARK: - Iterator

extension Dictionary_Primitives_Core.Dictionary where Value: Copyable {
    /// Iterator for unordered dictionary.
    ///
    /// Copies slab storage at creation for safe iteration independent of mutations.
    /// Visits occupied slots via bitmap iterator (Wegner/Kernighan bit extraction).
    ///
    /// - Complexity: O(count) total via bitmap iteration, not O(capacity).
    ///
    /// - Note: The iterator stores shallow reference copies of `Buffer.Slab` storage.
    ///   Without CoW on unordered `Dictionary` mutations, a stored iterator could observe
    ///   inconsistent state if the dictionary is mutated between `next()` calls. Safe
    ///   under `for-in` (borrow semantics prevent mutation during iteration).
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        public typealias Element = (key: Key, value: Value)

        @usableFromInline
        let _keys: Buffer<Key>.Slab

        @usableFromInline
        let _values: Buffer<Value>.Slab

        @usableFromInline
        var _occupiedSlots: Bit.Vector.Ones.Bounded.Iterator

        @usableFromInline
        var _element: Element? = nil

        @usableFromInline
        init(_ dict: borrowing Dictionary<Key, Value>) {
            let occupiedSlots = dict._keys.occupiedSlots
            self._keys = dict._keys
            self._values = dict._values
            self._occupiedSlots = occupiedSlots.makeIterator()
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
            guard let slot = _occupiedSlots.next() else { return nil }
            return (key: _keys[slot], value: _values[slot])
        }
    }
}

// MARK: - Sequence.Protocol Conformance

extension Dictionary_Primitives_Core.Dictionary: Sequence.`Protocol` where Value: Copyable {
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
extension Dictionary_Primitives_Core.Dictionary: Swift.Sequence where Value: Copyable {}

// MARK: - Sequence.Clearable Conformance

extension Dictionary_Primitives_Core.Dictionary: Sequence.Clearable where Value: Copyable {
    /// Removes all key-value pairs from the dictionary.
    ///
    /// This enables `.forEach.consuming { }` pattern via `Property.Inout` extension.
    @inlinable
    public mutating func removeAll() {
        clear(keepingCapacity: false)
    }
}

// MARK: - Subscript Access (Copyable)

extension Dictionary_Primitives_Core.Dictionary where Value: Copyable {
    /// Accesses the value for the given key.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The value if the key exists, or `nil`.
    @inlinable
    public subscript(key: Key) -> Value? {
        get {
            guard
                let position = _hashTable.position(
                    forHash: key.hashValue,
                    equals: { position in
                        _keys[position.retag(Bit.self)] == key
                    }
                )
            else { return nil }
            return _values[position.retag(Bit.self)]
        }
        set {
            if let newValue = newValue {
                set(key, newValue)
            } else {
                remove(key)
            }
        }
    }
}
