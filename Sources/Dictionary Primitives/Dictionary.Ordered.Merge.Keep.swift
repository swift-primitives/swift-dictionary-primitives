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

extension Dictionary.Ordered.Merge {
    /// Namespace for keep-policy merge operations.
    public struct Keep {
        @usableFromInline
        var dict: Dictionary<Key, Value>.Ordered

        @usableFromInline
        init(dict: Dictionary<Key, Value>.Ordered) {
            self.dict = dict
        }
    }
}

// MARK: - Keep Operations

extension Dictionary.Ordered.Merge.Keep {
    /// Merges pairs, keeping the first value for duplicate keys.
    ///
    /// - Parameter pairs: The key-value pairs to merge.
    @inlinable
    public mutating func first(_ pairs: some Sequence<(Key, Value)>) {
        for (key, value) in pairs {
            if !dict.contains(key) {
                dict[key] = value
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
                    dict._values[index] = value
                }
            } else {
                dict[key] = value
            }
        }
    }
}
