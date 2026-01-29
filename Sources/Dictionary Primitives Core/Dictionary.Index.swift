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

public import Index_Primitives
public import Set_Primitives

extension Dictionary {
    /// Type-safe index for dictionary entries.
    ///
    /// Uses `Index<Key>` to provide compile-time safety preventing
    /// cross-collection index confusion. The index is parameterized on Key
    /// since tuples with ~Copyable elements are not supported.
    ///
    /// ## Position Semantics
    ///
    /// Position 0 is the first entry in insertion order.
    /// Position `count - 1` is the most recently inserted entry.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let dictIdx: Dictionary<String, Int>.Index = 0
    /// var dict = Dictionary<String, Int>.Ordered()
    /// dict["apple"] = 1
    /// // Access first entry via index
    /// ```
    public typealias Index = Index_Primitives.Index<Key>
}

// MARK: - Typed Access (Dictionary.Ordered)

extension Dictionary.Ordered where Value: Copyable {
    /// Accesses the key at the given typed index.
    ///
    /// - Parameter index: The typed index of the entry to access.
    /// - Precondition: `index.position` must be in `0..<count`.
    @inlinable
    public func key(at index: Dictionary<Key, Value>.Index) -> Key {
        let pos = Int(bitPattern: index.position)
        precondition(pos >= 0 && pos < count, "Index out of bounds")
        return _keys[pos]
    }

    /// Accesses the value at the given typed index.
    ///
    /// - Parameter index: The typed index of the entry to access.
    /// - Precondition: `index.position` must be in `0..<count`.
    @inlinable
    public func value(at index: Dictionary<Key, Value>.Index) -> Value {
        let pos = Int(bitPattern: index.position)
        precondition(pos >= 0 && pos < count, "Index out of bounds")
        return unsafe _cachedValuePtr[pos]
    }

    /// Returns the key-value pair at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the entry to access.
    /// - Returns: The key-value pair at the index, or `nil` if out of bounds.
    @inlinable
    public func entry(at index: Dictionary<Key, Value>.Index) -> (key: Key, value: Value)? {
        let pos = Int(bitPattern: index.position)
        guard pos >= 0 && pos < count else { return nil }
        let key = _keys[pos]
        return unsafe (key, _cachedValuePtr[pos])
    }
}
