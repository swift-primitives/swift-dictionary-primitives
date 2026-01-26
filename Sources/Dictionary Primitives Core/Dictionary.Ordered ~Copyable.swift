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

// MARK: - Initialization (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Creates an ordered dictionary with reserved capacity.
    ///
    /// Pre-allocates storage for the specified number of elements.
    ///
    /// - Parameter capacity: Number of elements to reserve space for. Must be non-negative.
    /// - Throws: ``Dictionary/Ordered/Error/bounds(_:)`` if capacity is negative.
    @inlinable
    public init(reservingCapacity capacity: Int) throws(Error) {
        guard capacity >= 0 else {
            throw .bounds(.init(index: capacity, count: 0))
        }

        self._keys = Set<Key>.Ordered()
        self._keys.reserve(capacity)
        self._valueStorage = ValueStorage.create(minimumCapacity: capacity)
        unsafe (self._cachedValuePtr = _valueStorage._elementsPointer)
    }
}

// MARK: - Properties (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// The number of key-value pairs.
    @inlinable
    public var count: Int {
        _keys.count
    }

    /// Whether the dictionary is empty.
    @inlinable
    public var isEmpty: Bool {
        _keys.isEmpty
    }

    /// The current capacity.
    @inlinable
    public var capacity: Int {
        _valueStorage.capacity
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
    mutating func ensureCapacity(_ minimumCapacity: Int) {
        guard _valueStorage.capacity < minimumCapacity else { return }

        // Growth factor 2.0, minimum capacity 4
        let newCapacity = Swift.max(minimumCapacity, _valueStorage.capacity * 2, 4)
        let newStorage = ValueStorage.create(minimumCapacity: newCapacity)
        let currentCount = _valueStorage.header

        _valueStorage._moveAllValues(to: newStorage)
        newStorage.header = currentCount
        _valueStorage = newStorage
        unsafe (_cachedValuePtr = _valueStorage._elementsPointer)  // CRITICAL: Update cached pointer
    }

    /// Reserves enough space for the specified number of pairs.
    ///
    /// - Parameter minimumCapacity: The minimum number of pairs.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
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
        if let existingIndex = _keys.index(key) {
            _ = _valueStorage._moveValue(at: existingIndex)
            _valueStorage._initializeValue(at: existingIndex, to: value)
        } else {
            ensureCapacity(_valueStorage.header + 1)
            _keys.insert(key)
            _valueStorage._initializeValue(at: _valueStorage.header, to: value)
            _valueStorage.header += 1
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
        guard let index = _keys.index(key) else { return nil }
        let count = _valueStorage.header
        _keys.remove(key)
        let value = _valueStorage._moveValue(at: index)
        _valueStorage._shiftValuesLeftAndDecrement(removedAt: index, count: count)
        return value
    }

    /// Removes all key-value pairs.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        _keys.clear(keepingCapacity: keepingCapacity)
        _valueStorage._deinitializeAllValues()
        if !keepingCapacity {
            _valueStorage = ValueStorage.create(minimumCapacity: 0)
            unsafe (_cachedValuePtr = _valueStorage._elementsPointer)
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
        guard let index = _keys.index(key) else { return nil }
        return unsafe _valueStorage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + index).pointee)
        }
    }

    /// Accesses the value at the given index via closure (for ~Copyable values).
    ///
    /// - Parameters:
    ///   - index: The index.
    ///   - body: A closure that receives a borrowed reference to the value.
    /// - Returns: The result of the closure.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return unsafe _valueStorage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + index).pointee)
        }
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
        let count = _valueStorage.header
        guard count > 0 else { return }
        _ = unsafe _valueStorage.withUnsafeMutablePointerToElements { elements in
            for i in 0..<count {
                body(_keys[i], unsafe (elements + i).pointee)
            }
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
        let count = _valueStorage.header
        guard count > 0 else { return }
        _ = unsafe _valueStorage.withUnsafeMutablePointerToElements { elements in
            for i in 0..<count {
                body(Entry(key: _keys[i], value: unsafe (elements + i).move()))
            }
        }
        _valueStorage.header = 0
        _keys.clear(keepingCapacity: true)
    }
}

// MARK: - Bounded Variant (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded where Value: ~Copyable {
    /// Errors that can occur during bounded ordered dictionary operations.
    public typealias Error = __DictionaryOrderedBoundedError<Key>

    /// The number of key-value pairs.
    @inlinable
    public var count: Int { _keys.count }

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
        if let existingIndex = _keys.index(key) {
            _ = _valueStorage._moveValue(at: existingIndex)
            _valueStorage._initializeValue(at: existingIndex, to: value)
        } else {
            guard _keys.count < capacity else {
                throw .overflow
            }
            _keys.insert(key)
            _valueStorage._initializeValue(at: _valueStorage.header, to: value)
            _valueStorage.header += 1
        }
    }

    /// Removes a key-value pair.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if the key was not present.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        guard let index = _keys.index(key) else { return nil }
        let count = _valueStorage.header
        _keys.remove(key)
        let value = _valueStorage._moveValue(at: index)
        _valueStorage._shiftValuesLeftAndDecrement(removedAt: index, count: count)
        return value
    }

    /// Removes all key-value pairs.
    @inlinable
    public mutating func clear() {
        _keys.clear(keepingCapacity: true)
        _valueStorage._deinitializeAllValues()
    }

    /// Accesses the value for the given key via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        guard let index = _keys.index(key) else { return nil }
        return unsafe _valueStorage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + index).pointee)
        }
    }

    /// Accesses the value at the given index via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return unsafe _valueStorage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + index).pointee)
        }
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
            // Update existing
            let ptr = unsafe _pointerToValue(at: existingIndex)
            unsafe ptr.deinitialize(count: 1)
            unsafe ptr.initialize(to: value)
        } else {
            guard _count < capacity else {
                throw .overflow
            }
            // Insert new
            _keys[_count] = key
            let ptr = unsafe _pointerToValue(at: _count)
            unsafe ptr.initialize(to: value)
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

        let ptr = unsafe _pointerToValue(at: index)
        let value = unsafe ptr.move()

        // Shift keys and values left
        for i in index..<(_count - 1) {
            _keys[i] = _keys[i + 1]
            let srcPtr = unsafe _pointerToValue(at: i + 1)
            let dstPtr = unsafe _pointerToValue(at: i)
            unsafe dstPtr.initialize(to: srcPtr.move())
        }
        _keys[_count - 1] = nil
        _count -= 1

        return value
    }

    /// Removes all key-value pairs.
    @inlinable
    public mutating func clear() {
        for i in 0..<_count {
            let ptr = unsafe _pointerToValue(at: i)
            unsafe ptr.deinitialize(count: 1)
            _keys[i] = nil
        }
        _count = 0
    }

    /// Accesses the value for the given key via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        guard let index = index(of: key) else { return nil }
        return body(unsafe _readPointerToValue(at: index).pointee)
    }

    /// Accesses the value at the given index via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return body(unsafe _readPointerToValue(at: index).pointee)
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
            if let existingIndex = heapKeys.index(key) {
                _ = _heapValues!._moveValue(at: existingIndex)
                _heapValues!._initializeValue(at: existingIndex, to: value)
            } else {
                // Ensure capacity
                if _heapValues!.capacity <= _count {
                    let newCapacity = Swift.max(_count * 2, 8)
                    let newStorage = Dictionary<Key, Value>.Ordered.ValueStorage.create(minimumCapacity: newCapacity)
                    _heapValues!._moveAllValues(to: newStorage)
                    newStorage.header = _count
                    _heapValues = newStorage
                    unsafe (_heapValuePtr = newStorage._elementsPointer)
                }
                _heapKeys!.insert(key)
                _heapValues!._initializeValue(at: _heapValues!.header, to: value)
                _heapValues!.header += 1
                _count += 1
            }
        } else {
            // Inline mode
            if let existingIndex = _inlineIndex(of: key) {
                let ptr = unsafe _inlinePointerToValue(at: existingIndex)
                unsafe ptr.deinitialize(count: 1)
                unsafe ptr.initialize(to: value)
            } else if _count < inlineCapacity {
                // Still room in inline storage
                _inlineKeys[_count] = key
                let ptr = unsafe _inlinePointerToValue(at: _count)
                unsafe ptr.initialize(to: value)
                _count += 1
            } else {
                // Need to spill to heap
                _spillToHeap(minimumCapacity: _count + 1)
                _heapKeys!.insert(key)
                _heapValues!._initializeValue(at: _heapValues!.header, to: value)
                _heapValues!.header += 1
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
            guard let index = heapKeys.index(key) else { return nil }
            let count = _heapValues!.header
            _heapKeys!.remove(key)
            let value = _heapValues!._moveValue(at: index)
            _heapValues!._shiftValuesLeftAndDecrement(removedAt: index, count: count)
            _count -= 1
            return value
        } else {
            // Inline mode
            guard let index = _inlineIndex(of: key) else { return nil }

            let ptr = unsafe _inlinePointerToValue(at: index)
            let value = unsafe ptr.move()

            // Shift keys and values left
            for i in index..<(_count - 1) {
                _inlineKeys[i] = _inlineKeys[i + 1]
                let srcPtr = unsafe _inlinePointerToValue(at: i + 1)
                let dstPtr = unsafe _inlinePointerToValue(at: i)
                unsafe dstPtr.initialize(to: srcPtr.move())
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
            heapValues._deinitializeAllValues()
        } else {
            for i in 0..<_count {
                let ptr = unsafe _inlinePointerToValue(at: i)
                unsafe ptr.deinitialize(count: 1)
                _inlineKeys[i] = nil
            }
        }
        _count = 0
    }

    /// Accesses the value for the given key via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        if let heapKeys = _heapKeys {
            guard let index = heapKeys.index(key) else { return nil }
            return unsafe _heapValues!.withUnsafeMutablePointerToElements { elements in
                body(unsafe (elements + index).pointee)
            }
        }
        guard let index = _inlineIndex(of: key) else { return nil }
        return body(unsafe _inlineReadPointerToValue(at: index).pointee)
    }

    /// Accesses the value at the given index via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R {
        precondition(index >= 0 && index < count, "Index out of bounds")
        if let heapValues = _heapValues {
            return unsafe heapValues.withUnsafeMutablePointerToElements { elements in
                body(unsafe (elements + index).pointee)
            }
        }
        return body(unsafe _inlineReadPointerToValue(at: index).pointee)
    }
}

// Note: Small is unconditionally ~Copyable (has deinit), cannot conform to Equatable/Hashable
// which require Copyable. Use isEqual(to:) method instead if needed.
