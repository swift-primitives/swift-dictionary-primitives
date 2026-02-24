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
public import Buffer_Slab_Primitives

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
            _values = Buffer<Value>.Slab(minimumCapacity: .zero)
            _hashTable.remove.all(keepingCapacity: false)
        }
    }
}

// MARK: - forEach (~Copyable)

extension Dictionary_Primitives_Core.Dictionary where Value: ~Copyable {
    /// Calls the given closure for each key-value pair.
    ///
    /// Elements are visited in no particular order (sparse slot order).
    /// Uses Wegner/Kernighan bit iteration — O(n) where n is the number of pairs.
    ///
    /// - Parameter body: A closure that receives each key and borrowed value.
    @inlinable
    public func forEach(_ body: (Key, borrowing Value) -> Void) {
        _keys.forEachOccupied { slot in
            body(_keys[slot], _values[slot])
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
        // The bitmap iteration state is captured by value, so modifications
        // to the slab during iteration are safe.
        var slot: Bit.Index = .zero
        let end = _keys.capacity.map(Ordinal.init)
        while slot < end {
            if _keys.isOccupied(at: slot) {
                let key = _keys.remove(at: slot)
                let value = _values.remove(at: slot)
                body(Entry(key: key, value: consume value))
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
        guard let position = _hashTable.position(forHash: key.hashValue, equals: { position in
            _keys[position.retag(Bit.self)] == key
        }) else { return nil }
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
        let newCapacity = Index_Primitives.Index<Key>.Count(
            Cardinal(UInt(max(8, Int(bitPattern: _keys.occupancy) * 2)))
        )

        var newKeys = Buffer<Key>.Slab(minimumCapacity: newCapacity)
        var newValues = Buffer<Value>.Slab(minimumCapacity: newCapacity.retag(Value.self))
        var newHashTable = Hash.Table<Key>(minimumCapacity: newCapacity)

        // Typed while loop: mutating during iteration requires manual control.
        var slot: Bit.Index = .zero
        let end = _keys.capacity.map(Ordinal.init)
        while slot < end {
            if _keys.isOccupied(at: slot) {
                let key = _keys.remove(at: slot)
                let value = _values.remove(at: slot)

                guard let newSlot = newKeys.firstVacant() else {
                    fatalError("Insufficient capacity after growth")
                }
                newKeys.insert(key, at: newSlot)
                newValues.insert(consume value, at: newSlot)
                newHashTable.insert(
                    __unchecked: (),
                    position: newSlot.retag(Key.self),
                    hashValue: key.hashValue
                )
            }
            slot += .one
        }

        _keys = newKeys
        _values = newValues
        _hashTable = newHashTable
    }
}
