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

public import Buffer_Slab_Primitives

// MARK: - forEach { } (borrowing key-value pairs)

extension Property.Borrow where Base: ~Copyable {

    /// Iterates all key-value pairs, borrowing each value.
    ///
    /// The view borrows the entire Dictionary, so both `_keys` and `_values`
    /// are accessed through `base.value` — no re-borrow conflict.
    ///
    /// Typed while loop with early termination — Level 3 iteration per [IMPL-033],
    /// acceptable inside iteration infrastructure implementation.
    ///
    /// - Complexity: O(capacity) worst case, terminates early when all occupied
    ///   slots have been visited.
    @inlinable
    public func callAsFunction<Key, Value>(
        _ body: (Key, borrowing Value) -> Void
    ) where Tag == Sequence.ForEach, Base == Dictionary_Primitives_Core.Dictionary<Key, Value>, Value: ~Copyable {
        var slot: Bit.Index = .zero
        let end = base.value._keys.capacity.map(Ordinal.init)
        var remaining = base.value._keys.occupancy
        while slot < end, remaining != .zero {
            if base.value._keys.isOccupied(at: slot) {
                body(
                    base.value._keys[slot],
                    base.value._values[slot]
                )
                remaining = remaining.subtract.saturating(.one)
            }
            slot += .one
        }
    }
}
