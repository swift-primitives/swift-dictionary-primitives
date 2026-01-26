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

// MARK: - ValueStorage Copyable Helpers

extension Dictionary_Primitives_Core.Dictionary.Ordered.ValueStorage where Value: Copyable {

    /// Creates a copy of this storage with all values duplicated.
    @usableFromInline
    func copy() -> Dictionary<Key, Value>.Ordered.ValueStorage {
        let count = header
        guard count > 0 else {
            return Dictionary<Key, Value>.Ordered.ValueStorage.create(minimumCapacity: 0)
        }

        let new = Dictionary<Key, Value>.Ordered.ValueStorage.create(minimumCapacity: capacity)
        new.header = count

        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe new.withUnsafeMutablePointerToElements { dst in
                for i in 0..<count {
                    unsafe (dst + i).initialize(to: src[i])
                }
            }
        }

        return new
    }

    /// Reads value at the given index.
    @inlinable
    public func _readValue(at index: Int) -> Value {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe elements[index]
        }
    }

    /// Copies all values to new storage.
    @usableFromInline
    func _copyAllValues(to newStorage: Dictionary<Key, Value>.Ordered.ValueStorage) {
        let count = header
        guard count > 0 else { return }
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                for i in 0..<count {
                    unsafe (dst + i).initialize(to: src[i])
                }
            }
        }
    }
}

// MARK: - Initialization (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: Copyable {
    /// Creates an ordered dictionary from key-value pairs.
    ///
    /// - Parameter pairs: The key-value pairs.
    /// - Throws: `Ordered.Error.duplicate` if duplicate keys are found.
    @inlinable
    public init(_ pairs: some Swift.Sequence<(Key, Value)>) throws(Error) {
        self.init()
        for (key, value) in pairs {
            let (inserted, _) = _keys.insert(key)
            if !inserted {
                let first = _keys.index(key)!
                throw .duplicate(.init(key: key, first: first, second: _keys.count))
            }
            ensureCapacity(_valueStorage.header + 1)
            _valueStorage._initializeValue(at: _valueStorage.header, to: value)
            _valueStorage.header += 1
        }
    }

    /// Creates an ordered dictionary from key-value pairs, using a closure to resolve duplicates.
    ///
    /// - Parameters:
    ///   - pairs: The key-value pairs.
    ///   - combine: A closure that receives the existing and new values, returning the value to keep.
    @inlinable
    public init(
        _ pairs: some Swift.Sequence<(Key, Value)>,
        uniquingKeysWith combine: (Value, Value) throws -> Value
    ) rethrows {
        self.init()
        for (key, value) in pairs {
            if let existingIndex = _keys.index(key) {
                let existingValue = _valueStorage._readValue(at: existingIndex)
                let newValue = try combine(existingValue, value)
                // Deinitialize old and initialize new
                _ = _valueStorage._moveValue(at: existingIndex)
                _valueStorage._initializeValue(at: existingIndex, to: newValue)
            } else {
                ensureCapacity(_valueStorage.header + 1)
                _keys.insert(key)
                _valueStorage._initializeValue(at: _valueStorage.header, to: value)
                _valueStorage.header += 1
            }
        }
    }
}

// MARK: - Copy-on-Write (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_valueStorage) {
            _valueStorage = _valueStorage.copy()
            unsafe (_cachedValuePtr = _valueStorage._elementsPointer)  // CRITICAL: Update cached pointer
        }
    }

    /// Sets the value for the given key (CoW-aware).
    ///
    /// This method shadows the base `set(_:_:)` when `Value: Copyable`,
    /// providing copy-on-write semantics.
    @inlinable
    public mutating func set(_ key: Key, _ value: Value) {
        makeUnique()
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

    /// Removes the value for the given key (CoW-aware).
    ///
    /// This method shadows the base `remove(_:)` when `Value: Copyable`,
    /// providing copy-on-write semantics.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if not present.
    /// - Complexity: O(n) due to index shifting, O(n) if copy triggered.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        makeUnique()
        guard let index = _keys.index(key) else { return nil }
        let count = _valueStorage.header
        _keys.remove(key)
        let value = _valueStorage._moveValue(at: index)
        _valueStorage._shiftValuesLeftAndDecrement(removedAt: index, count: count)
        return value
    }

    /// Removes all key-value pairs (CoW-aware).
    ///
    /// This method shadows the base `clear(keepingCapacity:)` when `Value: Copyable`,
    /// providing copy-on-write semantics.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        makeUnique()
        _keys.clear(keepingCapacity: keepingCapacity)
        _valueStorage._deinitializeAllValues()
        if !keepingCapacity {
            _valueStorage = ValueStorage.create(minimumCapacity: 0)
            unsafe (_cachedValuePtr = _valueStorage._elementsPointer)
        }
    }
}

// MARK: - Subscript Access (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: Copyable {
    /// Accesses the value for the given key.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The value if the key exists, or `nil`.
    @inlinable
    public subscript(key: Key) -> Value? {
        get {
            guard let index = _keys.index(key) else { return nil }
            return _valueStorage._readValue(at: index)
        }
        set {
            if let newValue = newValue {
                set(key, newValue)
            } else {
                remove(key)
            }
        }
    }

    /// Accesses the key-value pair at the given index.
    ///
    /// - Parameter index: The index of the pair.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public subscript(index index: Int) -> (key: Key, value: Value) {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return (_keys[index], _valueStorage._readValue(at: index))
    }
}

// MARK: - Equatable (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered: Equatable where Value: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs._keys == rhs._keys else { return false }
        let count = lhs._valueStorage.header
        for i in 0..<count {
            if lhs._valueStorage._readValue(at: i) != rhs._valueStorage._readValue(at: i) {
                return false
            }
        }
        return true
    }
}

// MARK: - Hashable (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered: Hashable where Key: Hashable, Value: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for i in 0..<count {
            hasher.combine(_keys[i])
            hasher.combine(_valueStorage._readValue(at: i))
        }
    }
}

// MARK: - CustomStringConvertible (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered: CustomStringConvertible where Value: Copyable {
    public var description: String {
        var result = "Dictionary.Ordered(["
        var first = true
        for i in 0..<count {
            if !first { result += ", " }
            result += "\(_keys[i]): \(_valueStorage._readValue(at: i))"
            first = false
        }
        result += "])"
        return result
    }
}

// MARK: - Bounded Variant (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded where Value: Copyable {
    /// Accesses the value for the given key.
    @inlinable
    public subscript(key: Key) -> Value? {
        get {
            guard let index = _keys.index(key) else { return nil }
            return _valueStorage._readValue(at: index)
        }
    }

    /// Accesses the key-value pair at the given index.
    @inlinable
    public subscript(index index: Int) -> (key: Key, value: Value) {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return (_keys[index], _valueStorage._readValue(at: index))
    }
}

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Equatable where Value: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs._keys == rhs._keys else { return false }
        let count = lhs._valueStorage.header
        for i in 0..<count {
            if lhs._valueStorage._readValue(at: i) != rhs._valueStorage._readValue(at: i) {
                return false
            }
        }
        return true
    }
}

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Hashable where Key: Hashable, Value: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for i in 0..<count {
            hasher.combine(_keys[i])
            hasher.combine(_valueStorage._readValue(at: i))
        }
    }
}

// MARK: - Inline Variant (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Inline where Value: Copyable {
    /// Accesses the value for the given key.
    @inlinable
    public subscript(key: Key) -> Value? {
        get {
            guard let index = index(of: key) else { return nil }
            return unsafe _readPointerToValue(at: index).pointee
        }
    }

    /// Accesses the key-value pair at the given index.
    @inlinable
    public subscript(index index: Int) -> (key: Key, value: Value) {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return (_keys[index]!, unsafe _readPointerToValue(at: index).pointee)
    }
}

// MARK: - Small Variant (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Small where Value: Copyable {
    /// Accesses the value for the given key.
    @inlinable
    public subscript(key: Key) -> Value? {
        get {
            if let heapKeys = _heapKeys {
                guard let index = heapKeys.index(key) else { return nil }
                return _heapValues!._readValue(at: index)
            }
            guard let index = _inlineIndex(of: key) else { return nil }
            return unsafe _inlineReadPointerToValue(at: index).pointee
        }
    }

    /// Accesses the key-value pair at the given index.
    @inlinable
    public subscript(index index: Int) -> (key: Key, value: Value) {
        precondition(index >= 0 && index < count, "Index out of bounds")
        if let heapKeys = _heapKeys {
            return (heapKeys[index], _heapValues!._readValue(at: index))
        }
        return (_inlineKeys[index]!, unsafe _inlineReadPointerToValue(at: index).pointee)
    }
}
