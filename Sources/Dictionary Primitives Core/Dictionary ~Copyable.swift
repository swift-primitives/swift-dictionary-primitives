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

public import Buffer_Slab_Primitives
public import Hash_Table_Primitives
public import Index_Primitives

// MARK: - Properties (~Copyable)

extension Dictionary_Primitives_Core.Dictionary where Value: ~Copyable {
    /// The number of key-value pairs.
    @inlinable
    public var count: Index_Primitives.Index<Key>.Count {
        _keys.occupancy.retag(Key.self)
    }

    /// Whether the dictionary is empty.
    @inlinable
    public var isEmpty: Bool {
        _keys.isEmpty
    }
}

// MARK: - Clear (~Copyable)

extension Dictionary_Primitives_Core.Dictionary where Value: ~Copyable {
    /// Removes all key-value pairs.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current storage capacity.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        if keepingCapacity {
            _keys.removeAll()
            _values.removeAll()
            _hashTable.remove.all(keepingCapacity: true)
        } else {
            // Slab deinit handles element cleanup when replaced
            _keys = Buffer<Key>.Slab(minimumCapacity: .zero)
            _values = Buffer<Value>.Slab(minimumCapacity: _keys.capacity.retag(Value.self))
            _hashTable.remove.all(keepingCapacity: false)
        }
    }
}

// MARK: - forEach (~Copyable)

extension Dictionary_Primitives_Core.Dictionary where Value: ~Copyable {
    /// Non-mutating read-only view for forEach iteration.
    ///
    /// Uses `Property.Borrow` at the Dictionary level (not Slab level)
    /// so that both `_keys` and `_values` can be accessed through the pointer
    /// without borrow conflicts.
    ///
    /// - Complexity: O(n) where n is the number of pairs.
    @inlinable
    public var forEach: Property<Sequence.ForEach, Self>.Borrow {
        _read {
            yield Property<Sequence.ForEach, Self>.Borrow(self)
        }
    }

    /// Drains all key-value pairs from the dictionary, passing each to the closure.
    ///
    /// After this method returns, the dictionary is empty but still usable.
    /// Values are moved out (consumed).
    ///
    /// - Parameter body: A closure that receives each entry with ownership.
    /// - Complexity: O(n) where n is the number of pairs.
    @inlinable
    public mutating func drain(_ body: (consuming Entry) -> Void) {
        // Typed while loop: mutating during iteration requires manual control.
        // Early termination via remaining count avoids scanning vacant tail slots.
        var slot: Bit.Index = .zero
        let end = _keys.capacity.map(Ordinal.init)
        var remaining = _keys.occupancy
        while slot < end, remaining != .zero {
            if _keys.isOccupied(at: slot) {
                let key = _keys.remove(at: slot)
                let value = _values.remove(at: slot)
                body(Entry(key: key, value: consume value))
                remaining = remaining.subtract.saturating(.one)
            }
            slot += .one
        }
        _hashTable.remove.all(keepingCapacity: true)
    }
}

// MARK: - withValue (~Copyable)

extension Dictionary_Primitives_Core.Dictionary where Value: ~Copyable {
    /// Accesses the value for the given key via closure (for ~Copyable values).
    ///
    /// - Parameters:
    ///   - key: The key to look up.
    ///   - body: A closure that receives a borrowed reference to the value.
    /// - Returns: The result of the closure, or `nil` if the key doesn't exist.
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        guard
            let position = _hashTable.position(
                forHash: key.hashValue,
                equals: { position in
                    _keys[position.retag(Bit.self)] == key
                }
            )
        else { return nil }
        return body(_values[position.retag(Bit.self)])
    }
}

// MARK: - Growth

extension Dictionary_Primitives_Core.Dictionary where Value: ~Copyable {
    /// Grows the slab storage and rebuilds the hash table.
    ///
    /// Follows the Hash.Table.grow() capacity computation pattern.
    @usableFromInline
    mutating func _grow() {
        let occupancy = _keys.occupancy.retag(Key.self)
        let newCapacity = Index_Primitives.Index<Key>.Count.max(
            Index_Primitives.Index<Key>.Count(Cardinal(8 as UInt)),
            occupancy + occupancy
        )

        var newKeys = Buffer<Key>.Slab(minimumCapacity: newCapacity)
        // Use keys' actual capacity so values.capacity >= keys.capacity.
        // ManagedBuffer rounds up differently per element stride — without this,
        // a slot valid for keys could exceed values' bitmap bounds.
        var newValues = Buffer<Value>.Slab(minimumCapacity: newKeys.capacity.retag(Value.self))
        var newHashTable = Hash.Table<Key>(minimumCapacity: newCapacity)

        // Typed while loop: mutating during iteration requires manual control.
        // Early termination via remaining count avoids scanning vacant tail slots.
        var slot: Bit.Index = .zero
        let end = _keys.capacity.map(Ordinal.init)
        var remaining = _keys.occupancy
        while slot < end, remaining != .zero {
            if _keys.isOccupied(at: slot) {
                let key = _keys.remove(at: slot)
                let value = _values.remove(at: slot)

                guard let newSlot = newKeys.firstVacant() else {
                    fatalError("Insufficient capacity after growth")
                }
                newKeys.insert(key, at: newSlot)
                newValues.insert(consume value, at: newSlot)
                newHashTable.insert(
                    _unchecked: (),
                    position: newSlot.retag(Key.self),
                    hashValue: key.hashValue
                )
                remaining = remaining.subtract.saturating(.one)
            }
            slot += .one
        }

        _keys = newKeys
        _values = newValues
        _hashTable = newHashTable
    }
}
