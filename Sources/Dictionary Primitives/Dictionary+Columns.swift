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

// The COLUMN-PINNED keyed surface; the `Shared` forms cross the box via the
// gate-first scoped accessors ([MEM-OWN-017]: inserted entries thread as consuming
// closure PARAMETERS). Lookups go through the engine's projected-key doors — the
// key probes the index planes directly; no entry is constructed to search.
public import Dictionary_Primitive
public import Buffer_Primitive
public import Buffer_Linear_Primitive
public import Storage_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Hash_Indexed_Primitive
import Hash_Primitives
public import Shared_Primitive
public import Index_Primitives

// ============================================================================
// MARK: - Insert (displaced-value hand-back — move-only honesty)
// ============================================================================

extension Dictionary where S: ~Copyable {
    /// Sets the value for a key; returns the DISPLACED old value if the key was
    /// present, or `nil` on a fresh insertion. On replacement the stored entry keeps
    /// its ORIGINAL key instance (direct column).
    ///
    /// - Complexity: O(1) amortized
    @inlinable
    @discardableResult
    public mutating func insert<K: Hash.Key & ~Copyable, V: ~Copyable>(key: consuming K, value: consuming V) -> V?
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Hash.Entry<K, V>>>.Linear> {
        if let slot = store.position(
            matching: key.hashValue,
            context: key,
            equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in candidate.key == probe }
        ) {
            var displaced = consume value
            swap(&store[slot].value, &displaced)
            return displaced
        }
        _ = store.insert(Hash.Entry(key: key, value: value))
        return nil
    }

    /// Sets the value for a key (`Shared` column; uniqueness restored first).
    ///
    /// - Complexity: O(1) amortized (O(`capacity`) when a copy must be made first)
    @inlinable
    @discardableResult
    public mutating func insert<K: Hash.Key & ~Copyable, V: ~Copyable>(key: consuming K, value: consuming V) -> V?
    where S == Shared<Hash.Entry<K, V>, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Hash.Entry<K, V>>>.Linear>> {
        store.withUnique(consuming: Hash.Entry(key: key, value: value)) { column, entry in
            if let slot = column.position(
                matching: entry.hashValue,
                context: entry,
                equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing Hash.Entry<K, V>) in candidate == probe }
            ) {
                // Key present: swap the new value into the stored entry (its original
                // key stays), hand the old value back through the probe entry's shell.
                var displaced = consume entry
                swap(&column[slot].value, &displaced.value)
                return displaced.take()
            }
            _ = column.insert(entry)
            return nil
        }
    }
}

// ============================================================================
// MARK: - Lookup
// ============================================================================

extension Dictionary where S: ~Copyable {
    /// Whether a value exists for the key (direct column).
    ///
    /// - Complexity: O(1) average
    @inlinable
    public func contains<K: Hash.Key & ~Copyable, V: ~Copyable>(key: borrowing K) -> Bool
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Hash.Entry<K, V>>>.Linear> {
        store.position(
            matching: key.hashValue,
            context: key,
            equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in candidate.key == probe }
        ) != nil
    }

    /// Whether a value exists for the key (`Shared` column; no gate — reads never detach).
    ///
    /// - Complexity: O(1) average
    @inlinable
    public func contains<K: Hash.Key & ~Copyable, V: ~Copyable>(key: borrowing K) -> Bool
    where S == Shared<Hash.Entry<K, V>, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Hash.Entry<K, V>>>.Linear>> {
        store.withColumn { column in
            column.position(
                matching: key.hashValue,
                context: key,
                equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in candidate.key == probe }
            ) != nil
        }
    }

    /// Calls the closure with the value for the key; returns its result, or `nil`
    /// if the key is absent (direct column).
    ///
    /// - Complexity: O(1) average, plus the closure
    @inlinable
    public func withValue<K: Hash.Key & ~Copyable, V: ~Copyable, R>(forKey key: borrowing K, _ body: (borrowing V) -> R) -> R?
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Hash.Entry<K, V>>>.Linear> {
        guard let slot = store.position(
            matching: key.hashValue,
            context: key,
            equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in candidate.key == probe }
        ) else {
            return nil
        }
        return body(store[slot].value)
    }

    /// Calls the closure with the value for the key (`Shared` column; no gate).
    ///
    /// - Complexity: O(1) average, plus the closure
    @inlinable
    public func withValue<K: Hash.Key & ~Copyable, V: ~Copyable, R>(forKey key: borrowing K, _ body: (borrowing V) -> R) -> R?
    where S == Shared<Hash.Entry<K, V>, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Hash.Entry<K, V>>>.Linear>> {
        store.withColumn { column -> R? in
            guard let slot = column.position(
                matching: key.hashValue,
                context: key,
                equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in candidate.key == probe }
            ) else {
                return nil
            }
            return body(column[slot].value)
        }
    }
}

// ============================================================================
// MARK: - Value mutation (mutability ruling (a): keys are hash-stable, so the
// indexed seam's re-index guard takes its cheap no-change branch)
// ============================================================================

extension Dictionary where S: ~Copyable {
    /// Calls the closure with mutable access to the value for the key; returns its
    /// result, or `nil` if the key is absent (direct column).
    ///
    /// - Complexity: O(1) average, plus the closure
    @inlinable
    public mutating func withMutableValue<K: Hash.Key & ~Copyable, V: ~Copyable, R>(forKey key: borrowing K, _ body: (inout V) -> R) -> R?
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Hash.Entry<K, V>>>.Linear> {
        guard let slot = store.position(
            matching: key.hashValue,
            context: key,
            equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in candidate.key == probe }
        ) else {
            return nil
        }
        return body(&store[slot].value)
    }

    /// Calls the closure with mutable access to the value for the key (`Shared`
    /// column; uniqueness restored first).
    ///
    /// - Complexity: O(1) average (O(`capacity`) when a copy must be made first), plus the closure
    @inlinable
    public mutating func withMutableValue<K: Hash.Key & ~Copyable, V: ~Copyable, R>(forKey key: borrowing K, _ body: (inout V) -> R) -> R?
    where S == Shared<Hash.Entry<K, V>, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Hash.Entry<K, V>>>.Linear>> {
        store.withUnique { column -> R? in
            guard let slot = column.position(
                matching: key.hashValue,
                context: key,
                equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in candidate.key == probe }
            ) else {
                return nil
            }
            return body(&column[slot].value)
        }
    }
}

// ============================================================================
// MARK: - Remove (insertion order preserved)
// ============================================================================

extension Dictionary where S: ~Copyable {
    /// Removes the entry for the key; returns its value, or `nil` if absent
    /// (direct column).
    ///
    /// - Complexity: O(n) from the removal point (order preservation)
    @inlinable
    public mutating func removeValue<K: Hash.Key & ~Copyable, V: ~Copyable>(forKey key: borrowing K) -> V?
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Hash.Entry<K, V>>>.Linear> {
        guard let entry = store.remove(
            matching: key.hashValue,
            context: key,
            equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in candidate.key == probe }
        ) else {
            return nil
        }
        return entry.take()
    }

    /// Removes the entry for the key (`Shared` column; uniqueness restored first).
    @inlinable
    public mutating func removeValue<K: Hash.Key & ~Copyable, V: ~Copyable>(forKey key: borrowing K) -> V?
    where S == Shared<Hash.Entry<K, V>, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Hash.Entry<K, V>>>.Linear>> {
        store.withUnique { column -> V? in
            guard let entry = column.remove(
                matching: key.hashValue,
                context: key,
                equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in candidate.key == probe }
            ) else {
                return nil
            }
            return entry.take()
        }
    }

    /// Removes all entries (direct column).
    @inlinable
    public mutating func removeAll<K: Hash.Key & ~Copyable, V: ~Copyable>(keepingCapacity: Bool = true)
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Hash.Entry<K, V>>>.Linear> {
        store.removeAll(keepingCapacity: keepingCapacity)
    }

    /// Removes all entries (`Shared` column; detaches first — siblings keep theirs).
    @inlinable
    public mutating func removeAll<K: Hash.Key & ~Copyable, V: ~Copyable>(keepingCapacity: Bool = true)
    where S == Shared<Hash.Entry<K, V>, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Hash.Entry<K, V>>>.Linear>> {
        let capacity: Index_Primitives.Index<Hash.Entry<K, V>>.Count = keepingCapacity ? store.capacity : .zero
        self.store = Shared(
            Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Hash.Entry<K, V>>>.Linear>(minimumCapacity: capacity)
        )
    }
}

// ============================================================================
// MARK: - Iteration (insertion order) + direct clone
// ============================================================================

extension Dictionary where S: ~Copyable {
    /// Calls the closure for each key–value pair, in insertion order (direct column).
    ///
    /// - Complexity: O(n)
    @inlinable
    public func forEach<K: Hash.Key & ~Copyable, V: ~Copyable>(_ body: (borrowing K, borrowing V) -> Void)
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Hash.Entry<K, V>>>.Linear> {
        store.forEach { entry in body(entry.key, entry.value) }
    }

    /// Calls the closure for each key–value pair (`Shared` column; no gate).
    ///
    /// - Complexity: O(n)
    @inlinable
    public func forEach<K: Hash.Key & ~Copyable, V: ~Copyable>(_ body: (borrowing K, borrowing V) -> Void)
    where S == Shared<Hash.Entry<K, V>, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Hash.Entry<K, V>>>.Linear>> {
        store.withColumn { column in
            column.forEach { entry in body(entry.key, entry.value) }
        }
    }

    /// Returns an independent copy (direct column).
    ///
    /// - Complexity: O(`capacity`)
    @inlinable
    public func clone<K: Hash.Key, V>() -> Self
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<Hash.Entry<K, V>>>.Linear> {
        Self(store: store.clone())
    }
}
