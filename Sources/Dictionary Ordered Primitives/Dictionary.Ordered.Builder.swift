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

extension Dictionary.Ordered where Value: Copyable {
    /// A result builder for declaratively constructing ordered dictionaries.
    ///
    /// Each declared expression is a `(Key, Value)` tuple. Insertion order
    /// is preserved; duplicate keys after the first occurrence overwrite
    /// previous values (last-write-wins):
    ///
    /// ```swift
    /// let dict = Dictionary<String, Int>.Ordered {
    ///     ("alpha", 1)
    ///     ("beta", 2)
    ///     ("gamma", 3)
    /// }
    /// dict["beta"]  // 2
    /// ```
    ///
    /// ## Element Constraint
    ///
    /// Dictionary.Ordered.Builder requires `Value: Copyable` because the
    /// underlying `set(_:_:)` operation does not yet support `~Copyable`
    /// values. ~Copyable Value support is a future ecosystem extension
    /// and is out of round-1 scope.
    @resultBuilder
    public enum Builder {

        // MARK: - Expression Building

        @inlinable
        public static func buildExpression(
            _ expression: (Key, Value)
        ) -> [(Key, Value)] {
            [expression]
        }

        @inlinable
        public static func buildExpression(
            _ expression: [(Key, Value)]
        ) -> [(Key, Value)] {
            expression
        }

        /// Bulk-add a sequence of key-value pairs without per-iteration allocation.
        @inlinable
        public static func buildExpression<S: Swift.Sequence>(
            _ expression: S
        ) -> [(Key, Value)]
        where S.Element == (Key, Value) {
            Array(expression)
        }

        @inlinable
        public static func buildExpression(
            _ expression: (Key, Value)?
        ) -> [(Key, Value)] {
            expression.map { [$0] } ?? []
        }

        // MARK: - Partial Block Building

        @inlinable
        public static func buildPartialBlock(
            first: [(Key, Value)]
        ) -> [(Key, Value)] {
            first
        }

        @inlinable
        public static func buildPartialBlock(
            first: Void
        ) -> [(Key, Value)] {
            []
        }

        @inlinable
        public static func buildPartialBlock(
            first: Never
        ) -> [(Key, Value)] {}

        @inlinable
        public static func buildPartialBlock(
            accumulated: consuming [(Key, Value)],
            next: [(Key, Value)]
        ) -> [(Key, Value)] {
            accumulated.append(contentsOf: next)
            return accumulated
        }

        // MARK: - Block Building

        @inlinable
        public static func buildBlock() -> [(Key, Value)] {
            []
        }

        // MARK: - Control Flow

        @inlinable
        public static func buildOptional(
            _ component: [(Key, Value)]?
        ) -> [(Key, Value)] {
            component ?? []
        }

        @inlinable
        public static func buildEither(
            first: [(Key, Value)]
        ) -> [(Key, Value)] {
            first
        }

        @inlinable
        public static func buildEither(
            second: [(Key, Value)]
        ) -> [(Key, Value)] {
            second
        }

        @inlinable
        public static func buildArray(
            _ components: [[(Key, Value)]]
        ) -> [(Key, Value)] {
            components.flatMap { $0 }
        }

        @inlinable
        public static func buildLimitedAvailability(
            _ component: [(Key, Value)]
        ) -> [(Key, Value)] {
            component
        }
    }
}

// MARK: - Convenience Init

extension Dictionary.Ordered where Value: Copyable {
    /// Constructs an ordered dictionary from a result-builder closure.
    ///
    /// Each expression is a `(Key, Value)` tuple. Duplicate keys overwrite
    /// previous values (last-write-wins).
    ///
    /// ```swift
    /// let dict = Dictionary<String, Int>.Ordered {
    ///     ("alpha", 1)
    ///     ("beta", 2)
    /// }
    /// ```
    @inlinable
    public init(
        @Dictionary.Ordered.Builder _ builder: () -> [(Key, Value)]
    ) {
        self = (try? Self(builder(), uniquingKeysWith: { _, new in new })) ?? Self()
    }
}
