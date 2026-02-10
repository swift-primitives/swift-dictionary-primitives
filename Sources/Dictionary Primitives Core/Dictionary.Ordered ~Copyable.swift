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

// MARK: - Initialization (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Creates an ordered dictionary with reserved capacity.
    ///
    /// Pre-allocates storage for the specified number of elements.
    ///
    /// - Parameter capacity: Number of elements to reserve space for.
    @inlinable
    public init(reservingCapacity capacity: Index_Primitives.Index<Key>.Count) throws(Error) {
        self._keys = Set<Key>.Ordered()
        self._keys.reserve(capacity)
        self._values = Buffer<Value>.Linear(minimumCapacity: capacity.retag(Value.self))
    }
}

// MARK: - Properties (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// The number of key-value pairs.
    @inlinable
    public var count: Index_Primitives.Index<Key>.Count {
        _keys.count
    }

    /// Whether the dictionary is empty.
    @inlinable
    public var isEmpty: Bool {
        _keys.isEmpty
    }

    /// The current capacity.
    @inlinable
    public var capacity: Index_Primitives.Index<Key>.Count {
        _values.capacity.retag(Key.self)
    }
}

// MARK: - Contains (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Returns whether the dictionary contains the given key.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if the key exists.
    @inlinable
    public func contains(_ key: Key) -> Bool {
        _keys.contains(key)
    }
}

// MARK: - Capacity Management (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Ensures the dictionary has capacity for at least the specified number of elements.
    @usableFromInline
    mutating func ensureCapacity(_ minimumCapacity: Index_Primitives.Index<Key>.Count) {
        _values.reserveCapacity(minimumCapacity.retag(Value.self))
    }

    /// Reserves enough space for the specified number of pairs.
    ///
    /// - Parameter minimumCapacity: The minimum number of pairs.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Index_Primitives.Index<Key>.Count) {
        _keys.reserve(minimumCapacity)
        ensureCapacity(minimumCapacity)
    }
}

// MARK: - Core Operations (~Copyable - Base)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Sets the value for the given key.
    ///
    /// - Parameters:
    ///   - key: The key.
    ///   - value: The value to associate with the key.
    /// - Complexity: O(1) amortized.
    @inlinable
    public mutating func set(_ key: Key, _ value: consuming Value) {
        if let existingKeyIndex = _keys.index(key) {
            let valueIndex = existingKeyIndex.retag(Value.self)
            _ = _values.replace(at: valueIndex, with: value)
        } else {
            _keys.insert(key)
            _values.append(value)
        }
    }

    /// Removes the value for the given key.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if not present.
    /// - Complexity: O(n) due to index shifting.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        guard let keyIndex = _keys.index(key) else { return nil }
        let valueIndex = keyIndex.retag(Value.self)
        _keys.remove(key)
        return _values.remove(at: valueIndex)
    }

    /// Removes all key-value pairs.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        _keys.clear(keepingCapacity: keepingCapacity)
        _values.removeAll()
        if !keepingCapacity {
            _values = Buffer<Value>.Linear(minimumCapacity: .zero)
        }
    }
}

// MARK: - Peek (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Accesses the value for the given key via closure (for ~Copyable values).
    ///
    /// - Parameters:
    ///   - key: The key to look up.
    ///   - body: A closure that receives a borrowed reference to the value.
    /// - Returns: The result of the closure, or `nil` if the key doesn't exist.
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        guard let keyIndex = _keys.index(key) else { return nil }
        return body(_values[keyIndex.retag(Value.self)])
    }

    /// Accesses the value at the given index via closure (for ~Copyable values).
    ///
    /// - Parameters:
    ///   - index: The typed index.
    ///   - body: A closure that receives a borrowed reference to the value.
    /// - Returns: The result of the closure.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withValue<R>(at index: Index_Primitives.Index<Key>, _ body: (borrowing Value) -> R) -> R {
        precondition(index < _keys.count, "Index out of bounds")
        return body(_values[index.retag(Value.self)])
    }

    /// Accesses the value at the given index via closure, with typed error on bounds failure.
    ///
    /// - Parameters:
    ///   - index: The typed index.
    ///   - body: A closure that receives a borrowed reference to the value.
    /// - Returns: The result of the closure.
    /// - Throws: ``Dictionary/Ordered/Error/bounds(_:)`` if the index is out of bounds.
    @inlinable
    public func withValue<R>(at index: Index_Primitives.Index<Key>, _ body: (borrowing Value) throws(__DictionaryOrderedError<Key>) -> R) throws(__DictionaryOrderedError<Key>) -> R {
        guard index < _keys.count else {
            throw .bounds(.init(index: index, count: _keys.count))
        }
        return try body(_values[index.retag(Value.self)])
    }
}

// MARK: - forEach (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Calls the given closure for each key-value pair in the dictionary.
    ///
    /// Elements are visited in insertion order.
    ///
    /// - Parameter body: A closure that receives each key and borrowed value.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach(_ body: (Key, borrowing Value) -> Void) {
        var idx: Index_Primitives.Index<Key> = .zero
        let end = _keys.count.map(Ordinal.init)
        while idx < end {
            body(_keys[idx], _values[idx.retag(Value.self)])
            idx += .one
        }
    }

    /// Drains all key-value pairs from the dictionary, passing each to the closure.
    ///
    /// After this method returns, the dictionary is empty but still usable.
    /// Entries are visited in insertion order. Values are moved out (consumed).
    ///
    /// - Parameter body: A closure that receives each entry with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Entry) -> Void) {
        var idx: Index_Primitives.Index<Key> = .zero
        let end = _keys.count.map(Ordinal.init)
        while idx < end {
            body(Entry(key: _keys[idx], value: _values.consumeFront()))
            idx += .one
        }
        _keys.clear(keepingCapacity: true)
    }
}

// MARK: - Bounded Variant (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded where Value: ~Copyable {
    /// Errors that can occur during bounded ordered dictionary operations.
    public typealias Error = __DictionaryOrderedBoundedError<Key>

    /// The number of key-value pairs.
    @inlinable
    public var count: Index_Primitives.Index<Key>.Count { _keys.count }

    /// Whether the dictionary is empty.
    @inlinable
    public var isEmpty: Bool { _keys.isEmpty }

    /// Whether the dictionary is at capacity.
    @inlinable
    public var isFull: Bool { _keys.count >= capacity }

    /// Returns whether the dictionary contains the given key.
    @inlinable
    public func contains(_ key: Key) -> Bool {
        _keys.contains(key)
    }

    /// Sets a value for the given key.
    ///
    /// - Parameters:
    ///   - key: The key.
    ///   - value: The value to associate with the key.
    /// - Throws: ``Dictionary/Ordered/Bounded/Error/overflow`` if the dictionary is full
    ///   and the key is new.
    @inlinable
    public mutating func set(_ key: Key, _ value: consuming Value) throws(Error) {
        if let existingKeyIndex = _keys.index(key) {
            let valueIndex = existingKeyIndex.retag(Value.self)
            _ = _values.replace(at: valueIndex, with: value)
        } else {
            guard _keys.count < capacity else {
                throw .overflow
            }
            _keys.insert(key)
            _ = _values.append(value)
        }
    }

    /// Removes a key-value pair.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if the key was not present.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        guard let keyIndex = _keys.index(key) else { return nil }
        let valueIndex = keyIndex.retag(Value.self)
        _keys.remove(key)
        return _values.remove(at: valueIndex)
    }

    /// Removes all key-value pairs.
    @inlinable
    public mutating func clear() {
        _keys.clear(keepingCapacity: true)
        _values.removeAll()
    }

    /// Accesses the value for the given key via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        guard let keyIndex = _keys.index(key) else { return nil }
        return body(_values[keyIndex.retag(Value.self)])
    }

    /// Accesses the value at the given typed index via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(at index: Index_Primitives.Index<Key>, _ body: (borrowing Value) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(_values[index.retag(Value.self)])
    }

    /// Accesses the value at the given typed index via closure, with typed error on bounds failure.
    @inlinable
    public func withValue<R>(at index: Index_Primitives.Index<Key>, _ body: (borrowing Value) throws(__DictionaryOrderedBoundedError<Key>) -> R) throws(__DictionaryOrderedBoundedError<Key>) -> R {
        guard index < count else {
            throw .bounds(index: index, count: count)
        }
        return try body(_values[index.retag(Value.self)])
    }
}

// MARK: - Inline Variant (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Static where Value: ~Copyable {
    /// Errors that can occur during inline ordered dictionary operations.
    public typealias Error = __DictionaryOrderedInlineError<Key>

    /// The number of key-value pairs.
    @inlinable
    public var count: Index_Primitives.Index<Key>.Count { _keys.count }

    /// Whether the dictionary is empty.
    @inlinable
    public var isEmpty: Bool { _hashTable.isEmpty }

    /// Whether the dictionary is at capacity.
    @inlinable
    public var isFull: Bool { _hashTable.isFull }

    /// Returns whether the dictionary contains the given key.
    /// - Complexity: O(1) average via hash table lookup.
    @inlinable
    public func contains(_ key: Key) -> Bool {
        let hashValue = key.hashValue
        return _hashTable.contains(hashValue: hashValue, equals: { idx in
            _keys[idx] == key
        })
    }

    /// Returns the bounded index of the given key, or nil if not present.
    /// - Complexity: O(1) average via hash table lookup.
    @inlinable
    public func index(of key: Key) -> Index_Primitives.Index<Key>.Bounded<capacity>? {
        let hashValue = key.hashValue
        return _hashTable.position(forHash: hashValue, equals: { idx in
            _keys[idx] == key
        })
    }

    /// Sets a value for the given key.
    ///
    /// - Parameters:
    ///   - key: The key.
    ///   - value: The value to associate with the key.
    /// - Throws: ``Dictionary/Ordered/Inline/Error/overflow`` if the dictionary is full
    ///   and the key is new.
    @inlinable
    public mutating func set(_ key: Key, _ value: consuming Value) throws(Error) {
        let hashValue = key.hashValue

        if let existingPosition = _hashTable.position(forHash: hashValue, equals: { idx in
            _keys[idx] == key
        }) {
            let valueIndex = Index_Primitives.Index<Key>(existingPosition).retag(Value.self)
            _ = _values.replace(at: valueIndex, with: value)
        } else {
            guard !_hashTable.isFull else {
                throw .overflow
            }
            let position: Index_Primitives.Index<Key>.Bounded<capacity> = .init(_keys.count.map(Ordinal.init))!
            _ = _keys.append(key)
            _ = _values.append(value)
            _ = _hashTable.insert(__unchecked: (), position: position, hashValue: hashValue)
        }
    }

    /// Removes a key-value pair.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if the key was not present.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        let hashValue = key.hashValue

        guard let removedPosition = _hashTable.remove(hashValue: hashValue, equals: { idx in
            _keys[idx] == key
        }) else {
            return nil
        }

        let keyIndex = Index_Primitives.Index<Key>(removedPosition)
        let valueIndex = keyIndex.retag(Value.self)
        _ = _keys.remove(at: keyIndex)
        let value = _values.remove(at: valueIndex)

        // Update positions in hash table for shifted elements
        _hashTable.positions.decrement(after: removedPosition)

        return value
    }

    /// Removes all key-value pairs.
    @inlinable
    public mutating func clear() {
        guard _hashTable.count > .zero else { return }
        _keys.removeAll()
        _values.removeAll()
        _hashTable.remove.all()
    }

    /// Accesses the value for the given key via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        let hashValue = key.hashValue
        guard let position = _hashTable.position(forHash: hashValue, equals: { idx in
            _keys[idx] == key
        }) else { return nil }
        let valueIndex = Index_Primitives.Index<Key>(position).retag(Value.self)
        return body(_values[valueIndex])
    }

    /// Accesses the value at the given index via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R {
        precondition(index >= 0 && index < Int(bitPattern: _keys.count), "Index out of bounds")
        let valueIndex = Index_Primitives.Index<Value>(Ordinal(UInt(index)))
        return body(_values[valueIndex])
    }

    /// Accesses the value at the given typed index via closure, with typed error on bounds failure.
    @inlinable
    public func withValue<R>(at index: Index_Primitives.Index<Key>, _ body: (borrowing Value) throws(__DictionaryOrderedInlineError<Key>) -> R) throws(__DictionaryOrderedInlineError<Key>) -> R {
        guard index < _keys.count else {
            throw .bounds(.init(index: index, count: _keys.count))
        }
        return try body(_values[index.retag(Value.self)])
    }
}

// Note: Inline is unconditionally ~Copyable (has deinit), cannot conform to Equatable/Hashable
// which require Copyable. Use isEqual(to:) method instead if needed.

// MARK: - Small Variant (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Small where Value: ~Copyable {
    /// The number of key-value pairs.
    @inlinable
    public var count: Int { _count }

    /// Whether the dictionary is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Returns whether the dictionary contains the given key.
    @inlinable
    public func contains(_ key: Key) -> Bool {
        if let heapKeys = _heapKeys {
            return heapKeys.contains(key)
        }
        return _inlineIndex(of: key) != nil
    }

    /// Returns the index of the given key in inline storage.
    @usableFromInline
    func _inlineIndex(of key: Key) -> Index_Primitives.Index<Key>? {
        var idx: Index_Primitives.Index<Key> = .zero
        let end = _inlineKeys.count.map(Ordinal.init)
        while idx < end {
            if _inlineKeys[idx] == key { return idx }
            idx += .one
        }
        return nil
    }

    /// Sets a value for the given key.
    ///
    /// - Parameters:
    ///   - key: The key.
    ///   - value: The value to associate with the key.
    @inlinable
    public mutating func set(_ key: Key, _ value: consuming Value) {
        if let heapKeys = _heapKeys {
            // Heap mode
            if let existingKeyIndex = heapKeys.index(key) {
                let valueIndex = existingKeyIndex.retag(Value.self)
                _ = _values.replace(at: valueIndex, with: value)
            } else {
                _heapKeys!.insert(key)
                _values.append(value)
                _count += 1
            }
        } else {
            // Inline mode
            if let existingIndex = _inlineIndex(of: key) {
                let valueIndex = existingIndex.retag(Value.self)
                _ = _values.replace(at: valueIndex, with: value)
            } else if !_inlineKeys.isFull {
                // Still room in inline storage
                _ = _inlineKeys.append(key)
                _values.append(value)
                _count += 1
            } else {
                // Need to spill keys to heap (values spill handled by Buffer.Small)
                _spillKeysToHeap()
                _heapKeys!.insert(key)
                _values.append(value)
                _count += 1
            }
        }
    }

    /// Removes a key-value pair.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if the key was not present.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        if let heapKeys = _heapKeys {
            // Heap mode
            guard let keyIndex = heapKeys.index(key) else { return nil }
            let valueIndex = keyIndex.retag(Value.self)
            _heapKeys!.remove(key)
            let value = _values.remove(at: valueIndex)
            _count -= 1
            return value
        } else {
            // Inline mode
            guard let index = _inlineIndex(of: key) else { return nil }

            let valueIndex = index.retag(Value.self)
            let value = _values.remove(at: valueIndex)
            _ = _inlineKeys.remove(at: index)
            _count -= 1

            return value
        }
    }

    /// Removes all key-value pairs.
    @inlinable
    public mutating func clear() {
        _values.removeAll()
        if _heapKeys != nil {
            _heapKeys!.clear(keepingCapacity: true)
        } else {
            _inlineKeys.removeAll()
        }
        _count = 0
    }

    /// Accesses the value for the given key via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        if let heapKeys = _heapKeys {
            guard let keyIndex = heapKeys.index(key) else { return nil }
            return body(_values[keyIndex.retag(Value.self)])
        }
        guard let index = _inlineIndex(of: key) else { return nil }
        return body(_values[index.retag(Value.self)])
    }

    /// Accesses the value at the given index via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R {
        precondition(index >= 0 && index < count, "Index out of bounds")
        let valueIndex = Index_Primitives.Index<Value>(Ordinal(UInt(index)))
        return body(_values[valueIndex])
    }
}

// Note: Small is unconditionally ~Copyable (has deinit), cannot conform to Equatable/Hashable
// which require Copyable. Use isEqual(to:) method instead if needed.
