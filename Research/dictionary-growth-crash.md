# Dictionary Growth Crash Investigation

<!--
---
version: 1.0.0
last_updated: 2026-02-24
status: IN_PROGRESS
---
-->

## Context

Phase 2b restructured `Buffer.Slab` to use `Storage<Element>.Slab` (class, owns deinit) instead of having `deinit` directly on `Buffer.Slab`. This enables conditional `Copyable` conformance. After the restructuring, inserting >33 elements into `Dictionary<String, Int>` crashes with:

```
Bit_Vector_Primitives/Bit.Vector.Bounded.swift:149: Precondition failed: Index out of bounds
```

Line 149 is the `Bit.Vector.Bounded` subscript setter:
```swift
precondition(index < _count, "Index out of bounds")
```

The crash threshold is inconsistent between runs (34-35 elements), suggesting hash-distribution dependence.

## Question

What causes the `Bit.Vector.Bounded` subscript setter to receive an `index >= _count` during Dictionary growth, and what is the correct fix?

## Analysis

### Code Path Trace

**Growth trigger** (`Dictionary+set.swift:36`):
```swift
if _keys.isFull { _grow() }
```

**Growth method** (`Dictionary ~Copyable.swift:120-154`):
1. Computes `newCapacity = max(8, occupancy * 2)`
2. Creates new `Buffer.Slab` and `Hash.Table`
3. Iterates old buffer, moves elements to new buffer via `firstVacant()` + `insert()`
4. Replaces `_keys`, `_values`, `_hashTable`

**The crash site** is `header.bitmap[slot] = true` in `Buffer.Slab.insert` (static, `Buffer.Slab+Heap ~Copyable.swift:20`).

### Bitmap Initialization Chain

```
Dictionary._grow()
  → Buffer.Slab.init(minimumCapacity:)            [Buffer.Slab.swift:11-17]
    → Storage.Slab.init(minimumCapacity:)          [Storage.Slab ~Copyable.swift:24-31]
      → Storage.Heap.create(minimumCapacity:)      → ManagedBuffer (rounds up)
      → Bit.Vector.Bounded(capacity: heap.slotCapacity, count: heap.slotCapacity)
    → Header(capacity: storage.slotCapacity)       [Buffer.swift:575-576]
      → Bit.Vector.Bounded(capacity: cap, count: cap)
```

Both the Storage.Slab bitmap and the Header bitmap are created with `_count == _capacity == heap.slotCapacity`.

### Hypothesis 1: `_count` vs `_capacity` semantics mismatch

**Bit.Vector.Bounded** uses `_count` as the logical size for subscript bounds checking:
- Subscript: `precondition(index < _count)`
- `isFull`: `_count >= _capacity`
- `append`: increments `_count`

For a **slab bitmap**, `_count` should equal `_capacity` because all positions are addressable — the bitmap tracks which of the N slots are occupied, and all N positions are valid subscript targets.

The initialization `count: heap.slotCapacity` correctly makes all slots addressable. **This hypothesis is ELIMINATED** — `_count == _capacity` is correct for slab bitmaps.

### Hypothesis 2: ManagedBuffer capacity rounding creates divergence

`ManagedBuffer.create(minimumCapacity:)` may allocate more slots than requested. The actual capacity (`storage.slotCapacity`) can exceed `minimumCapacity`. Since the bitmap is created from `heap.slotCapacity` (the actual capacity), the bitmap accurately reflects the storage. **This hypothesis is ELIMINATED** — both bitmap and storage use the same `slotCapacity`.

### Hypothesis 3: Hash table position exceeds slab capacity

The hash table stores slab positions. During `set()`:
```swift
_hashTable.position(forHash: hashValue, equals: { position in
    _keys[position.retag(Bit.self)] == key
})
```

Positions come from previous `_hashTable.insert(__unchecked:, position: slot, ...)` calls, where `slot` came from `_keys.firstVacant()`. These slots are always `< _keys.capacity`.

BUT: After `_grow()`, the hash table is rebuilt with NEW positions from the NEW slab. The old positions are discarded. No cross-slab position leaking. **This hypothesis is ELIMINATED** for the standard path.

### Hypothesis 4: Hash table `shouldGrow` triggers during Dictionary._grow()

During `Dictionary._grow()`, `newHashTable.insert(__unchecked:...)` is called for each element. This internally calls `shouldGrow` which may trigger `Hash.Table.grow()`. Hash.Table.grow() rehashes but preserves position values. No interaction with `Bit.Vector.Bounded`. **This hypothesis is ELIMINATED**.

### Hypothesis 5: Storage.Slab deinit races with _grow() iteration

During `_grow()`, the old buffer's elements are moved out via `_keys.remove(at:)`. Each remove syncs `storage.bitmap = header.bitmap`. When `_keys = newKeys` drops the old buffer, `Storage.Slab.deinit` iterates `_bitmap.ones` — which should be empty since all elements were removed.

Could there be a timing issue where the old Storage.Slab is deallocated prematurely? In single-threaded code with ARC, this shouldn't happen — `_keys` holds the reference throughout the loop. **Needs empirical validation**.

### Hypothesis 6: The crash is NOT in _grow() but in a subsequent set() call

After `_grow()` completes, `set()` falls through to the insert path. The new `_keys` buffer has elements from the growth rehash. The hash table has those elements' positions. But what if:

- A hash collision causes the `equals` closure to be called with a position that was valid in the OLD slab but doesn't exist in the NEW slab?
- This can't happen — the new hash table was built from scratch with new positions.

**This hypothesis is ELIMINATED** by construction.

### Hypothesis 7: `firstVacant()` returns a slot from trailing bits

`Bit.Vector.Zeros.Bounded.first(max:)` iterates all words in `_storage` and looks for zero bits via `~word`. If the last word has bits beyond `_count`/`_capacity`, those trailing zeros could produce a `globalIndex >= _capacity`.

The `guard globalIndex < max` check (where `max == _capacity`) prevents this. **BUT** — what if `max` is wrong? `firstVacant()` passes `header.bitmap.capacity.maximum` which is `_capacity`. This matches `_count`. So returned indices are always `< _count`.

**Needs empirical validation** — perhaps `_capacity` is somehow incorrect.

### Hypothesis 8: The conversion chain in `_grow()` capacity computation

```swift
let newCapacity = Index_Primitives.Index<Key>.Count(
    Cardinal(UInt(max(8, Int(bitPattern: _keys.occupancy) * 2)))
)
```

`Int(bitPattern: _keys.occupancy)` — `_keys.occupancy` is `Bit.Index.Count` (Tagged<Bit, Cardinal>). `Int(bitPattern:)` converts via `Int(bitPattern: UInt)`. For small values (< 1000), this is correct.

`max(8, ...)` → always >= 8. `UInt(...)` → wraps back. `Cardinal(...)` → wraps. `Index<Key>.Count(...)` → wraps. All conversions are safe for small values. **This hypothesis is ELIMINATED**.

### Remaining Hypotheses Requiring Empirical Validation

| # | Hypothesis | Test |
|---|-----------|------|
| H5 | Storage.Slab deinit timing | Print refcount during _grow() |
| H7 | firstVacant trailing bits | Dump bitmap state at crash point |
| H9 | Unknown interaction | Minimal reproduction with state dumps |

## Experiment Plan

Create an experiment in `swift-dictionary-primitives/Experiments/growth-crash/` that:

1. **Traces ManagedBuffer capacity**: For each growth step, log the requested capacity vs actual `slotCapacity`
2. **Traces bitmap state**: Before each insert during growth, log `slot`, `_count`, `_capacity`
3. **Traces firstVacant results**: Log the returned slot index and verify it's within bounds
4. **Narrows the crash**: Binary search for the exact element count that triggers the crash
5. **Tests hash-distribution independence**: Use sequential numeric keys to remove hash randomness

## Outcome

**Status**: IN_PROGRESS — Awaiting experiment results.
