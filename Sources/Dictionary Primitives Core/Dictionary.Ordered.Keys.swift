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

public import Set_Primitives
public import Index_Primitives

// MARK: - Keys Accessor

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Nested accessor for key operations.
    ///
    /// ```swift
    /// if let idx = dict.keys.index("apple") { ... }
    /// let allKeys = dict.keys.all
    /// ```
    @inlinable
    public var keys: Keys {
        Keys(keys: _keys)
    }
}

// MARK: - Keys Type

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Namespace for key operations.
    ///
    /// Keys are always `Copyable` since `Key: Hashable` implies `Copyable`.
    public struct Keys {
        @usableFromInline
        let _keys: Set<Key>.Ordered

        @usableFromInline
        init(keys: Set<Key>.Ordered) {
            self._keys = keys
        }
    }
}

// MARK: - Keys Operations

extension Dictionary_Primitives_Core.Dictionary.Ordered.Keys where Value: ~Copyable {
    /// Returns the index of the given key, or `nil` if not present.
    ///
    /// - Parameter key: The key to find.
    /// - Returns: The typed index of the key.
    /// - Complexity: O(1) average.
    @inlinable
    public func index(_ key: Key) -> Index_Primitives.Index<Key>? {
        _keys.index(key)
    }

    /// All keys in order.
    @inlinable
    public var all: Set<Key>.Ordered {
        _keys
    }

    /// The number of keys.
    @inlinable
    public var count: Index_Primitives.Index<Key>.Count {
        _keys.count
    }

    /// Whether the keys collection is empty.
    @inlinable
    public var isEmpty: Bool {
        _keys.isEmpty
    }

    /// The key at the given typed index.
    ///
    /// - Parameter index: The typed index.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public subscript(_ index: Index_Primitives.Index<Key>) -> Key {
        _keys[index]
    }

    /// The key at the given raw index (stdlib compatibility).
    @inlinable
    public subscript(raw index: Int) -> Key {
        let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(index)))
        return _keys[keyIndex]
    }

    /// Returns whether the given key exists.
    @inlinable
    public func contains(_ key: Key) -> Bool {
        _keys.contains(key)
    }
}

// MARK: - Sequence Conformance

extension Dictionary_Primitives_Core.Dictionary.Ordered.Keys: Swift.Sequence {
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        var base: Set<Key>.Ordered.Iterator

        @usableFromInline
        init(_ keys: Set<Key>.Ordered) {
            self.base = keys.makeIterator()
        }

        @inlinable
        public mutating func next() -> Key? {
            base.next()
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_keys)
    }
}

extension Dictionary_Primitives_Core.Dictionary.Ordered.Keys.Iterator: Sendable where Key: Sendable {}
