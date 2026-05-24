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

extension Dictionary_Primitives_Core.Dictionary where Value: ~Copyable {

    /// An ordered dictionary that preserves insertion order, supporting move-only values.
    ///
    /// `Ordered` combines the key-value semantics of a dictionary with the ordering
    /// guarantees of an array. Key-value pairs are stored in insertion order and
    /// can be accessed by index.
    ///
    /// ## API
    ///
    /// Key operations use nested accessors:
    ///
    /// ```swift
    /// var dict = Dictionary<String, Int>.Ordered()
    ///
    /// // Value operations
    /// dict.values.set("apple", 1)
    /// dict.values.set("banana", 2)
    /// let removed = dict.values.remove("apple")
    ///
    /// // Key operations
    /// if let idx = dict.keys.index("banana") { ... }
    ///
    /// // Subscript access
    /// dict["cherry"] = 3
    /// let value = dict["cherry"]
    /// ```
    ///
    /// ## Ordering Semantics
    ///
    /// - Setting a new key adds to the end
    /// - Updating existing key does NOT move position
    /// - Removal shifts subsequent pairs (indices change)
    /// - Re-insertion after removal goes to end
    ///
    /// ## Move-Only Support
    ///
    /// Both the dictionary and its values can be `~Copyable`:
    ///
    /// ```swift
    /// struct FileHandle: ~Copyable { ... }
    /// var dict = Dictionary<String, FileHandle>.Ordered()
    /// dict.set("primary", FileHandle())
    /// ```
    ///
    /// Note: Keys must always be `Hashable` (which implies `Copyable`).
    ///
    /// ## Copy-on-Write
    ///
    /// When `Value` is `Copyable`, `Dictionary.Ordered` uses copy-on-write semantics:
    /// copies share storage until mutation.
    ///
    /// ## Thread Safety
    ///
    /// Not thread-safe for concurrent mutation. Synchronize externally.
    ///
    /// ## Complexity
    ///
    /// - Set/get/remove by key: O(1) average
    /// - Index lookup: O(1) average
    /// - Random access by index: O(1)
    ///
    /// ## Variants
    ///
    /// - ``Dictionary/Ordered``: Dynamically-growing storage (this type)
    /// - ``Dictionary/Ordered/Bounded``: Fixed-capacity, throws on overflow
    /// - ``Dictionary/Ordered/Inline``: Zero-allocation inline storage with compile-time capacity
    /// - ``Dictionary/Ordered/Small``: Inline storage with automatic spill to heap
    // WHY: Category D — structural Sendable workaround; the type is
    // WHY: structurally value-safe but the compiler cannot synthesize
    // WHY: Sendable due to a stored pointer / generic parameter shape.
    @safe
    public struct Ordered: ~Copyable {

        // MARK: - Value Storage
        //
        // Uses Buffer<Value>.Linear from Buffer Linear Primitives for value storage.
        // Buffer wraps Storage internally and provides the canonical data structure API.

        /// Typealias for value storage type.
        public typealias ValueStorage = Buffer<Value>.Linear

        public var _keys: Set<Key>.Ordered

        public var _values: Buffer<Value>.Linear

        /// Creates an empty ordered dictionary.
        @inlinable
        public init() {
            self._keys = Set<Key>.Ordered()
            self._values = Buffer<Value>.Linear(minimumCapacity: .zero)
        }

        // Note: No deinit needed - Buffer.Linear handles cleanup
    }
}

// MARK: - Conditional Conformances

/// `Dictionary.Ordered` is `Copyable` when its values are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Dictionary_Primitives_Core.Dictionary.Ordered: Copyable where Value: Copyable {}

// MARK: - Sendable

extension Dictionary_Primitives_Core.Dictionary.Ordered: @unsafe @unchecked Sendable where Key: Sendable, Value: Sendable {}
