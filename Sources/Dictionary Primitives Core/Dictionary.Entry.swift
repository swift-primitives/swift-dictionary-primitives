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

extension Dictionary_Primitives_Core.Dictionary where Value: ~Copyable {

    /// A key-value pair entry from the dictionary.
    ///
    /// Supports ~Copyable values, unlike tuples which require Copyable elements.
    /// Used as the `Element` type for drain operations.
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

/// `Dictionary.Entry` is `Copyable` when its values are `Copyable`.
extension Dictionary_Primitives_Core.Dictionary.Entry: Copyable where Value: Copyable {}
