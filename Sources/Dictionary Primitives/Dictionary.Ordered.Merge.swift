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

// MARK: - Merge Accessor

extension Dictionary.Ordered {
    /// Nested accessor for merge operations.
    ///
    /// ```swift
    /// dict.merge.keep.first(pairs)
    /// dict.merge.keep.last(pairs)
    /// ```
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

// MARK: - Merge Type

extension Dictionary.Ordered {
    /// Namespace for merge operations.
    public struct Merge {
        @usableFromInline
        var dict: Dictionary<Key, Value>.Ordered

        @usableFromInline
        init(dict: Dictionary<Key, Value>.Ordered) {
            self.dict = dict
        }
    }
}

// MARK: - Merge Keep Accessor

extension Dictionary.Ordered.Merge {
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
