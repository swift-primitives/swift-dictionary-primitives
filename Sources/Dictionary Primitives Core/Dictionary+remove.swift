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

public import Hash_Table_Primitives
public import Index_Primitives

// MARK: - Remove

extension Dictionary_Primitives_Core.Dictionary where Value: ~Copyable {
    /// Removes the value for the given key.
    ///
    /// Slab positions are stable — no element shifting occurs.
    /// This is the core O(1) advantage over `Dictionary.Ordered.remove`.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if the key was not present.
    /// - Complexity: O(1) average.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        let hashValue = key.hashValue

        guard
            let removedPosition = _hashTable.remove(
                hashValue: hashValue,
                equals: { position in
                    _keys[position.retag(Bit.self)] == key
                }
            )
        else {
            return nil
        }

        let slot = removedPosition.retag(Bit.self)
        _ = _keys.remove(at: slot)
        return _values.remove(at: slot)

        // NO _hashTable.positions.decrement(after:) — positions are stable!
    }
}
