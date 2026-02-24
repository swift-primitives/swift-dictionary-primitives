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
public import Index_Primitives

// MARK: - Drain Type

extension Dictionary_Primitives_Core.Dictionary where Value: ~Copyable {
    /// Type for drain operations on Dictionary.
    ///
    /// This type enables the `.drain { }` syntax while supporting `~Copyable` values.
    @safe
    public struct Drain: ~Copyable, ~Escapable {
        @usableFromInline
        internal let _base: UnsafeMutablePointer<Dictionary<Key, Value>>

        @inlinable
        @_lifetime(borrow base)
        internal init(_ base: UnsafeMutablePointer<Dictionary<Key, Value>>) {
            unsafe _base = base
        }

        /// Drain iteration: `.drain { }`
        ///
        /// Removes all key-value pairs from the dictionary, passing each to the closure
        /// as an `Entry` with ownership. After this call, the dictionary is empty but usable.
        /// Works for ALL value types including `~Copyable`.
        ///
        /// - Parameter body: A closure called with each entry (consuming).
        @_lifetime(&self)
        @inlinable
        public mutating func callAsFunction(_ body: (consuming Entry) -> Void) {
            // Typed while loop: mutating during iteration requires manual control.
            // Early termination via remaining count avoids scanning vacant tail slots.
            var slot: Bit.Index = .zero
            let end = unsafe _base.pointee._keys.capacity.map(Ordinal.init)
            var remaining = unsafe _base.pointee._keys.occupancy
            while slot < end, remaining != .zero {
                if unsafe _base.pointee._keys.isOccupied(at: slot) {
                    let key = unsafe _base.pointee._keys.remove(at: slot)
                    let value = unsafe _base.pointee._values.remove(at: slot)
                    body(Entry(key: key, value: consume value))
                    remaining = remaining.subtract.saturating(.one)
                }
                slot += .one
            }
            unsafe _base.pointee._hashTable.remove.all(keepingCapacity: true)
        }
    }
}

// MARK: - Drain Property Accessor

extension Dictionary_Primitives_Core.Dictionary where Value: ~Copyable {
    /// Property accessor for `.drain { }` syntax.
    ///
    /// Draining removes all key-value pairs from the dictionary, passing each to the closure
    /// as an `Entry`. The dictionary survives but is empty after draining.
    ///
    /// Works for ALL value types including `~Copyable`.
    ///
    /// ```swift
    /// var dict = Dictionary<String, Int>()
    /// dict.set("a", 1)
    /// dict.set("b", 2)
    /// dict.drain { entry in print("\(entry.key): \(entry.value)") }
    /// // dict is now empty but still usable
    /// ```
    ///
    /// - Complexity: O(n) where n is the number of elements.
    public var drain: Drain {
        mutating _read {
            yield unsafe Drain(&self)
        }
        mutating _modify {
            var view = unsafe Drain(&self)
            yield &view
        }
    }
}
