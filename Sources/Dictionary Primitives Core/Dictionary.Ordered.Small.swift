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
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// Value storage using Buffer.Linear.Small — handles inline/heap dispatch internally.
        @usableFromInline
        package var _values: Buffer<Value>.Linear.Small<inlineCapacity>

        /// Dense key storage for inline mode.
        @usableFromInline
        package var _inlineKeys: Buffer<Key>.Linear.Inline<inlineCapacity>

        @usableFromInline
        package var _count: Index_Primitives.Index<Key>.Count

        /// Heap storage for keys when spilled. Nil when using inline storage.
        @usableFromInline
        package var _heapKeys: Set<Key>.Ordered?

        // WORKAROUND: swiftlang/swift#86652 — @_rawLayout triviality misclassification.
        // Forces compiler to recognize type as non-trivially destructible so deinit executes.
        // COST: 8 bytes overhead per instance.
        // REMOVAL TEST: swift-buffer-primitives/Experiments/rawlayout-access-level-trigger/
        //   Build with `public` access under -O. If it passes, remove this field
        //   and the manual cleanup in deinit.
        // TRACKING: swift-buffer-primitives/Research/rawlayout-release-crash-investigation.md
        private var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty small ordered dictionary.
        @inlinable
        public init() {
            self._values = Buffer<Value>.Linear.Small<inlineCapacity>()
            self._inlineKeys = Buffer<Key>.Linear.Inline<inlineCapacity>()
            self._count = .zero
            self._heapKeys = nil
        }

        deinit {
            // WORKAROUND: Manually clean up elements via the mutating path.
            // TRACKING: swiftlang/swift #86652 variant
            unsafe withUnsafePointer(to: _values) { ptr in
                unsafe UnsafeMutablePointer(mutating: ptr).pointee.remove.all()
            }
            unsafe withUnsafePointer(to: _inlineKeys) { ptr in
                unsafe UnsafeMutablePointer(mutating: ptr).pointee.remove.all()
            }
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

extension Dictionary_Primitives_Core.Dictionary.Ordered.Small: @unchecked Sendable where Key: Sendable, Value: Sendable {}
