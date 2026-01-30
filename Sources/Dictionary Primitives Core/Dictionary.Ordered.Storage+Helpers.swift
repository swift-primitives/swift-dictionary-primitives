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

public import Storage_Primitives
public import Index_Primitives

// MARK: - Storage Helper Extensions for Dictionary
//
// These extensions provide convenience methods for Dictionary.Ordered's value storage.
// They handle the Index<Key> -> Index<Value> retag at the storage boundary.

extension Storage where Element: Copyable {
    /// Reads the value at the given key index.
    ///
    /// - Parameter index: The key index (will be retagged to value index).
    /// - Returns: A copy of the value at the index.
    @inlinable
    @inline(__always)
    public func _readValue<Key: ~Copyable>(at index: Index_Primitives.Index<Key>) -> Element {
        let valueIndex = index.retag(Element.self)
        return unsafe pointer(at: valueIndex).pointee
    }

    /// Reads the value at the given raw index (stdlib compatibility).
    ///
    /// - Parameter index: The raw integer index.
    /// - Returns: A copy of the value at the index.
    @inlinable
    @inline(__always)
    public func _readValue(at index: Int) -> Element {
        let valueIndex = Index_Primitives.Index<Element>(Ordinal(UInt(index)))
        return unsafe pointer(at: valueIndex).pointee
    }
}

extension Storage where Element: ~Copyable {
    /// Moves the value at the given key index, leaving the slot uninitialized.
    ///
    /// - Parameter index: The key index (will be retagged to value index).
    /// - Returns: The moved value.
    @inlinable
    @inline(__always)
    public func _moveValue<Key: ~Copyable>(at index: Index_Primitives.Index<Key>) -> Element {
        let valueIndex = index.retag(Element.self)
        return move(at: valueIndex)
    }

    /// Moves the value at the given raw index (stdlib compatibility).
    ///
    /// - Parameter index: The raw integer index.
    /// - Returns: The moved value.
    @inlinable
    @inline(__always)
    public func _moveValue(at index: Int) -> Element {
        let valueIndex = Index_Primitives.Index<Element>(Ordinal(UInt(index)))
        return move(at: valueIndex)
    }

    /// Initializes a value at the given key index.
    ///
    /// - Parameters:
    ///   - index: The key index (will be retagged to value index).
    ///   - value: The value to initialize.
    @inlinable
    @inline(__always)
    public func _initializeValue<Key: ~Copyable>(at index: Index_Primitives.Index<Key>, to value: consuming Element) {
        let valueIndex = index.retag(Element.self)
        initialize(to: value, at: valueIndex)
    }

    /// Initializes a value at the given raw index (stdlib compatibility).
    ///
    /// - Parameters:
    ///   - index: The raw integer index.
    ///   - value: The value to initialize.
    @inlinable
    @inline(__always)
    public func _initializeValue(at index: Int, to value: consuming Element) {
        let valueIndex = Index_Primitives.Index<Element>(Ordinal(UInt(index)))
        initialize(to: value, at: valueIndex)
    }
}
