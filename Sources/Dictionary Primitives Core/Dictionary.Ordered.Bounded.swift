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

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {

    /// A fixed-capacity ordered dictionary that throws on overflow.
    ///
    /// `Dictionary.Ordered.Bounded` allocates storage upfront and throws when
    /// inserting a key-value pair would exceed the capacity.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var dict = try Dictionary<String, Int>.Ordered.Bounded(capacity: 10)
    /// try dict.set("apple", 1)
    /// try dict.set("banana", 2)
    /// dict["apple"]  // Optional(1)
    /// ```
    ///
    /// ## Move-Only Support
    ///
    /// Both the dictionary and its values can be `~Copyable`:
    ///
    /// ```swift
    /// struct FileHandle: ~Copyable { ... }
    /// var dict = try Dictionary<String, FileHandle>.Ordered.Bounded(capacity: 5)
    /// try dict.set("primary", FileHandle())
    /// ```
    @safe
    public struct Bounded: ~Copyable {
        public var _keys: Set<Key>.Ordered

        public var _values: Buffer<Value>.Linear.Bounded

        /// The maximum number of key-value pairs the dictionary can hold.
        public let capacity: Index_Primitives.Index<Key>.Count

        /// Creates a bounded ordered dictionary with the specified capacity.
        ///
        /// - Parameter capacity: Maximum number of pairs. Must be non-negative.
        /// - Throws: ``Dictionary/Ordered/Bounded/Error/invalidCapacity`` if capacity is negative.
        @inlinable
        public init(capacity: Index_Primitives.Index<Key>.Count) throws(Dictionary_Primitives_Core.Dictionary<Key, Value>.Ordered.Bounded.Error) {
            self._keys = Set<Key>.Ordered()
            self._keys.reserve(capacity)
            self._values = Buffer<Value>.Linear.Bounded(minimumCapacity: capacity.retag(Value.self))
            self.capacity = capacity
        }

        // Note: No deinit needed - Buffer.Linear.Bounded handles cleanup
    }
}

// MARK: - Conditional Conformances

/// `Dictionary.Ordered.Bounded` is `Copyable` when its values are `Copyable`.
extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Copyable where Value: Copyable {}

// MARK: - Sendable

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: @unchecked Sendable where Key: Sendable, Value: Sendable {}
