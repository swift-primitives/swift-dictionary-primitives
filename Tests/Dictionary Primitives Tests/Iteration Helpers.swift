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

import Iterable
import Testing

@testable import Dictionary_Primitives

// MARK: - Iteration helpers (post-Swift.Sequence-drop)
//
// `Dictionary` (unordered, slab-backed) no longer conforms to `Swift.Sequence`; iteration
// is via the span-primitive `Iterable` floor (`forEach`). This helper materialises an
// `Iterable` into a `[Element]` for assertions, mirroring the ordered exemplar's and
// set-ordered's `toArray` test helper.

/// Materialises any `Iterable` into an array of its elements, preserving iteration order.
func toArray<S: Iterable & ~Copyable>(_ source: borrowing S) -> [S.Iterator.Element]
where S.Iterator.Failure == Never {
    var result: [S.Iterator.Element] = []
    source.forEach { result.append($0) }
    return result
}
