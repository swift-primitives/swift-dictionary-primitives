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

// MARK: - Note on Swift.Collection Conformances
//
// Swift.Sequence/Collection conformances are defined in Dictionary Primitives Core
// alongside the type definitions. This is required for proper witness table generation.
//
// This module provides drain functionality to support ~Copyable values via Entry struct.
// Uses a dedicated Drain type (similar to Array primitives pattern) because
// Dictionary has two generic parameters (Key, Value) which complicates Property.View.Typed usage.

// MARK: - Drain Type

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Type for drain operations on Dictionary.Ordered.
    ///
    /// This type enables the `.drain { }` syntax while supporting `~Copyable` values.
    @safe
    public struct Drain: ~Copyable, ~Escapable {
        @usableFromInline
        internal let _base: UnsafeMutablePointer<Dictionary<Key, Value>.Ordered>

        @inlinable
        @_lifetime(borrow base)
        internal init(_ base: UnsafeMutablePointer<Dictionary<Key, Value>.Ordered>) {
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
            let end = unsafe _base.pointee._keys.count.map(Ordinal.init)
            guard end > .zero else { return }
            var idx: Index_Primitives.Index<Key> = .zero
            while idx < end {
                body(Entry(key: unsafe _base.pointee._keys[idx], value: unsafe _base.pointee._values.consumeFront()))
                idx += .one
            }
            unsafe _base.pointee._keys.clear(keepingCapacity: true)
        }
    }
}

// MARK: - Drain Property Accessor

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Property accessor for `.drain { }` syntax.
    ///
    /// Draining removes all key-value pairs from the dictionary, passing each to the closure
    /// as an `Entry`. The dictionary survives but is empty after draining.
    ///
    /// Works for ALL value types including `~Copyable`.
    ///
    /// ```swift
    /// var dict = Dictionary<String, Int>.Ordered()
    /// dict.set("a", 1)
    /// dict.set("b", 2)
    /// dict.drain { entry in print("\(entry.key): \(entry.value)") }
    /// // prints "a: 1" and "b: 2"
    /// // dict is now empty but still usable
    /// dict.set("c", 3)  // OK
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
