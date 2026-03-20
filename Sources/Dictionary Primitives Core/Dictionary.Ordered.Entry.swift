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

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {

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
}

// MARK: - Conditional Conformances

/// `Dictionary.Ordered.Entry` is `Copyable` when its values are `Copyable`.
///
/// This enables Entry to be used as Swift.Sequence.Element while preserving
/// ~Copyable value support for the drain operation.
extension Dictionary_Primitives_Core.Dictionary.Ordered.Entry: Copyable where Value: Copyable {}
