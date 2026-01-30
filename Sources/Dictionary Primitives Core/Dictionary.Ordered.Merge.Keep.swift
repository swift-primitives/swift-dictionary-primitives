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

extension Dictionary_Primitives_Core.Dictionary.Ordered.Merge {
    /// Namespace for keep-policy merge operations.
    ///
    /// Keep-policy merges resolve key conflicts by retaining either the existing
    /// value (`.first`) or the incoming value (`.last`), without changing key order.
    ///
    /// ## Algebraic Laws
    ///
    /// For ordered dictionaries `A` and `B`, and sequence of pairs `S`:
    ///
    /// **Identity**: `A.merge.keep.first([]) == A` and `A.merge.keep.last([]) == A`
    ///
    /// **Idempotence**: `A.merge.keep.first(A) == A` and `A.merge.keep.last(A) == A`
    ///
    /// **Order Preservation**: Merge operations never reorder existing keys in `A`
    ///
    /// Available only when `Value` is `Copyable`.
    public struct Keep {
        @usableFromInline
        var dict: Dictionary_Primitives_Core.Dictionary<Key, Value>.Ordered

        @usableFromInline
        init(dict: Dictionary_Primitives_Core.Dictionary<Key, Value>.Ordered) {
            self.dict = dict
        }
    }
}

// MARK: - Keep Operations (Copyable values only)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Merge.Keep {
    /// Merges pairs, keeping the first (existing) value for duplicate keys.
    ///
    /// ## Algebraic Law
    ///
    /// For ordered dictionary `A` and sequence `S`:
    ///
    /// ```
    /// A.merge.keep.first(S) produces A' where:
    ///   - All keys in A retain their original values and positions
    ///   - Keys in S not present in A are appended in S's iteration order
    ///   - Keys in S already present in A are ignored
    /// ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// var dict: [a:1, b:2]
    /// dict.merge.keep.first([(b:20), (c:3)])
    /// // Result: [a:1, b:2, c:3]  (b keeps value 2)
    /// ```
    ///
    /// - Parameter pairs: The key-value pairs to merge.
    /// - Complexity: O(n) where n is the length of pairs.
    @inlinable
    public mutating func first(_ pairs: some Swift.Sequence<(Key, Value)>) {
        for (key, value) in pairs {
            if !dict.contains(key) {
                dict.set(key, value)
            }
        }
    }

    /// Merges pairs, keeping the last (incoming) value for duplicate keys.
    ///
    /// ## Algebraic Law
    ///
    /// For ordered dictionary `A` and sequence `S`:
    ///
    /// ```
    /// A.merge.keep.last(S) produces A' where:
    ///   - All keys in A retain their original positions
    ///   - Keys in S already present in A have their values updated in-place
    ///   - Keys in S not present in A are appended in S's iteration order
    /// ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// var dict: [a:1, b:2]
    /// dict.merge.keep.last([(b:20), (c:3)])
    /// // Result: [a:1, b:20, c:3]  (b updated to 20, position unchanged)
    /// ```
    ///
    /// - Parameter pairs: The key-value pairs to merge.
    /// - Complexity: O(n) where n is the length of pairs.
    @inlinable
    public mutating func last(_ pairs: some Swift.Sequence<(Key, Value)>) {
        for (key, value) in pairs {
            if dict.contains(key) {
                // Update value without changing position
                if let index = dict._keys.index(key) {
                    dict.makeUnique()
                    _ = dict._values._moveValue(at: index)
                    dict._values._initializeValue(at: index, to: value)
                }
            } else {
                dict.set(key, value)
            }
        }
    }
}
