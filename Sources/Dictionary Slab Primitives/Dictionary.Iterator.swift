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
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
public import Dictionary_Primitives_Core
public import Iterator_Primitive
public import Bit_Vector_Bounded_Primitives
internal import Index_Primitives
internal import Sequence_Primitives

// MARK: - Scalar pair iterator
//
// The divergent case: `Dictionary`'s element is `(key: Key, value: Value)`, a pair split
// across two parallel slab buffers (`_keys: Buffer.Slab`, `_values: Buffer.Slab`). There
// is NO contiguous span of pairs, so the dictionary cannot vend `Iterator.Chunk` over a
// `span` the way contiguous single-element containers (set-ordered, stack, heap) do.
// Instead this scalar `Iterator.`Protocol`` synthesises each pair by walking the occupied
// slots via the bitmap iterator (Wegner/Kernighan bit extraction); the bulk-iteration face
// is produced by wrapping it in `Iterator.Materializing` (see Dictionary+Iterable.swift),
// exactly as the generator-style single/cyclic iterators do.
//
// Hand-written `~Copyable`-shaped scalar iterator (GR3-irreducible — confirmed-active
// demangle bug); it is NOT deduped via a generic cursor.

extension Dictionary_Primitives_Core.Dictionary where Value: Copyable {
    /// A single-pass scalar iterator over the dictionary's key-value pairs.
    ///
    /// Copies slab storage at creation for safe iteration independent of mutations.
    /// Visits occupied slots via bitmap iterator (Wegner/Kernighan bit extraction).
    ///
    /// This is the scalar `Iterator.`Protocol`` source the materialising bulk iterator
    /// (`Iterator.Materializing`) wraps for the `Iterable` face, and the iterator the
    /// consuming `Sequenceable` face vends directly.
    ///
    /// - Complexity: O(count) total via bitmap iteration, not O(capacity).
    ///
    /// - Note: The iterator captures each plane's `Buffer.Slab` (sharing its
    ///   `Box`) at creation, giving it an independent snapshot. Under the
    ///   copy-on-write contract (see ``Dictionary+CoW``) a subsequent dictionary
    ///   mutation diverges the dictionary's plane into a fresh `Box`, leaving the
    ///   iterator's captured `Box` untouched — so a stored iterator observes a
    ///   stable snapshot even across mutations between `next()` calls.
    public struct Iterator: Iterator_Primitive.Iterator.`Protocol`, IteratorProtocol {
        public typealias Element = (key: Key, value: Value)

        @usableFromInline
        let _keys: Buffer<Storage<Key>.Contiguous<Memory.Heap<Key>>>.Slab

        @usableFromInline
        let _values: Buffer<Storage<Value>.Contiguous<Memory.Heap<Value>>>.Slab

        @usableFromInline
        var _occupiedSlots: Bit.Vector.Ones.Bounded.Iterator

        @usableFromInline
        var _element: Element? = nil

        @usableFromInline
        init(_ dict: borrowing Dictionary<Key, Value>) {
            let occupiedSlots = dict._keys.occupiedSlots
            self._keys = dict._keys
            self._values = dict._values
            self._occupiedSlots = occupiedSlots.makeIterator()
        }

        @inlinable
        public mutating func next() -> Element? {
            guard let slot = _occupiedSlots.next() else { return nil }
            return (key: _keys[slot], value: _values[slot])
        }
    }
}
