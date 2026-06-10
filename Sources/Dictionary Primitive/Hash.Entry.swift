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

public import Hash_Primitives
public import Hash_Indexed_Primitive

// MARK: - Hash.Entry (the key-projected pair — the dictionary column's element)

extension Hash {
    /// A key–value pair whose hash identity IS its key: `hash(into:)` and `==`
    /// project through `key` and ignore `value`, so the `Hash.Indexed` engine
    /// addresses entries by key while the dense plane carries the values.
    ///
    /// The key is immutable (`let`) — an entry's hash is fixed at initialization,
    /// which is what makes in-place VALUE mutation through the indexed seam lawful
    /// (mutability ruling (a): dictionaries mutate values only; the seam's re-index
    /// guard takes its cheap no-change branch).
    ///
    /// Hosted in the dictionary package, nested in the `Hash` vocabulary beside
    /// `Hash.Key`/`Hash.Indexed`: the entry must exist BEFORE the column type that
    /// stores it, so it cannot nest in the column-generic `Dictionary` template
    /// (a nested type would capture `S`, whose element is this entry — circular).
    @frozen
    public struct Entry<Key: Hash.Key & ~Copyable, Value: ~Copyable>: ~Copyable {
        /// The key of this entry. Immutable — the entry's hash identity.
        public let key: Key

        /// The value of this entry.
        public var value: Value

        /// Creates an entry with the given key and value.
        @inlinable
        public init(key: consuming Key, value: consuming Value) {
            self.key = key
            self.value = value
        }

        /// Consumes the entry, yielding its value (the `removeValue` exit; the key
        /// is dropped — lawful partial consume, the entry carries no deinit).
        @inlinable
        public consuming func take() -> Value {
            value
        }
    }
}

// MARK: - Conditional Conformances

/// `Hash.Entry` is `Copyable` when both halves are.
extension Hash.Entry: Copyable where Key: Copyable, Value: Copyable {}

extension Hash.Entry: Sendable where Key: Sendable & ~Copyable, Value: Sendable & ~Copyable {}

// MARK: - Key-projected hashing

extension Hash.Entry: Hash.`Protocol` where Key: ~Copyable, Value: ~Copyable {
    /// Hashes the KEY only — the entry's hash identity excludes its value.
    @inlinable
    public borrowing func hash(into hasher: inout Hasher) {
        key.hash(into: &hasher)
    }

    /// Compares KEYS only — two entries are "equal" (the same dictionary slot)
    /// exactly when their keys are.
    @inlinable
    public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.key == rhs.key
    }
}
