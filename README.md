# Dictionary Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)
[![CI](https://github.com/swift-primitives/swift-dictionary-primitives/actions/workflows/ci.yml/badge.svg)](https://github.com/swift-primitives/swift-dictionary-primitives/actions/workflows/ci.yml)

`Dictionary<S>` — an insertion-ordered hash dictionary generic over its storage **column**. Entries (`Hash.Entry<Key, Value>`) live densely in insertion order behind a key-projected bucket position-index engine, so lookup and insertion are O(1) average-case and `forEach` follows insertion order. Keys are immutable; a value mutates in place behind its hash-stable key, never triggering a rehash. As with the rest of the family, copyability flows from the column: a move-only column is zero-cost, and a `Shared` column gives copy-on-write value semantics.

The value surface borrows rather than returns by copy (`withValue` / `withMutableValue`), so keys and values may themselves be noncopyable.

---

## Key Features

- **Insertion-ordered hash dictionary** — O(1) average-case lookup and insert; `forEach` visits entries in insertion order.
- **Column-generic storage** — `Dictionary<S>` composes the ordered-hashed entry column; the backing is a type parameter, not a separate type per policy.
- **In-place value mutation** — `withMutableValue(forKey:)` edits a value behind a stable key with no rehash; keys are immutable.
- **Copyability from the column** — move-only by default (zero-cost), opt-in copy-on-write via a `Shared` column; `~Copyable` keys and values on the move-only column.

---

## Quick Start

```swift
import Dictionary_Primitives
import Column_Primitives
import Hash_Indexed_Primitive
import Hash_Primitives_Standard_Library_Integration

// Move-only by default, over the ordered-hashed entry column:
var statusText = Dictionary<Hash.Indexed<Column.Heap<Hash.Entry<Int, String>>>>()
statusText.insert(key: 200, value: "OK")
statusText.insert(key: 404, value: "Not Found")
let ok = statusText.withValue(forKey: 200) { $0 }        // Optional("OK") — borrows in place
statusText.withMutableValue(forKey: 404) { $0 = "Missing" }
statusText.forEach { key, value in print(key, value) }   // insertion order
```

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-dictionary-primitives.git", branch: "main")
]
```

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "Dictionary Primitives", package: "swift-dictionary-primitives")
    ]
)
```

The package is pre-1.0 — depend on `branch: "main"` until `0.1.0` is tagged. Requires Swift 6.3 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the corresponding Linux / Windows toolchain).

---

## Architecture

| Product | Contents | When to import |
|---------|----------|----------------|
| `Dictionary Primitives` | Umbrella — `Dictionary<S>`, `Hash.Entry`, the column constructors, and the conformances | Most consumers |
| `Dictionary Primitive` | The `Dictionary<S>` value type and `Hash.Entry`, without the conformances | Move-only / minimal-surface use |

---

## Platform Support

| Platform         | CI  | Status       |
|------------------|-----|--------------|
| macOS 26         | Yes | Full support |
| Linux            | Yes | Full support |
| Windows          | Yes | Full support |
| iOS/tvOS/watchOS | —   | Supported    |
| Swift Embedded   | —   | Pending (nightly-toolchain follow-up) |

---

## Related Packages

- [`swift-dictionary-ordered-primitives`](https://github.com/swift-primitives/swift-dictionary-ordered-primitives) — the order-preserving `Dictionary.Ordered` discipline with positional access.
- [`swift-hash-table-primitives`](https://github.com/swift-primitives/swift-hash-table-primitives) — the `Hash.Indexed` position-index engine the entry column is built on.
- [`swift-column-primitives`](https://github.com/swift-primitives/swift-column-primitives) — the column vocabulary (`Hash.Indexed`, `Column.Heap`, …) the dictionary composes.

---

## Community

<!-- BEGIN: discussion -->
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
