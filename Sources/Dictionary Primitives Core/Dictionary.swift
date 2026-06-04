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
internal import Hash_Table_Primitives
public import Index_Primitives
public import Set_Primitives

// ===----------------------------------------------------------------------===//
// MARK: - Semantic Invariants
// ===----------------------------------------------------------------------===//
//
// This section documents the fundamental invariants that define Dictionary.Ordered.
// These invariants MUST be preserved by all implementations, optimizations, and
// future modifications.
//
// ## Canonical Ordering
//
// Key order is canonical. Values are strictly indexed by key order.
//
// - The ordered key set (`_keys: Set<Key>.Ordered`) is the source of truth for ordering
// - Value storage indices correspond 1:1 with key indices
// - `_keys[i]` and `_values[i]` always refer to the same key-value pair
//
// ## Ordering Semantics
//
// - Insertion appends to end: new keys always go to index `count`
// - Update preserves position: changing a value for existing key does NOT move it
// - Removal shifts indices: removing key at index `i` shifts all keys at `i+1...` down
// - Re-insertion after removal goes to end: removed keys lose their position
//
// ## What Must Never Happen
//
// - Key and value arrays must never have different counts
// - Key at index `i` must always map to value at index `i`
// - Duplicate keys must never exist (enforced by Set<Key>.Ordered)
// - Value storage must never contain uninitialized memory within `0..<count`
//
// ## What Optimizations Must Preserve
//
// - Iteration order equals insertion order (minus removals)
// - Index-based access is O(1)
// - Key lookup is O(1) average (hash-based)
// - Equality considers order: `[a:1, b:2] != [b:2, a:1]`
//
// ## Copyable Boundaries
//
// - Keys must conform to Hash.Protocol (supports ~Copyable keys)
// - Values may be ~Copyable (move-only)
// - Copy-on-Write applies when Value: Copyable (see ``Dictionary+CoW``): copies
//   share each plane's storage until a mutation diverges exactly the plane(s) it
//   mutates. ~Copyable-value dictionaries are not Copyable, cannot be aliased,
//   and take no routing.
// - Base methods use `consuming Value`; CoW methods use `Value`
//
// ===----------------------------------------------------------------------===//

/// An unordered dictionary backed by slab storage with O(1) removal.
///
/// `Dictionary` uses hash-indexed sparse slab storage for both keys and values.
/// Positions are stable across removals — no element shifting occurs.
///
/// This shadows `Swift.Dictionary`. Use `Swift.Dictionary` or module-qualified
/// `Dictionary_Primitives_Core.Dictionary` to disambiguate when both are in scope.
///
/// ## Variants
///
/// - `Dictionary<K, V>()` — unordered, slab-backed, O(1) removal (this type)
/// - `Dictionary<K, V>.Ordered()` — insertion-ordered, linear-backed, O(n) removal
///
/// ## Composition
///
/// ```
/// Dictionary<Key, Value>
/// ├── _hashTable: Hash.Table<Key>         — hash-to-position lookup
/// ├── _keys: Buffer<Storage<Key>.Heap>.Slab             — sparse key storage
/// └── _values: Buffer<Storage<Value>.Heap>.Slab         — sparse value storage
/// ```
// WHY: Category D — structural Sendable workaround; the type is
// WHY: structurally value-safe but the compiler cannot synthesize
// WHY: Sendable due to a stored pointer / generic parameter shape.
@safe
public struct Dictionary<Key: Hash.`Protocol`, Value: ~Copyable>: ~Copyable {

    // MARK: - Storage

    public var _hashTable: Hash.Table<Key>

    public var _keys: Buffer<Storage<Key>.Heap>.Slab

    public var _values: Buffer<Storage<Value>.Heap>.Slab

    // MARK: - Init

    /// Creates an empty unordered dictionary.
    ///
    /// - Parameter minimumCapacity: The minimum number of key-value pairs to
    ///   reserve space for. Defaults to zero.
    @inlinable
    public init(minimumCapacity: Index_Primitives.Index<Key>.Count = .zero) {
        self._hashTable = Hash.Table<Key>(minimumCapacity: minimumCapacity)
        self._keys = Buffer<Storage<Key>.Heap>.Slab(minimumCapacity: minimumCapacity)
        // Use keys' actual capacity so values.capacity >= keys.capacity.
        // ManagedBuffer rounds up differently per element stride — without this,
        // a slot valid for keys could exceed values' bitmap bounds.
        self._values = Buffer<Storage<Value>.Heap>.Slab(minimumCapacity: self._keys.capacity.retag(Value.self))
    }

    // Note: No explicit deinit needed — Buffer.Slab handles cleanup via bitmap-driven deinitialization
}

// MARK: - Conditional Copyable

/// `Dictionary` (unordered) is `Copyable` when its values are `Copyable`.
///
/// This works because when `Value: Copyable`:
/// - `Hash.Table<Key>`: already conditionally Copyable
/// - `Buffer<Storage<Key>.Heap>.Slab`: Copyable (Key is always Copyable via `Hash.Protocol`)
/// - `Buffer<Storage<Value>.Heap>.Slab`: Copyable when Value: Copyable
extension Dictionary_Primitives_Core.Dictionary: Copyable where Value: Copyable {}

// Note: Dictionary.Ordered.Small and Dictionary.Ordered.Static are UNCONDITIONALLY ~Copyable due to inline storage deinit

// MARK: - Sendable

extension Dictionary_Primitives_Core.Dictionary: @unsafe @unchecked Sendable where Key: Sendable, Value: Sendable {}

// MARK: - Iteration Conformances
//
// Iteration is provided by the span-primitive model (recipe-2, non-contiguous) in the
// `Dictionary Slab Primitives` variant module, gated `where Value: Copyable`:
// - `Iterable` (multipass, borrowing) via `Iterator.Materializing` over the scalar iterator
// - `Sequenceable` (single-pass, consuming) via the scalar iterator directly
// - `Sequence.Clearable` (enables `.forEach.consuming { }`)
//
// `Dictionary` (unordered, slab-backed, NON-CONTIGUOUS) does NOT conform to `Swift.Sequence`,
// `Swift.Collection`, or `Memory.Contiguous` — the dropped per-type stdlib bridges are a
// deliberate consumer-facing removal matching the ordered exemplar.
//
// For ~Copyable values, use the per-type `forEach(_:)` (Property.Borrow) or `drain(_:)`.
