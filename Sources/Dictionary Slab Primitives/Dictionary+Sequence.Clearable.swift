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

public import Dictionary_Primitives_Core
import Sequence_Primitives

// MARK: - Sequence.Clearable Conformance

extension Dictionary_Primitives_Core.Dictionary: Sequence.Clearable where Value: Copyable {
    /// Removes all key-value pairs from the dictionary.
    ///
    /// This enables `.forEach.consuming { }` pattern via `Property.Inout` extension.
    @inlinable
    public mutating func removeAll() {
        clear(keepingCapacity: false)
    }
}
