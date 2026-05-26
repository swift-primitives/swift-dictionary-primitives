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

public import Index_Primitives

extension Dictionary {
    /// Type-safe index for dictionary entries.
    ///
    /// Uses `Index<Key>` to provide compile-time safety preventing
    /// cross-collection index confusion. The index is parameterized on Key
    /// since tuples with ~Copyable elements are not supported.
    ///
    /// ## Position Semantics
    ///
    /// Position 0 is the first entry in insertion order.
    /// The last position is the most recently inserted entry.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let dictIdx: Dictionary<String, Int>.Index = 0
    /// ```
    public typealias Index = Index_Primitives.Index<Key>
}
