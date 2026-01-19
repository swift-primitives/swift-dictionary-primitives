// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Set_Primitives

extension Dictionary {
    /// An ordered dictionary that preserves insertion order.
    ///
    /// `Ordered` combines the key-value semantics of a dictionary with the ordering
    /// guarantees of an array. Key-value pairs are stored in insertion order and
    /// can be accessed by index.
    ///
    /// ## API
    ///
    /// Key operations use nested accessors:
    ///
    /// ```swift
    /// var dict = Dictionary<String, Int>.Ordered()
    ///
    /// // Value operations
    /// dict.values.set("apple", 1)
    /// dict.values.set("banana", 2)
    /// let removed = dict.values.remove("apple")
    ///
    /// // Key operations
    /// if let idx = dict.keys.index("banana") { ... }
    ///
    /// // Subscript access
    /// dict["cherry"] = 3
    /// let value = dict["cherry"]
    /// ```
    ///
    /// ## Ordering Semantics
    ///
    /// - Setting a new key adds to the end
    /// - Updating existing key does NOT move position
    /// - Removal shifts subsequent pairs (indices change)
    /// - Re-insertion after removal goes to end
    ///
    /// ## Thread Safety
    ///
    /// Not thread-safe for concurrent mutation. Synchronize externally.
    ///
    /// ## Complexity
    ///
    /// - Set/get/remove by key: O(1) average
    /// - Index lookup: O(1) average
    /// - Random access by index: O(1)
    public struct Ordered {
        @usableFromInline
        var _keys: Set<Key>.Ordered

        @usableFromInline
        var _values: ContiguousArray<Value>

        /// Creates an empty ordered dictionary.
        @inlinable
        public init() {
            self._keys = Set<Key>.Ordered()
            self._values = ContiguousArray<Value>()
        }
    }
}

// MARK: - Initialization

extension Dictionary.Ordered {
    /// Creates an ordered dictionary from key-value pairs.
    ///
    /// - Parameter pairs: The key-value pairs.
    /// - Throws: `Ordered.Error.duplicate` if duplicate keys are found.
    @inlinable
    public init(_ pairs: some Sequence<(Key, Value)>) throws(Error) {
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
    public init(
        _ pairs: some Sequence<(Key, Value)>,
        uniquingKeysWith combine: (Value, Value) throws -> Value
    ) rethrows {
        self.init()
        for (key, value) in pairs {
            if let existingIndex = _keys.index(key) {
                _values[existingIndex] = try combine(_values[existingIndex], value)
            } else {
                _keys.insert(key)
                _values.append(value)
            }
        }
    }
}

// MARK: - Properties

extension Dictionary.Ordered {
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
        _keys.capacity
    }
}

// MARK: - Subscript Access

extension Dictionary.Ordered {
    /// Accesses the value for the given key.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The value if the key exists, or `nil`.
    @inlinable
    public subscript(key: Key) -> Value? {
        get {
            guard let index = _keys.index(key) else { return nil }
            return _values[index]
        }
        set {
            if let newValue = newValue {
                if let index = _keys.index(key) {
                    _values[index] = newValue
                } else {
                    _keys.insert(key)
                    _values.append(newValue)
                }
            } else {
                if let index = _keys.index(key) {
                    _keys.remove(key)
                    _values.remove(at: index)
                }
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
        return (_keys[index], _values[index])
    }
}

// MARK: - Contains

extension Dictionary.Ordered {
    /// Returns whether the dictionary contains the given key.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if the key exists.
    @inlinable
    public func contains(_ key: Key) -> Bool {
        _keys.contains(key)
    }
}

// MARK: - Capacity

extension Dictionary.Ordered {
    /// Reserves enough space for the specified number of pairs.
    ///
    /// - Parameter minimumCapacity: The minimum number of pairs.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        _keys.reserve(minimumCapacity)
        _values.reserveCapacity(minimumCapacity)
    }

    /// Removes all key-value pairs.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        _keys.clear(keepingCapacity: keepingCapacity)
        if keepingCapacity {
            _values.removeAll(keepingCapacity: true)
        } else {
            _values = []
        }
    }
}

// MARK: - Sendable

extension Dictionary.Ordered: Sendable where Key: Sendable, Value: Sendable {}

// MARK: - Equatable

extension Dictionary.Ordered: Equatable where Value: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs._keys == rhs._keys && lhs._values == rhs._values
    }
}

// MARK: - Hashable

extension Dictionary.Ordered: Hashable where Value: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for i in 0..<count {
            hasher.combine(_keys[i])
            hasher.combine(_values[i])
        }
    }
}

// MARK: - CustomStringConvertible

extension Dictionary.Ordered: CustomStringConvertible {
    public var description: String {
        var result = "Dictionary.Ordered(["
        var first = true
        for i in 0..<count {
            if !first { result += ", " }
            result += "\(_keys[i]): \(_values[i])"
            first = false
        }
        result += "])"
        return result
    }
}

