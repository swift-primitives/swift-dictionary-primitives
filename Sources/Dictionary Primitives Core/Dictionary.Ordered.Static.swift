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
        /// Value storage using Buffer.Linear.Inline from buffer-primitives.
        @usableFromInline
        package var _values: Buffer<Value>.Linear.Inline<capacity>

        /// Dense key storage using Buffer.Linear.Inline.
        @usableFromInline
        package var _keys: Buffer<Key>.Linear.Inline<capacity>

        /// Hash table for O(1) key lookup via open-addressed linear probing.
        /// Capacity must be a power of two.
        @usableFromInline
        package var _hashTable: Hash.Table<Key>.Static<capacity>

        // WORKAROUND: swiftlang/swift#86652 — @_rawLayout triviality misclassification.
        // Forces compiler to recognize type as non-trivially destructible so deinit executes.
        // COST: 8 bytes overhead per instance.
        // REMOVAL TEST: swift-buffer-primitives/Experiments/rawlayout-access-level-trigger/
        //   Build with `public` access under -O. If it passes, remove this field
        //   and the manual cleanup in deinit.
        // TRACKING: swift-buffer-primitives/Research/rawlayout-release-crash-investigation.md
        private var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty inline ordered dictionary.
        /// - Note: `capacity` must be a power of two (hash table requirement).
        @inlinable
        public init() {
            self._values = Buffer<Value>.Linear.Inline<capacity>()
            self._keys = Buffer<Key>.Linear.Inline<capacity>()
            self._hashTable = Hash.Table<Key>.Static<capacity>()
        }

        deinit {
            // WORKAROUND: Manually clean up elements via the mutating path.
            // TRACKING: swiftlang/swift #86652 variant
            unsafe withUnsafePointer(to: _values) { ptr in
                unsafe UnsafeMutablePointer(mutating: ptr).pointee.remove.all()
            }
            unsafe withUnsafePointer(to: _keys) { ptr in
                unsafe UnsafeMutablePointer(mutating: ptr).pointee.remove.all()
            }
        }
    }
}

// MARK: - Sendable

extension Dictionary_Primitives_Core.Dictionary.Ordered.Static: @unchecked Sendable where Key: Sendable, Value: Sendable {}
