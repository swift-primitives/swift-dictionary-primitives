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

public import Dictionary_Primitives_Core
public import Iterable
public import Iterator_Primitive
public import Iterator_Chunk_Primitives

// MARK: - Iterable (multipass, borrowing) — via materialising adapter
//
// The divergent pair type has NO contiguous span of `(key, value)` pairs, so — unlike
// the contiguous single-element containers (set-ordered/stack/heap) which vend
// `Iterator.Chunk` over a `Memory.Contiguous.Protocol` span — `Dictionary` produces its
// bulk iterator by wrapping the scalar `Iterator` in `Iterator.Materializing`, the
// span-primitive adapter for generator-style sequences (the same shape `Single` /
// `Cyclic.Group.Static` use). The dictionary therefore does NOT conform
// `Memory.Contiguous.Protocol` (no pair span exists) — this is NON-CONTIGUOUS storage.
//
// Both `Iterable` and `Sequenceable` declare `associatedtype Iterator`, which Swift
// unifies across protocols; the dual conformer splits the two bindings with
// `@_implements`. `Iterable.Iterator` binds to the materialising bulk iterator here;
// `Sequenceable.Iterator` binds to the scalar `Iterator` (Dictionary+Sequenceable.swift).

extension Dictionary_Primitives_Core.Dictionary: Iterable where Value: Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Materializing<Iterator>

    /// Iterable's bulk span witness: wraps the scalar pair iterator in the generator
    /// materialise adapter.
    @inlinable
    @_lifetime(borrow self)
    @_implements(Iterable, makeIterator())
    public borrowing func iterableMakeIterator() -> Iterator_Primitive.Iterator.Materializing<Iterator> {
        Iterator_Primitive.Iterator.Materializing(Iterator(self))
    }
}
