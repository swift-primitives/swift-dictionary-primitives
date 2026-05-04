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
public import Hash_Table_Primitives

// MARK: - Set (Insert / Update)

extension Dictionary_Primitives_Core.Dictionary where Value: ~Copyable {
    /// Sets the value for the given key, inserting if new or updating if existing.
    ///
    /// - Parameters:
    ///   - key: The key.
    ///   - value: The value to associate with the key.
    /// - Complexity: O(1) amortized.
    @inlinable
    public mutating func set(_ key: Key, _ value: consuming Value) {
        let hashValue = key.hashValue

        if let existingPosition = _hashTable.position(forHash: hashValue, equals: { position in
            _keys[position.retag(Bit.self)] == key
        }) {
            // Update: replace value at existing slot
            let slot = existingPosition.retag(Bit.self)
            _ = _values.update(at: slot, with: value)
        } else {
            // Insert new entry
            if _keys.isFull {
                _grow()
            }
            guard let slot = _keys.firstVacant() else {
                fatalError("No vacant slot after growth")
            }
            _keys.insert(key, at: slot)
            _values.insert(consume value, at: slot)
            _hashTable.insert(
                _unchecked: (),
                position: slot.retag(Key.self),
                hashValue: hashValue
            )
        }
    }
}
