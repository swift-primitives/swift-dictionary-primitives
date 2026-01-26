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
public import Sequence_Primitives
public import Property_Primitives

// MARK: - Note on Swift.Collection Conformances
//
// Swift.Sequence/Collection conformances are defined in Dictionary Primitives Core
// alongside the type definitions. This is required for proper witness table generation.
//
// This module provides Sequence_Primitives protocol conformances that support
// ~Copyable elements.

// MARK: - Sequence.Drain.Protocol Conformance

/// Conformance wrapper for drain protocol.
///
/// The drain method is defined in Dictionary Primitives Core.
/// This extension declares conformance to `Sequence.Drain.Protocol`.
extension Dictionary_Primitives_Core.Dictionary.Ordered: Sequence.Drain.`Protocol` {
    // Element type is Dictionary.Ordered.Element (defined in Core)
    // drain(_ body:) method is defined in Dictionary.Ordered.swift
}

// MARK: - Property Accessor for drain

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Property accessor for `.drain { }` syntax.
    ///
    /// Draining removes all key-value pairs from the dictionary, passing each to the closure.
    /// The dictionary survives but is empty after draining.
    ///
    /// ```swift
    /// var dict = Dictionary<String, Int>.Ordered()
    /// dict["a"] = 1
    /// dict["b"] = 2
    /// dict.drain { key, value in print("\(key): \(value)") }
    /// // prints "a: 1" and "b: 2"
    /// // dict is now empty but still usable
    /// dict["c"] = 3  // OK
    /// ```
    ///
    /// - Complexity: O(n) where n is the number of elements.
    public var drain: Property<Sequence.Drain, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View(&self)
            yield &view
        }
    }
}
