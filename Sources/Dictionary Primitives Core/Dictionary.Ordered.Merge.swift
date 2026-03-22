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

internal import Set_Primitives

// MARK: - Merge Accessor (Copyable values only)
//
// Merge operations require iterating over sequences of values, which requires
// copying. For ~Copyable values, merge operations are not available.
//
// NOTE: Merge and Keep remain as concrete structs rather than using Property<Tag, Base>
// because the nested accessor pattern (dict.merge.keep.first()) requires:
// 1. `.keep` to be a property (not a method)
// 2. Properties cannot introduce generic parameters
// 3. If we extended Property_Primitives.Property, we'd lose access to Key/Value
// See: "Protocol Conformance and Phantom Type Generalization" paper.

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: Copyable {
    /// Nested accessor for merge operations.
    ///
    /// ```swift
    /// dict.merge.keep.first(pairs)
    /// dict.merge.keep.last(pairs)
    /// ```
    ///
    /// - Note: Merge operations are only available when `Value` is `Copyable`.
    @inlinable
    public var merge: Merge {
        get { Merge(dict: self) }
        _modify {
            var proxy = Merge(dict: self)
            defer { self = proxy.dict }
            yield &proxy
        }
    }
}

// MARK: - Merge Type (Copyable values only)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: Copyable {
    /// Namespace for merge operations.
    ///
    /// Available only when `Value` is `Copyable`.
    public struct Merge {
        @usableFromInline
        var dict: Dictionary_Primitives_Core.Dictionary<Key, Value>.Ordered

        @usableFromInline
        init(dict: Dictionary_Primitives_Core.Dictionary<Key, Value>.Ordered) {
            self.dict = dict
        }
    }
}

// MARK: - Merge Keep Accessor (Copyable values only)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Merge {
    /// Nested accessor for keep-policy merge operations.
    @inlinable
    public var keep: Keep {
        get { Keep(dict: dict) }
        _modify {
            var proxy = Keep(dict: dict)
            defer { dict = proxy.dict }
            yield &proxy
        }
    }
}
