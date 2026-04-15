# Dictionary Operations Audit

<!--
---
version: 1.0.0
last_updated: 2026-02-16
status: RECOMMENDATION
tier: 1
---
-->

## Context

Proactive audit of swift-dictionary-primitives per [RES-012] Discovery.
**Scope**: Package-specific (swift-dictionary-primitives).

This document inventories every public operation on every variant of `Dictionary.Ordered` and maps them against the canonical Dictionary/Map ADT operations from computer science literature. The goal is to identify present operations, missing operations that should be added at the primitives layer, and operations intentionally deferred to higher layers.

**Note**: This package implements `Dictionary.Ordered` (insertion-order-preserving dictionary backed by hash-based key lookup), not a sorted/tree-based map. Key lookup is O(1) average (hash-based), not O(log n). The "Ordered" in the name refers to insertion-order preservation, similar to Python 3.7+ `dict` and Rust's `indexmap`.

## Question

Does swift-dictionary-primitives provide the canonical operations expected of the Dictionary/Map ADT?

---

## Canonical Operations (ADT Reference)

### Hash Map (Unordered / Insertion-Ordered)

| Operation | Expected Complexity | Description |
|-----------|-------------------|-------------|
| put(k, v) / insert(k, v) | O(1) avg | Insert or update key-value pair |
| get(k) | O(1) avg | Retrieve value by key |
| remove(k) | O(1) avg | Remove by key |
| containsKey(k) | O(1) avg | Check key existence |
| iterate keys | O(n) | Visit all keys |
| iterate values | O(n) | Visit all values |
| iterate items | O(n) | Visit all key-value pairs |
| count/size | O(1) | Number of entries |
| isEmpty | O(1) | Empty check |
| merge | O(m) | Merge another dictionary |
| subscript-with-default | O(1) avg | Get value or return default |
| mapValues | O(n) | Transform all values preserving keys |
| filter | O(n) | Filter entries by predicate |
| updateValue (returning old) | O(1) avg | Upsert returning previous value |

### Ordered/Tree Map (Not Applicable -- Included for Completeness)

| Operation | Expected Complexity | Description |
|-----------|-------------------|-------------|
| put/get/remove | O(log n) | Ordered operations |
| range queries | O(log n + k) | Query range of keys |
| min/max key | O(log n) or O(1) | Extrema |

These tree-map operations are **not applicable** to `Dictionary.Ordered`, which is insertion-order-preserving, not sorted-order. Min/max by insertion position is available via index 0 and `count - 1`.

---

## Current Operations Inventory

### Variant: `Dictionary.Ordered`

Dynamic, heap-allocated ordered dictionary. Copyable when `Value: Copyable`.

#### Initialization

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `init()` | `Value: ~Copyable` | `Dictionary.Ordered.swift` | 175 |
| `init(reservingCapacity: Index<Key>.Count) throws(Error)` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 23 |
| `init(_ pairs: some Sequence<(Key, Value)>) throws(Error)` | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` | 22 |
| `init(_ pairs: some Sequence<(Key, Value)>, uniquingKeysWith: (Value, Value) throws -> Value) rethrows` | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` | 40 |

#### Properties

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `var count: Index<Key>.Count` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 35 |
| `var isEmpty: Bool` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 41 |
| `var capacity: Index<Key>.Count` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 47 |
| `var description: String` | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` | 195 |

#### Core Mutation (~Copyable base)

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `mutating func set(_ key: Key, _ value: consuming Value)` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 94 |
| `@discardableResult mutating func remove(_ key: Key) -> Value?` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 110 |
| `mutating func clear(keepingCapacity: Bool = false)` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 120 |
| `mutating func reserve(_ minimumCapacity: Index<Key>.Count)` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 78 |

#### Core Mutation (CoW-aware, shadows base when Copyable)

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `mutating func set(_ key: Key, _ value: Value)` | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` | 73 |
| `@discardableResult mutating func remove(_ key: Key) -> Value?` | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` | 93 |
| `mutating func clear(keepingCapacity: Bool = false)` | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` | 107 |
| `mutating func removeAll()` | `Value: Copyable` (Sequence.Clearable) | `Dictionary.Ordered Copyable.swift` (Ordered Primitives) | 144 |

#### Lookup / Access

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `func contains(_ key: Key) -> Bool` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 60 |
| `func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R?` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 139 |
| `func withValue<R>(at index: Index<Key>, _ body: (borrowing Value) -> R) -> R` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 152 |
| `func withValue<R>(at index: Index<Key>, _ body: (borrowing Value) throws(Error) -> R) throws(Error) -> R` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 165 |
| `subscript(key: Key) -> Value?` (get/set) | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` | 125 |
| `subscript(at index: Index<Key>) -> (key: Key, value: Value)` | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` | 144 |
| `subscript(index index: Int) -> (key: Key, value: Value)` | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` | 151 |
| `func key(at index: Dictionary<Key, Value>.Index) -> Key` | `Value: Copyable` | `Dictionary.Index.swift` | 46 |
| `func value(at index: Dictionary<Key, Value>.Index) -> Value` | `Value: Copyable` | `Dictionary.Index.swift` | 56 |
| `func entry(at index: Dictionary<Key, Value>.Index) -> (key: Key, value: Value)?` | `Value: Copyable` | `Dictionary.Index.swift` | 66 |
| `func element(at index: Index<Key>) throws(Error) -> (key: Key, value: Value)` | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` (Ordered Primitives) | 88 |

#### Iteration

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `func forEach(_ body: (Key, borrowing Value) -> Void)` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 183 |
| `mutating func drain(_ body: (consuming Entry) -> Void)` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 200 |
| `var drain: Drain` (property accessor) | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` (Ordered Primitives) | 84 |
| `borrowing func makeIterator() -> Iterator` | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` (Ordered Primitives) | 62 |

#### Protocol Conformances

| Protocol | Constraint | Module |
|----------|-----------|--------|
| `Copyable` | `Value: Copyable` | Core |
| `@unchecked Sendable` | `Key: Sendable, Value: Sendable` | Core |
| `Equatable` | `Value: Equatable` | Core |
| `Hashable` | `Key: Hashable, Value: Hashable` | Core |
| `CustomStringConvertible` | `Value: Copyable` | Core |
| `Sequence.Protocol` | `Value: Copyable` | Ordered Primitives |
| `Swift.Sequence` | `Value: Copyable` | Ordered Primitives |
| `Swift.Collection` | `Value: Copyable` | Ordered Primitives |
| `Swift.BidirectionalCollection` | `Value: Copyable` | Ordered Primitives |
| `Swift.RandomAccessCollection` | `Value: Copyable` | Ordered Primitives |
| `Sequence.Clearable` | `Value: Copyable` | Ordered Primitives |

---

### Variant: `Dictionary.Ordered.Bounded`

Fixed-capacity ordered dictionary. Throws on overflow.

#### Initialization

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `init(capacity: Index<Key>.Count) throws(Error)` | `Value: ~Copyable` | `Dictionary.Ordered.swift` | 221 |

#### Properties

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `var count: Index<Key>.Count` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 219 |
| `var isEmpty: Bool` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 223 |
| `var isFull: Bool` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 227 |
| `let capacity: Index<Key>.Count` | `Value: ~Copyable` | `Dictionary.Ordered.swift` | 214 |

#### Core Mutation

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `mutating func set(_ key: Key, _ value: consuming Value) throws(Error)` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 243 |
| `@discardableResult mutating func remove(_ key: Key) -> Value?` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 261 |
| `mutating func clear()` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 269 |
| `mutating func removeAll()` | `Value: Copyable` (Sequence.Clearable) | Bounded Primitives | 127 |

#### Lookup / Access

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `func contains(_ key: Key) -> Bool` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 231 |
| `func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R?` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 276 |
| `func withValue<R>(at index: Index<Key>, _ body: (borrowing Value) -> R) -> R` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 283 |
| `func withValue<R>(at index: Index<Key>, _ body: (borrowing Value) throws(Error) -> R) throws(Error) -> R` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 290 |
| `subscript(key: Key) -> Value?` (get only) | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` | 216 |
| `subscript(index index: Int) -> (key: Key, value: Value)` | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` | 225 |

#### Protocol Conformances

| Protocol | Constraint | Module |
|----------|-----------|--------|
| `Copyable` | `Value: Copyable` | Core |
| `@unchecked Sendable` | `Key: Sendable, Value: Sendable` | Core |
| `Equatable` | `Value: Equatable` | Core |
| `Hashable` | `Key: Hashable, Value: Hashable` | Core |
| `Sequence.Protocol` | `Value: Copyable` | Bounded Primitives |
| `Swift.Sequence` | `Value: Copyable` | Bounded Primitives |
| `Swift.Collection` | `Value: Copyable` | Bounded Primitives |
| `Swift.BidirectionalCollection` | `Value: Copyable` | Bounded Primitives |
| `Swift.RandomAccessCollection` | `Value: Copyable` | Bounded Primitives |
| `Sequence.Clearable` | `Value: Copyable` | Bounded Primitives |

---

### Variant: `Dictionary.Ordered.Static<let capacity: Int>`

Compile-time-capacity, inline-storage ordered dictionary. Unconditionally `~Copyable`.

#### Initialization

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `init()` | `Value: ~Copyable` | `Dictionary.Ordered.swift` | 259 |

#### Properties

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `var count: Index<Key>.Count` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 306 |
| `var isEmpty: Bool` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 310 |
| `var isFull: Bool` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 314 |

#### Core Mutation

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `mutating func set(_ key: Key, _ value: consuming Value) throws(Error)` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 344 |
| `@discardableResult mutating func remove(_ key: Key) -> Value?` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 368 |
| `mutating func clear()` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 389 |
| `mutating func removeAll()` | `Value: Copyable` (Sequence.Clearable) | Static Copyable (Ordered Primitives) | 106 |

#### Lookup / Access

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `func contains(_ key: Key) -> Bool` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 319 |
| `func index(of key: Key) -> Index<Key>.Bounded<capacity>?` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 329 |
| `func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R?` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 398 |
| `func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 408 |
| `func withValue<R>(at index: Index<Key>, _ body: (borrowing Value) -> R) -> R` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 422 |
| `func withValue<R>(at index: Index<Key>, _ body: (borrowing Value) throws(Error) -> R) throws(Error) -> R` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 429 |
| `subscript(key: Key) -> Value?` (get only) | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` | 267 |
| `subscript(index index: Int) -> (key: Key, value: Value)` | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` | 279 |

#### Protocol Conformances

| Protocol | Constraint | Module |
|----------|-----------|--------|
| `@unchecked Sendable` | `Key: Sendable, Value: Sendable` | Core |
| `Sequence.Protocol` | `Value: Copyable` | Ordered Primitives (Static Copyable) |
| `Sequence.Clearable` | `Value: Copyable` | Ordered Primitives (Static Copyable) |

**Note**: Static is unconditionally `~Copyable`, so it cannot conform to `Equatable`, `Hashable`, `Swift.Sequence`, or `Swift.Collection` (all require `Copyable` self).

---

### Variant: `Dictionary.Ordered.Small<let inlineCapacity: Int>`

Small-buffer-optimization ordered dictionary. Unconditionally `~Copyable`.

#### Initialization

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `init()` | `Value: ~Copyable` | `Dictionary.Ordered.swift` | 317 |

#### Properties

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `var count: Index<Key>.Count` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 445 |
| `var isEmpty: Bool` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 449 |
| `var isSpilled: Bool` | `Value: ~Copyable` | `Dictionary.Ordered.swift` | 330 |

#### Core Mutation

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `mutating func set(_ key: Key, _ value: consuming Value)` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 478 |
| `@discardableResult mutating func remove(_ key: Key) -> Value?` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 513 |
| `mutating func clear()` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 534 |
| `mutating func removeAll()` | `Value: Copyable` (Sequence.Clearable) | Small Copyable (Ordered Primitives) | 110 |

#### Lookup / Access

| Signature | Constraint | File | Line |
|-----------|-----------|------|------|
| `func contains(_ key: Key) -> Bool` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 453 |
| `func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R?` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 546 |
| `func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 557 |
| `func withValue<R>(at index: Index<Key>, _ body: (borrowing Value) -> R) -> R` | `Value: ~Copyable` | `Dictionary.Ordered ~Copyable.swift` | 571 |
| `subscript(key: Key) -> Value?` (get only) | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` | 291 |
| `subscript(index index: Int) -> (key: Key, value: Value)` | `Value: Copyable` | `Dictionary.Ordered Copyable.swift` | 304 |

#### Protocol Conformances

| Protocol | Constraint | Module |
|----------|-----------|--------|
| `@unchecked Sendable` | `Key: Sendable, Value: Sendable` | Core |
| `Sequence.Protocol` | `Value: Copyable` | Ordered Primitives (Small Copyable) |
| `Sequence.Clearable` | `Value: Copyable` | Ordered Primitives (Small Copyable) |

**Note**: Small is unconditionally `~Copyable`, same limitations as Static.

---

### Keys View (`Dictionary.Ordered.Keys`)

Available on `Dictionary.Ordered` only (via `dict.keys` property). Defined in Core, accessible when `Value: ~Copyable`.

| Signature | File | Line |
|-----------|------|------|
| `var keys: Keys` (property accessor) | `Dictionary.Ordered.Keys.swift` | 25 |
| `func index(_ key: Key) -> Index<Key>?` | `Dictionary.Ordered.Keys.swift` | 56 |
| `var all: Set<Key>.Ordered` | `Dictionary.Ordered.Keys.swift` | 62 |
| `var count: Index<Key>.Count` | `Dictionary.Ordered.Keys.swift` | 68 |
| `var isEmpty: Bool` | `Dictionary.Ordered.Keys.swift` | 74 |
| `subscript(_ index: Index<Key>) -> Key` | `Dictionary.Ordered.Keys.swift` | 83 |
| `subscript(raw index: Int) -> Key` | `Dictionary.Ordered.Keys.swift` | 89 |
| `func contains(_ key: Key) -> Bool` | `Dictionary.Ordered.Keys.swift` | 96 |
| `func makeIterator() -> Iterator` (Swift.Sequence) | `Dictionary.Ordered.Keys.swift` | 120 |

---

### Values View (`Dictionary.Ordered.Values`)

Available on `Dictionary.Ordered` only (via `dict.values` property). Requires `Value: Copyable`.

| Signature | File | Line |
|-----------|------|------|
| `var values: Values` (property accessor with `_modify`) | `Dictionary.Ordered.Values.swift` | 33 |
| `mutating func set(_ key: Key, _ value: Value)` | `Dictionary.Ordered.Values.swift` | 74 |
| `@discardableResult mutating func remove(_ key: Key) -> Value?` | `Dictionary.Ordered.Values.swift` | 85 |
| `@discardableResult mutating func modify(_ key: Key, _ transform: (inout Value) -> Void) -> Value?` | `Dictionary.Ordered.Values.swift` | 97 |
| `var count: Index<Key>.Count` | `Dictionary.Ordered.Values.swift` | 108 |
| `var isEmpty: Bool` | `Dictionary.Ordered.Values.swift` | 114 |
| `subscript(_ index: Index<Key>) -> Value` (get/set) | `Dictionary.Ordered.Values.swift` | 123 |
| `subscript(raw index: Int) -> Value` (get/set) | `Dictionary.Ordered.Values.swift` | 140 |
| `subscript(key key: Key) -> Value?` (get/set) | `Dictionary.Ordered.Values.swift` | 159 |
| `func makeIterator() -> Iterator` (Swift.Sequence) | `Dictionary.Ordered.Values.swift` | 201 |

---

### Merge Operations (`Dictionary.Ordered.Merge` / `Dictionary.Ordered.Merge.Keep`)

Available on `Dictionary.Ordered` only. Requires `Value: Copyable`.

| Signature | File | Line |
|-----------|------|------|
| `var merge: Merge` (property accessor with `_modify`) | `Dictionary.Ordered.Merge.swift` | 36 |
| `var keep: Keep` (on Merge, property accessor with `_modify`) | `Dictionary.Ordered.Merge.swift` | 68 |
| `mutating func first(_ pairs: some Sequence<(Key, Value)>)` | `Dictionary.Ordered.Merge.Keep.swift` | 71 |
| `mutating func last(_ pairs: some Sequence<(Key, Value)>)` | `Dictionary.Ordered.Merge.Keep.swift` | 103 |

---

### Additional Types

| Type | Description | File | Line |
|------|-------------|------|------|
| `Dictionary.Ordered.Entry` | Key-value pair struct supporting `~Copyable` values | `Dictionary.Ordered.swift` | 146 |
| `Dictionary.Ordered.Drain` | Non-escapable drain type for `~Copyable` consuming iteration | `Dictionary.Ordered ~Copyable.swift` (Ordered Primitives) | 31 |
| `Dictionary.Index` (typealias for `Index_Primitives.Index<Key>`) | Type-safe index | `Dictionary.Index.swift` | 35 |
| `Dictionary.Ordered.ValueStorage` (typealias for `Buffer<Value>.Linear`) | Value storage type | `Dictionary.Ordered.swift` | 167 |
| `Dictionary.Ordered.Error` (typealias) | Typed error | `Dictionary.Ordered.Error.swift` | 191 |
| `Dictionary.Ordered.Bounded.Error` (typealias) | Typed error | `Dictionary.Ordered ~Copyable.swift` | 215 |
| `Dictionary.Ordered.Static.Error` (typealias) | Typed error | `Dictionary.Ordered ~Copyable.swift` | 302 |

---

## Gap Analysis

### Present and Correctly Mapped

| ADT Operation | Implementation | Variants | Notes |
|---------------|---------------|----------|-------|
| **put(k, v)** | `set(_ key:, _ value:)` | All four | O(1) avg. CoW-aware on Ordered when Copyable. Throws on Bounded/Static when full. |
| **get(k)** | `subscript(key:) -> Value?` | All four (Copyable) | O(1) avg. Read-only on Bounded/Static/Small. |
| **get(k) (~Copyable)** | `withValue(forKey:_:)` | All four | Borrow-based access for ~Copyable values. |
| **remove(k)** | `remove(_ key:) -> Value?` | All four | Returns removed value. O(n) due to index shifting. |
| **containsKey(k)** | `contains(_ key:)` | All four | O(1) avg. |
| **iterate items** | `makeIterator()` / `for-in` | All four (Copyable) | `(key: Key, value: Value)` tuples. Static/Small use snapshot copy. |
| **iterate items (~Copyable)** | `forEach(_ body:)` | Ordered only | Borrow-based, O(n). |
| **drain items (~Copyable)** | `drain { entry in }` | Ordered only | Consuming iteration via Entry struct. |
| **iterate keys** | `dict.keys` + Sequence conformance | Ordered only | Keys view with full Sequence/iterator support. |
| **iterate values** | `dict.values` + Sequence conformance | Ordered only | Values view with full Sequence/iterator support. |
| **count** | `var count` | All four | O(1). |
| **isEmpty** | `var isEmpty` | All four | O(1). |
| **merge** | `dict.merge.keep.first(_:)` / `.last(_:)` | Ordered only | O(m) where m is length of incoming pairs. |
| **clear** | `clear()` / `clear(keepingCapacity:)` | All four | Ordered has `keepingCapacity` parameter; others keep capacity. |
| **capacity** | `var capacity` | Ordered, Bounded | Bounded also has `let capacity`. |
| **reserve** | `reserve(_:)` | Ordered only | Reserves for both keys and values. |
| **index-based access** | `subscript(at:)`, `subscript(index:)`, `key(at:)`, `value(at:)`, `entry(at:)` | Ordered (Copyable) | O(1) random access. |
| **index-based access (~Copyable)** | `withValue(at:_:)` | All four | Borrow-based with typed error variant. |
| **construct from pairs** | `init(_ pairs:) throws(Error)` | Ordered only (Copyable) | Detects duplicates with typed error. |
| **construct with conflict resolution** | `init(_:uniquingKeysWith:)` | Ordered only (Copyable) | Custom merge on construction. |
| **isFull** | `var isFull` | Bounded, Static | Capacity-bounded diagnostic. |
| **isSpilled** | `var isSpilled` | Small | Small-buffer diagnostic. |
| **equality** | `Equatable` | Ordered, Bounded | Order-sensitive equality. |
| **hashing** | `Hashable` | Ordered, Bounded | Order-sensitive hashing. |

### Missing -- Should Add (Primitives Layer)

These are canonical Dictionary ADT operations that belong at the primitives layer.

| Operation | Priority | Rationale |
|-----------|----------|-----------|
| **`subscript(key:default:) -> Value`** | **High** | Core dictionary ergonomic present in Swift stdlib, Python, and every major language. `dict[key, default: 0] += 1` is the canonical counting pattern. Should be on Ordered (Copyable). |
| **`updateValue(_:forKey:) -> Value?`** | **Medium** | Standard upsert returning the old value. Present in Swift stdlib. Useful for detecting whether an insert or update occurred. |
| **`forEach` on Bounded/Static/Small** | **Medium** | Currently `forEach(_ body: (Key, borrowing Value) -> Void)` is only on Ordered. The ~Copyable iteration pattern should be available on all variants for consistency. |
| **`drain` on Bounded/Static/Small** | **Medium** | Currently `drain` (consuming iteration) is only on Ordered. Bounded/Static/Small with ~Copyable values have no consuming iteration path. |
| **`keys` / `values` projections on Bounded/Static/Small** | **Medium** | Key and value views are only on Ordered. The other variants lack structured key/value access. At minimum, a `keys` view would provide `index(_:)` for all variants. |
| **`subscript(key:)` set on Bounded/Static/Small** | **Low** | Currently get-only on these variants. A setter that delegates to `set`/`remove` would improve ergonomics. For Bounded/Static this would need to handle the overflow error (perhaps as a precondition). |
| **`merge` on Bounded** | **Low** | Merge with keep-policy is only on Ordered. Bounded could support merge with overflow checking. |
| **`Equatable`/`Hashable` on Static/Small** | **Low** | Unconditionally `~Copyable` types cannot conform to these protocols. Could provide `isEqual(to:)` method as workaround. |
| **`withValue(at:_:) throws` on Small** | **Low** | Small has `withValue(at:_:)` with precondition but lacks the typed-error throwing variant that Ordered, Bounded, and Static all provide. |
| **`capacity` on Static/Small** | **Low** | Static's capacity is the generic parameter. Small has `inlineCapacity` but no runtime total capacity property. Could be useful for diagnostics. |
| **`reserve` on Bounded/Small** | **Low** | Bounded has fixed capacity (no reserve needed). Small could benefit from pre-spill reservation. |

### Missing -- Intentionally Absent (Higher Layer)

These operations are part of the canonical Dictionary ADT but properly belong at the foundations or components layer, not primitives.

| Operation | Layer | Rationale |
|-----------|-------|-----------|
| **`mapValues(_:)`** | Foundations | Functor operation (structure-preserving value transformation). Requires constructing a new dictionary, which is a composed operation. The discipline-boundary analysis lists this as "solely dictionary discipline" but with a construction cost that suggests foundations-layer complexity. |
| **`compactMapValues(_:)`** | Foundations | Transform-and-compact values. Composed from mapValues + filter. |
| **`filter(_:)` returning dictionary** | Foundations | Predicate-based filtering returning a new dictionary. Composed operation. |
| **`intersection`, `difference`, `symmetricDifference`** | Foundations | Set-theoretic operations on dictionaries. Algebraically correct but composed. |
| **`ExpressibleByDictionaryLiteral`** | Foundations | Syntax sugar requiring `Dictionary` to shadow Swift.Dictionary literal syntax. Ergonomic but has namespace implications. |
| **`Codable`** | Foundations | Serialization concern. Would require Foundation or a custom encoding layer. |
| **`subscript(key:default:)` with modify** | Foundations | The read-only default subscript is primitives; the `_modify` yield enabling `dict[key, default: 0] += 1` involves more complex COW coordination. |
| **`reduce` / `allSatisfy` / `contains(where:)`** | stdlib | Available for free via `Swift.Sequence` conformance on Ordered/Bounded. Not needed as dedicated methods. |
| **Sorted-order operations (min/max key, range queries)** | N/A | `Dictionary.Ordered` is insertion-ordered, not sorted. A `Dictionary.Sorted` type (tree-based) would provide these. |

---

## Cross-Variant Parity Matrix

Summary of which operations are present on which variant.

| Operation | Ordered | Bounded | Static | Small |
|-----------|:-------:|:-------:|:------:|:-----:|
| `init()` | Y | N (needs capacity) | Y | Y |
| `init(capacity:)` | N (use reserve) | Y | N (generic param) | N (generic param) |
| `init(pairs:)` | Y | -- | -- | -- |
| `init(pairs:uniquingKeysWith:)` | Y | -- | -- | -- |
| `set` | Y | Y (throws) | Y (throws) | Y |
| `remove` | Y | Y | Y | Y |
| `clear` | Y | Y | Y | Y |
| `contains` | Y | Y | Y | Y |
| `count` | Y | Y | Y | Y |
| `isEmpty` | Y | Y | Y | Y |
| `capacity` | Y | Y | -- | -- |
| `isFull` | -- | Y | Y | -- |
| `reserve` | Y | -- | -- | -- |
| `subscript(key:)` get | Y | Y | Y | Y |
| `subscript(key:)` set | Y | -- | -- | -- |
| `subscript(at:)` typed | Y | -- | -- | -- |
| `subscript(index:)` raw | Y | Y | Y | Y |
| `key(at:)` | Y | -- | -- | -- |
| `value(at:)` | Y | -- | -- | -- |
| `entry(at:)` | Y | -- | -- | -- |
| `element(at:) throws` | Y | -- | -- | -- |
| `withValue(forKey:)` | Y | Y | Y | Y |
| `withValue(at:)` | Y | Y | Y | Y |
| `withValue(at:) throws` | Y | Y | Y | -- |
| `withValue(atIndex:)` raw | -- | -- | Y | Y |
| `index(of:)` | -- | -- | Y | -- |
| `forEach` ~Copyable | Y | -- | -- | -- |
| `drain` ~Copyable | Y | -- | -- | -- |
| `makeIterator` | Y | Y | Y | Y |
| `keys` view | Y | -- | -- | -- |
| `values` view | Y | -- | -- | -- |
| `merge.keep.first/last` | Y | -- | -- | -- |
| `Equatable` | Y | Y | -- | -- |
| `Hashable` | Y | Y | -- | -- |
| `Swift.Sequence` | Y | Y | -- | -- |
| `Swift.Collection` | Y | Y | -- | -- |
| `RandomAccessCollection` | Y | Y | -- | -- |
| `Sequence.Protocol` | Y | Y | Y | Y |
| `Sequence.Clearable` | Y | Y | Y | Y |
| `Sendable` | Y | Y | Y | Y |
| `CustomStringConvertible` | Y | -- | -- | -- |

**Key observation**: `Dictionary.Ordered` is significantly more feature-complete than the other three variants. Bounded has moderate coverage. Static and Small have minimal API surfaces beyond core CRUD.

---

## Outcome

**Status**: RECOMMENDATION

### Summary

`swift-dictionary-primitives` covers the core Dictionary ADT operations well for the primary `Dictionary.Ordered` variant. The key-value association contract (set/get/remove/contains), iteration (multiple patterns including ~Copyable support), projections (Keys/Values views), and merge operations are all present. The four-variant family (Ordered, Bounded, Static, Small) correctly covers different allocation strategies.

### Primary Gaps

1. **`subscript(key:default:)`** is missing entirely. This is the single most impactful gap -- it blocks the `dict[key, default: 0] += 1` counting pattern that is fundamental dictionary usage.

2. **Cross-variant parity** is the second concern. `forEach`, `drain`, `keys`/`values` views, and merge are only on `Dictionary.Ordered`. The other three variants lack these operations, creating an inconsistent API surface.

3. **`updateValue(_:forKey:) -> Value?`** is a standard dictionary operation (present in Swift stdlib) that provides information about whether an insert or update occurred.

### Recommended Priority Order

1. Add `subscript(key:default:)` on `Dictionary.Ordered` (Copyable)
2. Add `forEach` on Bounded, Static, and Small (~Copyable)
3. Add `drain` on Bounded, Static, and Small (~Copyable)
4. Add `keys` view on Bounded, Static, and Small
5. Add `updateValue(_:forKey:) -> Value?` on `Dictionary.Ordered`
6. Add `values` view on Bounded (Copyable)
7. Add `merge` on Bounded (Copyable)
8. Add `withValue(at:) throws` on Small

---

## References

- [dictionary-discipline-boundary-analysis.md](dictionary-discipline-boundary-analysis.md) -- Prior audit of layering discipline
- [value-storage-buffer-layering.md](value-storage-buffer-layering.md) -- Buffer migration research
- Liskov & Guttag, "Abstraction and Specification in Program Development" -- ADT axioms
- [Swift stdlib Dictionary](https://developer.apple.com/documentation/swift/dictionary) -- Standard library reference
- [Python dict](https://docs.python.org/3/library/stdtypes.html#mapping-types-dict) -- Insertion-ordered reference
- [Rust HashMap](https://doc.rust-lang.org/std/collections/struct.HashMap.html) -- Systems-level reference
- [Rust IndexMap](https://docs.rs/indexmap/latest/indexmap/) -- Insertion-ordered map reference
