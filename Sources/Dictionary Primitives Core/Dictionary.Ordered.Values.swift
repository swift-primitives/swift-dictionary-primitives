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

public import Set_Primitives

// MARK: - Values Accessor (Copyable values only)
//
// The Values accessor provides a convenient namespace for value operations
// when values are Copyable. For ~Copyable values, use the methods directly
// on Dictionary.Ordered: set(_:_:), remove(_:), withValue(forKey:_:), etc.

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: Copyable {
    /// Nested accessor for value operations.
    ///
    /// ```swift
    /// dict.values.set("apple", 1)
    /// let removed = dict.values.remove("banana")
    /// let allValues = dict.values.all
    /// ```
    ///
    /// - Note: For `~Copyable` values, use methods directly on `Dictionary.Ordered`:
    ///   `set(_:_:)`, `remove(_:)`, `withValue(forKey:_:)`, etc.
    @inlinable
    public var values: Values {
        get { Values(dict: self) }
        _modify {
            var proxy = Values(dict: self)
            defer { self = proxy.dict }
            yield &proxy
        }
    }
}

// MARK: - Values Type (Copyable values only)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: Copyable {
    /// Namespace for value operations.
    ///
    /// Available only when `Value` is `Copyable`. For `~Copyable` values,
    /// use methods directly on `Dictionary.Ordered`.
    public struct Values {
        @usableFromInline
        var dict: Dictionary<Key, Value>.Ordered

        @usableFromInline
        init(dict: Dictionary<Key, Value>.Ordered) {
            self.dict = dict
        }
    }
}

// MARK: - Values Operations (Copyable values only)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Values {
    /// Sets the value for the given key.
    ///
    /// If the key exists, updates the value without changing position.
    /// If the key is new, adds to the end.
    ///
    /// - Parameters:
    ///   - key: The key.
    ///   - value: The value.
    /// - Complexity: O(1) average.
    @inlinable
    public mutating func set(_ key: Key, _ value: Value) {
        dict.set(key, value)
    }

    /// Removes the value for the given key.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if not present.
    /// - Complexity: O(n) due to index shifting.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        dict.remove(key)
    }

    /// Updates the value for the given key using a closure.
    ///
    /// - Parameters:
    ///   - key: The key to update.
    ///   - transform: A closure that transforms the current value.
    /// - Returns: The new value, or `nil` if the key doesn't exist.
    @inlinable
    @discardableResult
    public mutating func modify(_ key: Key, _ transform: (inout Value) -> Void) -> Value? {
        guard let index = dict._keys.index(key) else { return nil }
        // Read, modify, write back
        var value = dict._valueStorage._readValue(at: index)
        transform(&value)
        _ = dict._valueStorage._moveValue(at: index)
        dict._valueStorage._initializeValue(at: index, to: value)
        return value
    }

    /// The number of values.
    @inlinable
    public var count: Int {
        dict.count
    }

    /// Whether the values collection is empty.
    @inlinable
    public var isEmpty: Bool {
        dict.isEmpty
    }

    /// The value at the given index.
    ///
    /// - Parameter index: The index.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public subscript(_ index: Int) -> Value {
        get {
            precondition(index >= 0 && index < dict.count, "Index out of bounds")
            return dict._valueStorage._readValue(at: index)
        }
        set {
            precondition(index >= 0 && index < dict.count, "Index out of bounds")
            dict.makeUnique()
            _ = dict._valueStorage._moveValue(at: index)
            dict._valueStorage._initializeValue(at: index, to: newValue)
        }
    }

    /// The value for the given key.
    ///
    /// - Parameter key: The key.
    /// - Returns: The value, or `nil` if not present.
    @inlinable
    public subscript(key key: Key) -> Value? {
        get { dict[key] }
        set {
            if let newValue = newValue {
                dict.set(key, newValue)
            } else {
                dict.remove(key)
            }
        }
    }
}

// MARK: - Sequence Conformance (Copyable values only)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Values: Swift.Sequence {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let storage: Dictionary<Key, Value>.Ordered.ValueStorage

        @usableFromInline
        var index: Int

        @usableFromInline
        let count: Int

        @usableFromInline
        init(_ dict: Dictionary<Key, Value>.Ordered) {
            self.storage = dict._valueStorage
            self.index = 0
            self.count = dict._valueStorage.header
        }

        @inlinable
        public mutating func next() -> Value? {
            guard index < count else { return nil }
            let value = storage._readValue(at: index)
            index += 1
            return value
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(dict)
    }
}

extension Dictionary_Primitives_Core.Dictionary.Ordered.Values.Iterator: @unchecked Sendable where Value: Sendable {}
