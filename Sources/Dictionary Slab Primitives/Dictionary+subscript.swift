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
public import Dictionary_Primitives_Core

// MARK: - Subscript Access (Copyable)

extension Dictionary_Primitives_Core.Dictionary where Value: Copyable {
    /// Accesses the value for the given key.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The value if the key exists, or `nil`.
    @inlinable
    public subscript(key: Key) -> Value? {
        get {
            guard
                let position = _hashTable.position(
                    forHash: key.hashValue,
                    equals: { position in
                        _keys[position.retag(Bit.self)] == key
                    }
                )
            else { return nil }
            return _values[position.retag(Bit.self)]
        }
        set {
            if let newValue = newValue {
                set(key, newValue)
            } else {
                remove(key)
            }
        }
    }
}
