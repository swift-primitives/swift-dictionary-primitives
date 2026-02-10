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

public import Set_Primitives
public import Buffer_Linear_Primitives
public import Index_Primitives

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
// - Copy-on-Write only applies when Value: Copyable
// - Base methods use `consuming Value`; CoW methods use `Value`
//
// ===----------------------------------------------------------------------===//

/// Namespace for ordered dictionary types.
///
/// This shadows `Swift.Dictionary`. Use `Swift.Dictionary` or module-qualified
/// `Dictionary_Primitives_Core.Dictionary` to disambiguate when both are in scope.
public enum Dictionary<Key: Hash.`Protocol`, Value: ~Copyable>: ~Copyable {
    /// An ordered dictionary that preserves insertion order, supporting move-only values.
    ///
    /// `Ordered` combines the key-value semantics of a dictionary with the ordering
    /// guarantees of an array. Key-value pairs are stored in insertion order and
    /// can be accessed by index.
    ///
    /// ## API
    ///
    /// Key operations use nested accessors:
    ///
    /// ```swift
    /// var dict = Dictionary<String, Int>.Ordered()
    ///
    /// // Value operations
    /// dict.values.set("apple", 1)
    /// dict.values.set("banana", 2)
    /// let removed = dict.values.remove("apple")
    ///
    /// // Key operations
    /// if let idx = dict.keys.index("banana") { ... }
    ///
    /// // Subscript access
    /// dict["cherry"] = 3
    /// let value = dict["cherry"]
    /// ```
    ///
    /// ## Ordering Semantics
    ///
    /// - Setting a new key adds to the end
    /// - Updating existing key does NOT move position
    /// - Removal shifts subsequent pairs (indices change)
    /// - Re-insertion after removal goes to end
    ///
    /// ## Move-Only Support
    ///
    /// Both the dictionary and its values can be `~Copyable`:
    ///
    /// ```swift
    /// struct FileHandle: ~Copyable { ... }
    /// var dict = Dictionary<String, FileHandle>.Ordered()
    /// dict.set("primary", FileHandle())
    /// ```
    ///
    /// Note: Keys must always be `Hashable` (which implies `Copyable`).
    ///
    /// ## Copy-on-Write
    ///
    /// When `Value` is `Copyable`, `Dictionary.Ordered` uses copy-on-write semantics:
    /// copies share storage until mutation.
    ///
    /// ## Thread Safety
    ///
    /// Not thread-safe for concurrent mutation. Synchronize externally.
    ///
    /// ## Complexity
    ///
    /// - Set/get/remove by key: O(1) average
    /// - Index lookup: O(1) average
    /// - Random access by index: O(1)
    ///
    /// ## Variants
    ///
    /// - ``Dictionary/Ordered``: Dynamically-growing storage (this type)
    /// - ``Dictionary/Ordered/Bounded``: Fixed-capacity, throws on overflow
    /// - ``Dictionary/Ordered/Inline``: Zero-allocation inline storage with compile-time capacity
    /// - ``Dictionary/Ordered/Small``: Inline storage with automatic spill to heap
    @safe
    public struct Ordered: ~Copyable {

        // MARK: - Entry (nested to inherit Value's ~Copyable context)

        /// A key-value pair entry from the dictionary.
        ///
        /// This struct supports ~Copyable values, unlike tuples which require Copyable elements.
        /// Used as the `Element` type for `Sequence.Drain.Protocol` conformance.
        ///
        /// Entry is conditionally Copyable when Value is Copyable, enabling Swift.Sequence
        /// conformance while preserving ~Copyable value support.
        public struct Entry: ~Copyable {
            /// The key of this entry.
            public let key: Key

            /// The value of this entry.
            public var value: Value

            /// Creates an entry with the given key and value.
            @inlinable
            public init(key: Key, value: consuming Value) {
                self.key = key
                self.value = value
            }
        }

        // MARK: - Value Storage
        //
        // Uses Buffer<Value>.Linear from Buffer Linear Primitives for value storage.
        // Buffer wraps Storage internally and provides the canonical data structure API.

        /// Typealias for value storage type.
        public typealias ValueStorage = Buffer<Value>.Linear

        public var _keys: Set<Key>.Ordered

        public var _values: Buffer<Value>.Linear

        /// Creates an empty ordered dictionary.
        @inlinable
        public init() {
            self._keys = Set<Key>.Ordered()
            self._values = Buffer<Value>.Linear(minimumCapacity: .zero)
        }

        // Note: No deinit needed - Buffer.Linear handles cleanup

        // MARK: - Bounded Variant

        /// A fixed-capacity ordered dictionary that throws on overflow.
        ///
        /// `Dictionary.Ordered.Bounded` allocates storage upfront and throws when
        /// inserting a key-value pair would exceed the capacity.
        ///
        /// ## Example
        ///
        /// ```swift
        /// var dict = try Dictionary<String, Int>.Ordered.Bounded(capacity: 10)
        /// try dict.set("apple", 1)
        /// try dict.set("banana", 2)
        /// dict["apple"]  // Optional(1)
        /// ```
        ///
        /// ## Move-Only Support
        ///
        /// Both the dictionary and its values can be `~Copyable`:
        ///
        /// ```swift
        /// struct FileHandle: ~Copyable { ... }
        /// var dict = try Dictionary<String, FileHandle>.Ordered.Bounded(capacity: 5)
        /// try dict.set("primary", FileHandle())
        /// ```
        @safe
        public struct Bounded: ~Copyable {
            public var _keys: Set<Key>.Ordered

            public var _values: Buffer<Value>.Linear.Bounded

            /// The maximum number of key-value pairs the dictionary can hold.
            public let capacity: Index_Primitives.Index<Key>.Count

            /// Creates a bounded ordered dictionary with the specified capacity.
            ///
            /// - Parameter capacity: Maximum number of pairs. Must be non-negative.
            /// - Throws: ``Dictionary/Ordered/Bounded/Error/invalidCapacity`` if capacity is negative.
            @inlinable
            public init(capacity: Index_Primitives.Index<Key>.Count) throws(Dictionary.Ordered.Bounded.Error) {
                self._keys = Set<Key>.Ordered()
                self._keys.reserve(capacity)
                self._values = Buffer<Value>.Linear.Bounded(minimumCapacity: capacity.retag(Value.self))
                self.capacity = capacity
            }

            // Note: No deinit needed - Buffer.Linear.Bounded handles cleanup
        }

        // MARK: - Inline Variant

        /// A fixed-capacity, inline-storage ordered dictionary with compile-time capacity.
        ///
        /// `Dictionary.Ordered.Static` stores elements directly within the struct's memory layout,
        /// requiring no heap allocation. The capacity is specified as a compile-time
        /// generic parameter.
        ///
        /// - Note: This type is declared inside `Ordered` (not in an extension) due to a
        ///   Swift compiler bug where nested types with value generic parameters declared
        ///   in extensions do not properly inherit `~Copyable` constraints from the outer type.
        public struct Static<let capacity: Int>: ~Copyable {
            /// Value storage using Buffer.Linear.Inline from buffer-primitives.
            @usableFromInline
            var _values: Buffer<Value>.Linear.Inline<capacity>

            /// Keys stored inline.
            @usableFromInline
            var _keys: InlineArray<capacity, Key?>

            /// Hash table for O(1) key lookup (maps hash bucket to key index, -1 for empty).
            @usableFromInline
            var _hashTable: InlineArray<capacity, Int>

            // WORKAROUND: _count stored as raw Int, not Index<Key>.Count
            // WHY: Key storage still uses InlineArray<capacity, Key?> which indexes by Int
            // WHEN TO REMOVE: Key storage migration to Buffer<Key>.Linear.Inline + Hash.Table<Key>.Static
            @usableFromInline
            var _count: Int

            /// Workaround for Swift compiler bug where deinit element cleanup
            /// fails for ~Copyable structs that contain only value-type properties.
            /// Adding a reference type property (`AnyObject?`) fixes the bug.
            /// See: https://github.com/swiftlang/swift/issues/86652
            @usableFromInline
            var _deinitWorkaround: AnyObject? = nil

            /// Creates an empty inline ordered dictionary.
            @inlinable
            public init() {
                self._values = Buffer<Value>.Linear.Inline<capacity>()
                self._keys = InlineArray(repeating: nil)
                self._hashTable = InlineArray(repeating: -1)
                self._count = 0
            }

            deinit {
                // Buffer.Linear.Inline handles element cleanup via Storage.Inline's deinit.
            }
        }

        // MARK: - Small Variant

        /// An ordered dictionary with small-buffer optimization (SmallVec pattern).
        ///
        /// `Dictionary.Ordered.Small` stores up to `inlineCapacity` elements in inline storage,
        /// then automatically spills to heap storage when that capacity is exceeded.
        /// This provides the performance benefits of inline storage for common cases
        /// while supporting unbounded growth.
        ///
        /// ## Example
        ///
        /// ```swift
        /// var dict = Dictionary<String, Int>.Ordered.Small<4>()  // Inline up to 4 elements
        /// dict.set("a", 1)  // Inline
        /// dict.set("b", 2)  // Inline
        /// dict.set("c", 3)  // Inline
        /// dict.set("d", 4)  // Inline
        /// dict.set("e", 5)  // Spills to heap, moves all elements
        /// ```
        ///
        /// ## Non-Copyable
        ///
        /// `Dictionary.Ordered.Small` is unconditionally `~Copyable` (move-only) because it requires
        /// a deinitializer to clean up inline storage.
        ///
        /// - Note: This type is declared inside `Ordered` (not in an extension) due to a
        ///   Swift compiler bug where nested types with value generic parameters declared
        ///   in extensions do not properly inherit `~Copyable` constraints from the outer type.
        @safe
        public struct Small<let inlineCapacity: Int>: ~Copyable {
            /// Value storage using Buffer.Linear.Small — handles inline/heap dispatch internally.
            @usableFromInline
            var _values: Buffer<Value>.Linear.Small<inlineCapacity>

            /// Keys stored inline.
            @usableFromInline
            var _inlineKeys: InlineArray<inlineCapacity, Key?>

            /// Hash table for inline mode.
            @usableFromInline
            var _inlineHashTable: InlineArray<inlineCapacity, Int>

            // WORKAROUND: _count stored as raw Int, not Index<Key>.Count
            // WHY: Key storage still uses InlineArray<inlineCapacity, Key?> which indexes by Int
            // WHEN TO REMOVE: Key storage migration to Buffer<Key>.Linear.Inline + Hash.Table<Key>.Static
            @usableFromInline
            var _count: Int

            /// Heap storage for keys when spilled. Nil when using inline storage.
            @usableFromInline
            var _heapKeys: Set<Key>.Ordered?

            /// Creates an empty small ordered dictionary.
            @inlinable
            public init() {
                self._values = Buffer<Value>.Linear.Small<inlineCapacity>()
                self._inlineKeys = InlineArray(repeating: nil)
                self._inlineHashTable = InlineArray(repeating: -1)
                self._count = 0
                self._heapKeys = nil
            }

            deinit {
                // Buffer.Linear.Small handles cleanup for both inline and heap modes.
            }

            /// Whether the dictionary is currently using heap storage.
            @inlinable
            public var isSpilled: Bool { _heapKeys != nil }

            /// Spills inline key storage to heap.
            @usableFromInline
            mutating func _spillKeysToHeap() {
                precondition(_heapKeys == nil, "Already spilled")

                var heapKeys = Set<Key>.Ordered()
                for i in 0..<_count {
                    if let key = _inlineKeys[i] {
                        heapKeys.insert(key)
                    }
                }

                _heapKeys = heapKeys
            }
        }
    }
}

// MARK: - Conditional Copyable

/// `Dictionary.Ordered` is `Copyable` when its values are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Dictionary_Primitives_Core.Dictionary.Ordered: Copyable where Value: Copyable {}

/// `Dictionary.Ordered.Bounded` is `Copyable` when its values are `Copyable`.
extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Copyable where Value: Copyable {}

/// `Dictionary.Ordered.Entry` is `Copyable` when its values are `Copyable`.
///
/// This enables Entry to be used as Swift.Sequence.Element while preserving
/// ~Copyable value support for the drain operation.
extension Dictionary_Primitives_Core.Dictionary.Ordered.Entry: Copyable where Value: Copyable {}

// Note: Dictionary.Ordered.Small and Dictionary.Ordered.Static are UNCONDITIONALLY ~Copyable due to deinit requirement

// MARK: - Sendable

extension Dictionary_Primitives_Core.Dictionary.Ordered: @unchecked Sendable where Key: Sendable, Value: Sendable {}
extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: @unchecked Sendable where Key: Sendable, Value: Sendable {}
extension Dictionary_Primitives_Core.Dictionary.Ordered.Static: @unchecked Sendable where Key: Sendable, Value: Sendable {}
extension Dictionary_Primitives_Core.Dictionary.Ordered.Small: @unchecked Sendable where Key: Sendable, Value: Sendable {}

// MARK: - Swift.Sequence/Collection Conformances
//
// Per [REFACTOR-002]: Swift.Sequence and Collection conformances are in separate variant modules
// to avoid constraint poisoning. These protocols implicitly require Element: Copyable.
//
// Variant modules:
// - Dictionary Ordered Primitives: Swift.Sequence, Collection, BidirectionalCollection, RandomAccessCollection
// - Dictionary Bounded Primitives: Swift.Sequence
//
// For ~Copyable values, use forEach(_:) or drain(_:).
