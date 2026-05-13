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

import Buffer_Linear_Inline_Primitives
import Hash_Table_Primitives

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {

    // MARK: - Static (Fixed-Capacity, Inline Storage)

    /// A fixed-capacity, inline-storage ordered dictionary with compile-time capacity.
    ///
    /// `Dictionary.Ordered.Static` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter.
    public struct Static<let capacity: Int>: ~Copyable {
        /// Element cleanup is handled by Storage.Inline's deinit.

        /// Hash table for O(1) key lookup via open-addressed linear probing.
        /// Capacity must be a power of two.
        @usableFromInline
        package var _hashTable: Hash.Table<Key>.Static<capacity>

        /// Value storage using Buffer.Linear.Inline from buffer-primitives.
        @usableFromInline
        package var _values: Buffer<Value>.Linear.Inline<capacity>

        /// Dense key storage using Buffer.Linear.Inline.
        @usableFromInline
        package var _keys: Buffer<Key>.Linear.Inline<capacity>

        /// Creates an empty inline ordered dictionary.
        /// - Note: `capacity` must be a power of two (hash table requirement).
        @inlinable
        public init() {
            self._values = Buffer<Value>.Linear.Inline<capacity>()
            self._keys = Buffer<Key>.Linear.Inline<capacity>()
            self._hashTable = Hash.Table<Key>.Static<capacity>()
        }

    }
}

// MARK: - Sendable

extension Dictionary_Primitives_Core.Dictionary.Ordered.Static: @unsafe @unchecked Sendable where Key: Sendable, Value: Sendable {}
