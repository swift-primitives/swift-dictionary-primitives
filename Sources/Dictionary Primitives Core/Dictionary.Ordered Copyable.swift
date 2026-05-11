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
    public init(_ pairs: some Swift.Sequence<(Key, Value)>) throws(Self.Error) {
        self.init()
        for (key, value) in pairs {
            let (inserted, _) = _keys.insert(key)
            if !inserted {
                let first = _keys.index(key)!
                throw .duplicate(.init(key: key, first: first, second: _keys.count))
            }
            _values.append(value)
        }
    }

    /// Creates an ordered dictionary from key-value pairs, using a closure to resolve duplicates.
    ///
    /// - Parameters:
    ///   - pairs: The key-value pairs.
    ///   - combine: A closure that receives the existing and new values, returning the value to keep.
    @inlinable
    public init<E: Swift.Error>(
        _ pairs: some Swift.Sequence<(Key, Value)>,
        uniquingKeysWith combine: (Value, Value) throws(E) -> Value
    ) throws(E) {
        self.init()
        for (key, value) in pairs {
            if let existingKeyIndex = _keys.index(key) {
                let valueIndex = existingKeyIndex.retag(Value.self)
                let existingValue = _values[valueIndex]
                let newValue = try combine(existingValue, value)
                _ = _values.replace(at: valueIndex, with: newValue)
            } else {
                _keys.insert(key)
                _values.append(value)
            }
        }
    }
}

// MARK: - Copy-on-Write (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    mutating func makeUnique() {
        _values.ensureUnique()
    }

    /// Sets the value for the given key (CoW-aware).
    ///
    /// This method shadows the base `set(_:_:)` when `Value: Copyable`,
    /// providing copy-on-write semantics.
    @inlinable
    public mutating func set(_ key: Key, _ value: Value) {
        makeUnique()
        if let existingKeyIndex = _keys.index(key) {
            _ = _values.replace(at: existingKeyIndex.retag(Value.self), with: value)
        } else {
            _keys.insert(key)
            _values.append(value)
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
        _keys.remove(key)
        return _values.remove(at: keyIndex.retag(Value.self))
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
        _values.remove.all()
        if !keepingCapacity {
            _values = Buffer<Value>.Linear(minimumCapacity: .zero)
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
            return _values[keyIndex.retag(Value.self)]
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
        precondition(index < _keys.count, "Index out of bounds")
        return (_keys[index], _values[index.retag(Value.self)])
    }

    /// Accesses the key-value pair at the given raw index (stdlib compatibility).
    @inlinable
    public subscript(index index: Int) -> (key: Key, value: Value) {
        precondition(index >= 0 && index < Int(bitPattern: _keys.count), "Index out of bounds")
        let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(index)))
        return (_keys[keyIndex], _values[keyIndex.retag(Value.self)])
    }
}

// MARK: - Equatable (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered: Equatable where Value: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs._keys == rhs._keys else { return false }
        var idx: Index_Primitives.Index<Key> = .zero
        let end = lhs._keys.count.map(Ordinal.init)
        while idx < end {
            if lhs._values[idx.retag(Value.self)] != rhs._values[idx.retag(Value.self)] {
                return false
            }
            idx += .one
        }
        return true
    }
}

// MARK: - Hashable (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered: Hashable where Key: Hashable, Value: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_keys.count)
        var idx: Index_Primitives.Index<Key> = .zero
        let end = _keys.count.map(Ordinal.init)
        while idx < end {
            hasher.combine(_keys[idx])
            hasher.combine(_values[idx.retag(Value.self)])
            idx += .one
        }
    }
}

// MARK: - CustomStringConvertible (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered: CustomStringConvertible where Value: Copyable {
    public var description: String {
        var result = "Dictionary.Ordered(["
        var first = true
        var idx: Index_Primitives.Index<Key> = .zero
        let end = _keys.count.map(Ordinal.init)
        while idx < end {
            if !first { result += ", " }
            result += "\(_keys[idx]): \(_values[idx.retag(Value.self)])"
            first = false
            idx += .one
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
            return _values[keyIndex.retag(Value.self)]
        }
    }

    /// Accesses the key-value pair at the given index.
    @inlinable
    public subscript(index index: Int) -> (key: Key, value: Value) {
        precondition(index >= 0 && index < Int(bitPattern: _keys.count), "Index out of bounds")
        let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(index)))
        return (_keys[keyIndex], _values[keyIndex.retag(Value.self)])
    }
}

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Equatable where Value: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs._keys == rhs._keys else { return false }
        var idx: Index_Primitives.Index<Key> = .zero
        let end = lhs._keys.count.map(Ordinal.init)
        while idx < end {
            if lhs._values[idx.retag(Value.self)] != rhs._values[idx.retag(Value.self)] {
                return false
            }
            idx += .one
        }
        return true
    }
}

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Hashable where Key: Hashable, Value: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_keys.count)
        var idx: Index_Primitives.Index<Key> = .zero
        let end = _keys.count.map(Ordinal.init)
        while idx < end {
            hasher.combine(_keys[idx])
            hasher.combine(_values[idx.retag(Value.self)])
            idx += .one
        }
    }
}

// MARK: - Inline Variant (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Static where Value: Copyable {
    /// Accesses the value for the given key.
    @inlinable
    public subscript(key: Key) -> Value? {
        get {
            let hashValue = key.hashValue
            guard
                let position = _hashTable.position(
                    forHash: hashValue,
                    equals: { idx in
                        _keys[idx] == key
                    }
                )
            else { return nil }
            return _values[Index_Primitives.Index<Key>(position).retag(Value.self)]
        }
    }

    /// Accesses the key-value pair at the given index.
    @inlinable
    public subscript(index index: Int) -> (key: Key, value: Value) {
        precondition(index >= 0 && index < Int(bitPattern: _keys.count), "Index out of bounds")
        let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(index)))
        return (_keys[keyIndex], _values[keyIndex.retag(Value.self)])
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
                return _values[keyIndex.retag(Value.self)]
            }
            guard let index = _inlineIndex(of: key) else { return nil }
            return _values[index.retag(Value.self)]
        }
    }

    /// Accesses the key-value pair at the given index.
    @inlinable
    public subscript(index index: Int) -> (key: Key, value: Value) {
        precondition(index >= 0 && index < Int(bitPattern: count), "Index out of bounds")
        let valueIndex = Index_Primitives.Index<Value>(Ordinal(UInt(index)))
        if let heapKeys = _heapKeys {
            let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(index)))
            return (heapKeys[keyIndex], _values[valueIndex])
        }
        let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(index)))
        return (_inlineKeys[keyIndex], _values[valueIndex])
    }
}
