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
public import Hash_Table_Primitives
public import Index_Primitives

// MARK: - Copy-on-Write (Copyable values)
//
// `Dictionary` shares storage on copy: when `Value: Copyable`, copying a
// dictionary shares the `Box` of EACH plane (`_keys`, `_values`) — both are
// `Buffer<Storage<…>.Heap>.Slab` whose internal cleanup oracle is a reference
// `Box` (buffer-slab Box-relocation). Copies are observationally independent
// because each mutating op installs a private deep copy of the plane(s) it
// mutates BEFORE writing, via the slab's occupancy-aware `ensureUnique()`.
//
// ## Per-plane divergence
//
// Routing is per-plane: an op that mutates only the values plane diverges only
// `_values`, leaving the keys box shared (that sharing is correct — the shared
// keys are never written, so no copy can observe a divergent key set). The
// keys plane (`_keys`) is always `Copyable` (Key: Hash.Protocol ⇒ Copyable),
// so `_keys.ensureUnique()` is well-formed even in the base `~Copyable`-value
// surface; the values plane requires `Value: Copyable`, which is why the
// divergence-routing surface is gated `where Value: Copyable`.
//
// ## ~Copyable values take NO routing
//
// When `Value: ~Copyable`, `Dictionary` is NOT `Copyable` (its conditional
// `Copyable` conformance holds only `where Value: Copyable`). A non-Copyable
// dictionary cannot be aliased, so no copy can exist to observe a mutation —
// the base `where Value: ~Copyable` ops mutate exclusively-owned storage and
// need no `ensureUnique()`. (`ensureUnique()` on `_values` is also not
// expressible there: it requires `Value: Copyable`.)
//
// ## Scope boundary — the `_hashTable` plane
//
// This routing covers the two STORAGE planes the task owns (`_keys`,
// `_values`). The dictionary has a THIRD shared-on-copy field, `_hashTable`
// (`Hash.Table<Key>`), whose backing `Buffer.Slots` is itself Box-relocated and
// shares on copy. `Hash.Table`'s own mutating ops (`insert`/`remove`) do NOT yet
// route `ensureUnique()`, so a both-plane mutation (insert / remove) that also
// writes `_hashTable` still mutates the SHARED hash-table box. Full copy
// independence for those ops therefore depends on `Hash.Table` adopting the
// dual CoW routing (`_buffer.ensureUnique()` — the slot buffer already vends it)
// in the hash-table package. The values-only update path does not touch
// `_hashTable` and is fully independent today.
//
// ## Mechanism
//
// These methods SHADOW the base `where Value: ~Copyable` ops when
// `Value: Copyable` (constraint-specialised overload resolution selects the
// more-specialised member for Copyable values). They re-implement each op's
// body — routing first, then the same logic the base performs — rather than
// delegating (a delegating call would re-select these same shadows). The
// `subscript` setter and `Sequence.Clearable.removeAll()` inherit divergence
// transitively: they delegate to `set`/`remove`/`clear`, which resolve here.

extension Dictionary_Primitives_Core.Dictionary where Value: Copyable {

    /// Sets the value for the given key (copy-on-write aware), inserting if new
    /// or updating if existing.
    ///
    /// Shadows the base ``set(_:_:)`` when `Value: Copyable`. The update path
    /// mutates only the values plane and diverges only `_values`; the insert
    /// path mutates both planes and diverges both. The keys box stays shared on
    /// a pure update — that sharing is correct.
    ///
    /// - Parameters:
    ///   - key: The key.
    ///   - value: The value to associate with the key.
    /// - Complexity: O(1) amortized, O(occupancy) if a plane copy is triggered.
    @inlinable
    public mutating func set(_ key: Key, _ value: Value) {
        let hashValue = key.hashValue

        if let existingPosition = _hashTable.position(
            forHash: hashValue,
            equals: { position in
                _keys[position.retag(Bit.self)] == key
            }
        ) {
            // Update: mutates ONLY the values plane → diverge only `_values`.
            _values.ensureUnique()
            let slot = existingPosition.retag(Bit.self)
            _ = _values.update(at: slot, with: value)
        } else {
            // Insert: mutates BOTH planes → diverge both before any write.
            // (Diverge before the `isFull`/`_grow` check: `_grow` drains the
            // shared boxes in place, so the boxes must be private first.)
            _keys.ensureUnique()
            _values.ensureUnique()
            if _keys.isFull {
                _grow()
            }
            guard let slot = _keys.firstVacant() else {
                fatalError("No vacant slot after growth")
            }
            _keys.insert(key, at: slot)
            _values.insert(value, at: slot)
            _hashTable.insert(
                _unchecked: (),
                position: slot.retag(Key.self),
                hashValue: hashValue
            )
        }
    }

    /// Removes the value for the given key (copy-on-write aware).
    ///
    /// Shadows the base ``remove(_:)`` when `Value: Copyable`. Removal mutates
    /// both planes, so both `_keys` and `_values` are diverged before the write.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if the key was not present.
    /// - Complexity: O(1) average, O(occupancy) if a plane copy is triggered.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        let hashValue = key.hashValue

        guard
            let removedPosition = _hashTable.remove(
                hashValue: hashValue,
                equals: { position in
                    _keys[position.retag(Bit.self)] == key
                }
            )
        else {
            return nil
        }

        // Removal mutates BOTH planes → diverge both before the write.
        _keys.ensureUnique()
        _values.ensureUnique()
        let slot = removedPosition.retag(Bit.self)
        _ = _keys.remove(at: slot)
        return _values.remove(at: slot)
    }

    /// Removes all key-value pairs (copy-on-write aware).
    ///
    /// Shadows the base ``clear(keepingCapacity:)`` when `Value: Copyable`.
    /// When `keepingCapacity` is `true`, both planes are mutated in place and
    /// both are diverged first. When `false`, both planes are replaced wholesale
    /// with fresh slabs — reassignment installs new boxes and is inherently
    /// divergence-safe, so no `ensureUnique()` is needed on that path.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current storage capacity.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        if keepingCapacity {
            // In-place clear of both planes → diverge both first.
            _keys.ensureUnique()
            _values.ensureUnique()
            _keys.removeAll()
            _values.removeAll()
            _hashTable.remove.all(keepingCapacity: true)
        } else {
            // Wholesale replacement: reassignment installs fresh boxes; an
            // aliasing copy keeps the old boxes untouched. No routing needed.
            _keys = Buffer<Storage<Key>.Heap>.Slab(minimumCapacity: .zero)
            _values = Buffer<Storage<Value>.Heap>.Slab(minimumCapacity: _keys.capacity.retag(Value.self))
            _hashTable.remove.all(keepingCapacity: false)
        }
    }

    /// Drains all key-value pairs from the dictionary (copy-on-write aware),
    /// passing each to the closure.
    ///
    /// Shadows the base ``drain(_:)`` when `Value: Copyable`. The drain loop
    /// removes from both planes in place, so both are diverged before iterating.
    /// After this returns, the dictionary is empty but still usable.
    ///
    /// - Parameter body: A closure that receives each entry with ownership.
    /// - Complexity: O(n), O(n + occupancy) if a plane copy is triggered.
    @inlinable
    public mutating func drain(_ body: (consuming Entry) -> Void) {
        // The drain loop mutates BOTH planes in place → diverge both first.
        _keys.ensureUnique()
        _values.ensureUnique()
        // Typed while loop: mutating during iteration requires manual control.
        // Early termination via remaining count avoids scanning vacant tail slots.
        var slot: Bit.Index = .zero
        let end = _keys.capacity.map(Ordinal.init)
        var remaining = _keys.occupancy
        while slot < end, remaining != .zero {
            if _keys.isOccupied(at: slot) {
                let key = _keys.remove(at: slot)
                let value = _values.remove(at: slot)
                body(Entry(key: key, value: value))
                remaining = remaining.subtract.saturating(.one)
            }
            slot += .one
        }
        _hashTable.remove.all(keepingCapacity: true)
    }
}
