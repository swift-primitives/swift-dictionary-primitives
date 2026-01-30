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
            let currentCount = _keys.count
            ensureCapacity(currentCount)
            let valueIndex = currentCount.retag(Value.self).subtract.saturating(.one)
            _valueStorage.initialize(to: value, at: Index_Primitives.Index<Value>(valueIndex))
            _valueStorage.count = valueIndex + .one
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
            if let existingKeyIndex = _keys.index(key) {
                let valueIndex = existingKeyIndex.retag(Value.self)
                let existingValue = unsafe _cachedValuePtr[Int(bitPattern: valueIndex)]
                let newValue = try combine(existingValue, value)
                _ = _valueStorage.move(at: valueIndex)
                _valueStorage.initialize(to: newValue, at: valueIndex)
            } else {
                let currentCount = _keys.count
                ensureCapacity(currentCount + .one)
                _keys.insert(key)
                let valueIndex = currentCount.retag(Value.self)
                _valueStorage.initialize(to: value, at: Index_Primitives.Index<Value>(valueIndex))
                _valueStorage.count = valueIndex + .one
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
            unsafe (_cachedValuePtr = _valueStorage.pointer(at: .zero).base)
        }
    }

    /// Sets the value for the given key (CoW-aware).
    ///
    /// This method shadows the base `set(_:_:)` when `Value: Copyable`,
    /// providing copy-on-write semantics.
    @inlinable
    public mutating func set(_ key: Key, _ value: Value) {
        makeUnique()
        if let existingKeyIndex = _keys.index(key) {
            let valueIndex = existingKeyIndex.retag(Value.self)
            _ = _valueStorage.move(at: valueIndex)
            _valueStorage.initialize(to: value, at: valueIndex)
        } else {
            let currentCount = _keys.count
            ensureCapacity(currentCount + .one)
            _keys.insert(key)
            let valueIndex = currentCount.retag(Value.self)
            _valueStorage.initialize(to: value, at: Index_Primitives.Index<Value>(valueIndex))
            _valueStorage.count = valueIndex + .one
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
        guard let keyIndex = _keys.index(key) else { return nil }
        let valueIndex = keyIndex.retag(Value.self)
        _keys.remove(key)
        let value = _valueStorage.move(at: valueIndex)
        _valueStorage.shiftLeft(removedAt: valueIndex)
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
        _valueStorage.deinitialize()
        if !keepingCapacity {
            _valueStorage = Storage<Value>.create(minimumCapacity: .zero)
            unsafe (_cachedValuePtr = _valueStorage.pointer(at: .zero).base)
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
            guard let keyIndex = _keys.index(key) else { return nil }
            let pos = Int(bitPattern: keyIndex)
            return unsafe _cachedValuePtr[pos]
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
    public subscript(at index: Index_Primitives.Index<Key>) -> (key: Key, value: Value) {
        let pos = Int(bitPattern: index)
        precondition(index < _keys.count, "Index out of bounds")
        return (_keys[index], unsafe _cachedValuePtr[pos])
    }

    /// Accesses the key-value pair at the given raw index (stdlib compatibility).
    @inlinable
    public subscript(index index: Int) -> (key: Key, value: Value) {
        precondition(index >= 0 && index < Int(bitPattern: _keys.count), "Index out of bounds")
        let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(index)))
        return (_keys[keyIndex], unsafe _cachedValuePtr[index])
    }
}

// MARK: - Equatable (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered: Equatable where Value: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs._keys == rhs._keys else { return false }
        let count = Int(bitPattern: lhs._keys.count)
        for i in 0..<count {
            if unsafe lhs._cachedValuePtr[i] != rhs._cachedValuePtr[i] {
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
        let count = Int(bitPattern: _keys.count)
        hasher.combine(count)
        for i in 0..<count {
            let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(i)))
            hasher.combine(_keys[keyIndex])
            hasher.combine(unsafe _cachedValuePtr[i])
        }
    }
}

// MARK: - CustomStringConvertible (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered: CustomStringConvertible where Value: Copyable {
    public var description: String {
        var result = "Dictionary.Ordered(["
        var first = true
        let count = Int(bitPattern: _keys.count)
        for i in 0..<count {
            if !first { result += ", " }
            let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(i)))
            result += "\(_keys[keyIndex]): \(unsafe _cachedValuePtr[i])"
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
            guard let keyIndex = _keys.index(key) else { return nil }
            let pos = Int(bitPattern: keyIndex)
            return unsafe _cachedValuePtr[pos]
        }
    }

    /// Accesses the key-value pair at the given index.
    @inlinable
    public subscript(index index: Int) -> (key: Key, value: Value) {
        precondition(index >= 0 && index < Int(bitPattern: _keys.count), "Index out of bounds")
        let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(index)))
        return (_keys[keyIndex], unsafe _cachedValuePtr[index])
    }
}

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Equatable where Value: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs._keys == rhs._keys else { return false }
        let count = Int(bitPattern: lhs._keys.count)
        for i in 0..<count {
            if unsafe lhs._cachedValuePtr[i] != rhs._cachedValuePtr[i] {
                return false
            }
        }
        return true
    }
}

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Hashable where Key: Hashable, Value: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        let count = Int(bitPattern: _keys.count)
        hasher.combine(count)
        for i in 0..<count {
            let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(i)))
            hasher.combine(_keys[keyIndex])
            hasher.combine(unsafe _cachedValuePtr[i])
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
                guard let keyIndex = heapKeys.index(key) else { return nil }
                let pos = Int(bitPattern: keyIndex)
                return unsafe _heapValuePtr![pos]
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
            let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(index)))
            return (heapKeys[keyIndex], unsafe _heapValuePtr![index])
        }
        return (_inlineKeys[index]!, unsafe _inlineReadPointerToValue(at: index).pointee)
    }
}
