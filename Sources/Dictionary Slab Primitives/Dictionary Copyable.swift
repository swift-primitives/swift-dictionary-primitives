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

extension Dictionary_Primitives_Core.Dictionary where Value: Copyable {
    /// Iterator for unordered dictionary.
    ///
    /// Copies slab storage at creation for safe iteration independent of mutations.
    /// Visits occupied slots via bitmap iteration.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        public typealias Element = (key: Key, value: Value)

        @usableFromInline
        let _keys: Buffer<Key>.Slab

        @usableFromInline
        let _values: Buffer<Value>.Slab

        @usableFromInline
        var _slot: Bit.Index

        @usableFromInline
        let _capacity: Bit.Index

        @usableFromInline
        init(_ dict: borrowing Dictionary<Key, Value>) {
            self._keys = dict._keys
            self._values = dict._values
            self._slot = .zero
            self._capacity = dict._keys.capacity.map(Ordinal.init)
        }

        @inlinable
        public mutating func next() -> Element? {
            while _slot < _capacity {
                let current = _slot
                _slot += .one
                if _keys.isOccupied(at: current) {
                    return (key: _keys[current], value: _values[current])
                }
            }
            return nil
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
    /// This enables `.forEach.consuming { }` pattern via `Property.View` extension.
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
            guard let position = _hashTable.position(forHash: key.hashValue, equals: { position in
                _keys[position.retag(Bit.self)] == key
            }) else { return nil }
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
