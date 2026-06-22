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

public import Buffer_Primitive
public import Buffer_Linear_Primitive
public import Buffer_Protocol_Primitives
public import Store_Protocol_Primitives
public import Storage_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Hash_Indexed_Primitive
import Hash_Primitives
public import Shared_Primitive
public import Index_Primitives

// MARK: - Dictionary (the ADT tier — generic over the ORDERED HASHED entry column)

/// An insertion-ordered hash dictionary — the semantic ADT over an explicit ORDERED
/// HASHED storage COLUMN of key-projected entries (the ADT-families tranche reshape,
/// 2026-06-10; the two-`Buffer.Slab`-planes shape is retired).
///
/// The ratified two-column design: `Dictionary` is generic over `S`, and **copyability
/// flows from the column** (S5):
///
/// ```swift
/// Dictionary<                       Hash.Indexed<Buffer<Storage<…System>.Contiguous<Hash.Entry<Key, FD >>>.Linear>>   // zero-cost MOVE-ONLY (default)
/// Dictionary<Shared<Hash.Entry<…>, Hash.Indexed<Buffer<Storage<…System>.Contiguous<Hash.Entry<Key, Int>>>.Linear>>>  // explicit CoW value semantics
/// ```
///
/// The column is `Hash.Indexed<Dense>` with `Dense.Element == Hash.Entry<Key, Value>`:
/// entries live DENSELY in insertion order; the hash side is the bucket position-index
/// engine (tombstone-free backward shift, per-instance seed), addressing entries by
/// their KEY-projected hash. `Shared` wraps the COMPOSITE — one box, one clone strategy.
///
/// Keys are immutable; values mutate in place behind a hash-stable key
/// (`withMutableValue(forKey:)` — mutability ruling (a)). Iteration (`forEach`) is
/// insertion-ordered.
///
/// This shadows `Swift.Dictionary`. Use `Swift.Dictionary` for the stdlib type when
/// both are in scope.
@frozen
public struct Dictionary<S: Store.`Protocol` & Buffer.`Protocol` & ~Copyable>: ~Copyable
where S.Count == Index_Primitives.Index<S.Element>.Count, S.Element: Hash.Key {

    /// The ordered hashed entry column — move-only (the default ownership column) or
    /// a `Shared` CoW column. The ADT is a thin keyed discipline over it; it carries
    /// NO deinit.
    @usableFromInline
    package var store: S

    /// Wraps an existing column.
    @inlinable
    public init(store: consuming S) {
        self.store = store
    }

    /// Consumes the dictionary, yielding its storage column.
    @inlinable
    public consuming func take() -> S {
        store
    }
}

// MARK: - Conditional Conformances (co-located per [COPY-FIX-004])

/// The S5 chain: `Dictionary<Shared<Hash.Entry<K, V>, B>>` is `Copyable` exactly when
/// the entry is.
extension Dictionary: Copyable where S: Copyable {}

extension Dictionary: Sendable where S: Sendable & ~Copyable {}

// MARK: - Column-pinned construction ([MEM-COPY-017]: the split lives in `Shared`'s
// pinned constructor pair; the `Dictionary` forms pick the column)

extension Dictionary where S: ~Copyable {
    /// Creates an empty MOVE-ONLY dictionary (the default ownership column).
    @inlinable
    public init<K: Hash.Key & ~Copyable, V: ~Copyable>(
        minimumCapacity: Index_Primitives.Index<Hash.Entry<K, V>>.Count = .zero
    )
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Hash.Entry<K, V>>>.Linear> {
        self.init(store: S(minimumCapacity: minimumCapacity))
    }

    /// Creates an empty CoW (value-semantic) dictionary on the `Shared` column.
    @inlinable
    public init<K: Hash.Key, V>(
        minimumCapacity: Index_Primitives.Index<Hash.Entry<K, V>>.Count = .zero
    )
    where S == Shared<Hash.Entry<K, V>, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Hash.Entry<K, V>>>.Linear>> {
        self.init(store: Shared(
            Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Hash.Entry<K, V>>>.Linear>(minimumCapacity: minimumCapacity)
        ))
    }

    /// Creates an empty statically-unique dictionary of move-only values on the
    /// `Shared` column (the boxed flavor of the move-only regime).
    @inlinable
    public init<K: Hash.Key & ~Copyable, V: ~Copyable>(
        minimumCapacity: Index_Primitives.Index<Hash.Entry<K, V>>.Count = .zero
    )
    where S == Shared<Hash.Entry<K, V>, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Hash.Entry<K, V>>>.Linear>> {
        self.init(store: Shared(
            Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Hash.Entry<K, V>>>.Linear>(minimumCapacity: minimumCapacity)
        ))
    }
}
