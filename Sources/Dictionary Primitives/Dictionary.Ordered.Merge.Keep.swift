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

// MARK: - Keep Type (Copyable values only)

extension Dictionary_Primitives.Dictionary.Ordered.Merge {
    /// Namespace for keep-policy merge operations.
    ///
    /// Available only when `Value` is `Copyable`.
    public struct Keep {
        @usableFromInline
        var dict: Dictionary<Key, Value>.Ordered

        @usableFromInline
        init(dict: Dictionary<Key, Value>.Ordered) {
            self.dict = dict
        }
    }
}

// MARK: - Keep Operations (Copyable values only)

extension Dictionary_Primitives.Dictionary.Ordered.Merge.Keep {
    /// Merges pairs, keeping the first value for duplicate keys.
    ///
    /// - Parameter pairs: The key-value pairs to merge.
    @inlinable
    public mutating func first(_ pairs: some Sequence<(Key, Value)>) {
        for (key, value) in pairs {
            if !dict.contains(key) {
                dict.set(key, value)
            }
        }
    }

    /// Merges pairs, keeping the last value for duplicate keys.
    ///
    /// - Parameter pairs: The key-value pairs to merge.
    @inlinable
    public mutating func last(_ pairs: some Sequence<(Key, Value)>) {
        for (key, value) in pairs {
            if dict.contains(key) {
                // Update value without changing position
                if let index = dict._keys.index(key) {
                    dict.makeUnique()
                    _ = dict._valueStorage._moveValue(at: index)
                    dict._valueStorage._initializeValue(at: index, to: value)
                }
            } else {
                dict.set(key, value)
            }
        }
    }
}
