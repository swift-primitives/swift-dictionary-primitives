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
        let valueCapacity = capacity.retag(Value.self)
        self._values = Storage<Value>.create(minimumCapacity: valueCapacity)
        unsafe (self._cachedValuePtr = _values.pointer(at: .zero).base)
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
        _values.count.retag(Key.self)
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
        let currentCapacity = Index_Primitives.Index<Key>.Count(UInt(_values.capacity))
        guard currentCapacity < minimumCapacity else { return }

        // Growth factor 2.0, minimum capacity 4
        let minCapInt = Int(bitPattern: minimumCapacity)
        let currentCapInt = _values.capacity
        let newCapInt = Swift.max(minCapInt, currentCapInt * 2, 4)
        let newCapacity = Index_Primitives.Index<Value>.Count(UInt(newCapInt))

        let newStorage = Storage<Value>.create(minimumCapacity: newCapacity)
        let currentCount = _values.count

        // Move values to new storage
        if currentCount > .zero {
            _values.move(to: newStorage, count: currentCount)
        }
        newStorage.count = currentCount
        _values = newStorage
        unsafe (_cachedValuePtr = _values.pointer(at: .zero).base)
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
            _ = _values.move(at: valueIndex)
            _values.initialize(to: value, at: valueIndex)
        } else {
            let currentCount = _keys.count
            ensureCapacity(currentCount + .one)
            _keys.insert(key)
            let valueIndex = currentCount.retag(Value.self)
            _values.initialize(to: value, at: Index_Primitives.Index<Value>(valueIndex))
            _values.count = valueIndex + .one
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
        let value = _values.move(at: valueIndex)
        _values.shiftLeft(removedAt: valueIndex)
        return value
    }

    /// Removes all key-value pairs.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        _keys.clear(keepingCapacity: keepingCapacity)
        _values.deinitialize()
        if !keepingCapacity {
            _values = Storage<Value>.create(minimumCapacity: .zero)
            unsafe (_cachedValuePtr = _values.pointer(at: .zero).base)
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
        let pos = Int(bitPattern: keyIndex)
        return body(unsafe _cachedValuePtr[pos])
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
        let pos = Int(bitPattern: index)
        return body(unsafe _cachedValuePtr[pos])
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
        let count = Int(bitPattern: _keys.count)
        guard count > 0 else { return }
        for i in 0..<count {
            let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(i)))
            body(_keys[keyIndex], unsafe _cachedValuePtr[i])
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
        let count = Int(bitPattern: _keys.count)
        guard count > 0 else { return }
        for i in 0..<count {
            let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(i)))
            let valueIndex = Index_Primitives.Index<Value>(Ordinal(UInt(i)))
            body(Entry(key: _keys[keyIndex], value: _values.move(at: valueIndex)))
        }
        _values.count = .zero
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
            _ = _values.move(at: valueIndex)
            _values.initialize(to: value, at: valueIndex)
        } else {
            guard _keys.count < capacity else {
                throw .overflow
            }
            let currentCount = _keys.count
            _keys.insert(key)
            let valueIndex = currentCount.retag(Value.self)
            _values.initialize(to: value, at: Index_Primitives.Index<Value>(valueIndex))
            _values.count = valueIndex + .one
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
        let value = _values.move(at: valueIndex)
        _values.shiftLeft(removedAt: valueIndex)
        return value
    }

    /// Removes all key-value pairs.
    @inlinable
    public mutating func clear() {
        _keys.clear(keepingCapacity: true)
        _values.deinitialize()
    }

    /// Accesses the value for the given key via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        guard let keyIndex = _keys.index(key) else { return nil }
        let pos = Int(bitPattern: keyIndex)
        return body(unsafe _cachedValuePtr[pos])
    }

    /// Accesses the value at the given typed index via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(at index: Index_Primitives.Index<Key>, _ body: (borrowing Value) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        let pos = Int(bitPattern: index)
        return body(unsafe _cachedValuePtr[pos])
    }
}

// MARK: - Inline Variant (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Inline where Value: ~Copyable {
    /// Errors that can occur during inline ordered dictionary operations.
    public typealias Error = __DictionaryOrderedInlineError<Key>

    /// The number of key-value pairs.
    @inlinable
    public var count: Int { _count }

    /// Whether the dictionary is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Whether the dictionary is at capacity.
    @inlinable
    public var isFull: Bool { _count >= capacity }

    /// Returns whether the dictionary contains the given key.
    @inlinable
    public func contains(_ key: Key) -> Bool {
        index(of: key) != nil
    }

    /// Returns the index of the given key, or nil if not present.
    @inlinable
    public func index(of key: Key) -> Int? {
        // Linear search for simplicity in inline storage
        for i in 0..<_count {
            if _keys[i] == key {
                return i
            }
        }
        return nil
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
        if let existingIndex = index(of: key) {
            // Update existing - move old value out, initialize with new
            let valueIndex = Index<Value>(Ordinal(UInt(existingIndex)))
            _ = _values.move(at: valueIndex)
            _values.initialize(to: value, at: valueIndex)
        } else {
            guard _count < capacity else {
                throw .overflow
            }
            // Insert new
            _keys[_count] = key
            let valueIndex = Index<Value>(Ordinal(UInt(_count)))
            _values.initialize(to: value, at: valueIndex)
            _count += 1
        }
    }

    /// Removes a key-value pair.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if the key was not present.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        guard let index = index(of: key) else { return nil }

        let valueIndex = Index<Value>(Ordinal(UInt(index)))
        let value = _values.move(at: valueIndex)

        // Shift values left using Storage.Inline's shift API
        _values.shift.left(removedAt: valueIndex, count: Index<Value>.Count(UInt(_count)))

        // Shift keys left
        for i in index..<(_count - 1) {
            _keys[i] = _keys[i + 1]
        }
        _keys[_count - 1] = nil
        _count -= 1

        return value
    }

    /// Removes all key-value pairs.
    @inlinable
    public mutating func clear() {
        if _count > 0 {
            _values.deinitialize(count: Index<Value>.Count(UInt(_count)))
        }
        for i in 0..<_count {
            _keys[i] = nil
        }
        _count = 0
    }

    /// Accesses the value for the given key via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        guard let index = index(of: key) else { return nil }
        let valueIndex = Index<Value>(Ordinal(UInt(index)))
        return _values.withElement(at: valueIndex, body)
    }

    /// Accesses the value at the given index via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R {
        precondition(index >= 0 && index < count, "Index out of bounds")
        let valueIndex = Index<Value>(Ordinal(UInt(index)))
        return _values.withElement(at: valueIndex, body)
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
    func _inlineIndex(of key: Key) -> Int? {
        for i in 0..<_count {
            if _inlineKeys[i] == key {
                return i
            }
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
                _ = _heapValues!.move(at: valueIndex)
                _heapValues!.initialize(to: value, at: valueIndex)
            } else {
                // Ensure capacity
                if _heapValues!.capacity <= _count {
                    let newCapacity = Swift.max(_count * 2, 8)
                    let valueCapacity = Index_Primitives.Index<Value>.Count(UInt(newCapacity))
                    let newStorage = Storage<Value>.create(minimumCapacity: valueCapacity)
                    let currentCount = _heapValues!.count
                    if currentCount > .zero {
                        _heapValues!.move(to: newStorage, count: currentCount)
                    }
                    newStorage.count = currentCount
                    _heapValues = newStorage
                    unsafe (_heapValuePtr = newStorage.pointer(at: .zero).base)
                }
                let currentCount = _heapKeys!.count
                _heapKeys!.insert(key)
                let valueIndex = currentCount.retag(Value.self)
                _heapValues!.initialize(to: value, at: Index_Primitives.Index<Value>(valueIndex))
                _heapValues!.count = valueIndex + .one
                _count += 1
            }
        } else {
            // Inline mode
            if let existingIndex = _inlineIndex(of: key) {
                // Update existing - move old value out, initialize with new
                let valueIndex = Index_Primitives.Index<Value>(Ordinal(UInt(existingIndex)))
                _ = _inlineValueStorage.move(at: valueIndex)
                _inlineValueStorage.initialize(to: value, at: valueIndex)
            } else if _count < inlineCapacity {
                // Still room in inline storage
                _inlineKeys[_count] = key
                let valueIndex = Index_Primitives.Index<Value>(Ordinal(UInt(_count)))
                _inlineValueStorage.initialize(to: value, at: valueIndex)
                _count += 1
            } else {
                // Need to spill to heap
                _spillToHeap(minimumCapacity: _count + 1)
                let currentCount = _heapKeys!.count
                _heapKeys!.insert(key)
                let valueIndex = currentCount.retag(Value.self)
                _heapValues!.initialize(to: value, at: Index_Primitives.Index<Value>(valueIndex))
                _heapValues!.count = valueIndex + .one
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
            let value = _heapValues!.move(at: valueIndex)
            _heapValues!.shiftLeft(removedAt: valueIndex)
            _count -= 1
            return value
        } else {
            // Inline mode
            guard let index = _inlineIndex(of: key) else { return nil }

            let valueIndex = Index_Primitives.Index<Value>(Ordinal(UInt(index)))
            let value = _inlineValueStorage.move(at: valueIndex)

            // Shift values left using Storage.Inline's shift API
            _inlineValueStorage.shift.left(removedAt: valueIndex, count: Index_Primitives.Index<Value>.Count(UInt(_count)))

            // Shift keys left
            for i in index..<(_count - 1) {
                _inlineKeys[i] = _inlineKeys[i + 1]
            }
            _inlineKeys[_count - 1] = nil
            _count -= 1

            return value
        }
    }

    /// Removes all key-value pairs.
    @inlinable
    public mutating func clear() {
        if let heapValues = _heapValues {
            _heapKeys!.clear(keepingCapacity: true)
            heapValues.deinitialize()
        } else {
            if _count > 0 {
                _inlineValueStorage.deinitialize(count: Index_Primitives.Index<Value>.Count(UInt(_count)))
            }
            for i in 0..<_count {
                _inlineKeys[i] = nil
            }
        }
        _count = 0
    }

    /// Accesses the value for the given key via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        if let heapKeys = _heapKeys {
            guard let keyIndex = heapKeys.index(key) else { return nil }
            let pos = Int(bitPattern: keyIndex)
            return body(unsafe _heapValuePtr![pos])
        }
        guard let index = _inlineIndex(of: key) else { return nil }
        let valueIndex = Index_Primitives.Index<Value>(Ordinal(UInt(index)))
        return _inlineValueStorage.withElement(at: valueIndex, body)
    }

    /// Accesses the value at the given index via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R {
        precondition(index >= 0 && index < count, "Index out of bounds")
        if let _ = _heapValues {
            return body(unsafe _heapValuePtr![index])
        }
        let valueIndex = Index_Primitives.Index<Value>(Ordinal(UInt(index)))
        return _inlineValueStorage.withElement(at: valueIndex, body)
    }
}

// Note: Small is unconditionally ~Copyable (has deinit), cannot conform to Equatable/Hashable
// which require Copyable. Use isEqual(to:) method instead if needed.
