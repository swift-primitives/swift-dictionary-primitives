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
public import Sequence_Primitives

// MARK: - Sequenceable (single-pass, consuming)
//
// Re-uses the scalar pair `Iterator` (single-pass, consuming). This conformance is thin
// and splits the `Iterator` associated-type binding from `Iterable`'s via `@_implements`.
//
// `Dictionary` does not conform to `Swift.Sequence`: the span-primitive iteration family is
// `~Copyable, ~Escapable` end-to-end and cannot back a Copyable stdlib `IteratorProtocol`
// without re-introducing a per-type Copyable iterator. This is the DEFERRED
// `Swift.Sequence`-interop axis settled ecosystem-wide — see
// set-ordered-capability-composition.md §2.8 / §3. The dropped per-type `Swift.Sequence`
// conformance (and the `Swift.Collection` family where present) is a deliberate
// consumer-facing removal to match the exemplar (swift-dictionary-ordered-primitives).

extension Dictionary_Primitives_Core.Dictionary: Sequenceable where Value: Copyable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Iterator

    /// A single-pass consuming iterator over key-value pairs. Witness for `Sequenceable`.
    @inlinable
    public consuming func makeIterator() -> Iterator {
        Iterator(self)
    }

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}
