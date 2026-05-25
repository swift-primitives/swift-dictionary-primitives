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

public import Buffer_Slab_Primitive
public import Hash_Table_Primitives
public import Index_Primitives
public import Buffer_Linear_Inline_Primitive

// MARK: - Lookup

extension Dictionary_Primitives_Core.Dictionary where Value: ~Copyable {
    /// Returns whether the dictionary contains the given key.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if the key exists.
    /// - Complexity: O(1) average.
    @inlinable
    public func contains(_ key: Key) -> Bool {
        let hashValue = key.hashValue
        return _hashTable.position(
            forHash: hashValue,
            equals: { position in
                _keys[position.retag(Bit.self)] == key
            }
        ) != nil
    }
}
