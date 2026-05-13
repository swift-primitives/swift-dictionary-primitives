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

import Buffer_Linear_Inline_Primitives
import Buffer_Linear_Small_Primitives
import Index_Primitives
import Set_Primitives

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {

    // MARK: - Small (SmallVec Pattern)

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
    // WHY: Category D — structural Sendable workaround; the type is
    // WHY: structurally value-safe but the compiler cannot synthesize
    // WHY: Sendable due to a stored pointer / generic parameter shape.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// Element cleanup is handled by Storage.Inline's deinit (inline path) or Storage.Heap's deinit (spilled path).

        @usableFromInline
        package var _count: Index_Primitives.Index<Key>.Count

        /// Heap storage for keys when spilled. Nil when using inline storage.
        @usableFromInline
        package var _heapKeys: Set<Key>.Ordered?

        /// Value storage using Buffer.Linear.Small — handles inline/heap dispatch internally.
        @usableFromInline
        package var _values: Buffer<Value>.Linear.Small<inlineCapacity>

        /// Dense key storage for inline mode.
        @usableFromInline
        package var _inlineKeys: Buffer<Key>.Linear.Inline<inlineCapacity>

        /// Creates an empty small ordered dictionary.
        @inlinable
        public init() {
            self._values = Buffer<Value>.Linear.Small<inlineCapacity>()
            self._inlineKeys = Buffer<Key>.Linear.Inline<inlineCapacity>()
            self._count = .zero
            self._heapKeys = nil
        }

        /// Whether the dictionary is currently using heap storage.
        @inlinable
        public var isSpilled: Bool { _heapKeys != nil }

        /// Spills inline key storage to heap.
        @usableFromInline
        mutating func _spillKeysToHeap() {
            precondition(_heapKeys == nil, "Already spilled")

            var heapKeys = Set<Key>.Ordered()
            _inlineKeys.forEach { key in
                heapKeys.insert(key)
            }
            _heapKeys = heapKeys
            _inlineKeys.removeAll()
        }
    }
}

// MARK: - Sendable

extension Dictionary_Primitives_Core.Dictionary.Ordered.Small: Sendable where Key: Sendable, Value: Sendable {}
