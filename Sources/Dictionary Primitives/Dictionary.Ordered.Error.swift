// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Dictionary.Ordered {
    /// Typed error for ordered dictionary operations.
    ///
    /// Uses typed throws for compile-time exhaustiveness.
    public enum Error: Swift.Error {
        /// An index was out of bounds.
        case bounds(Bounds)

        /// An operation was attempted on an empty dictionary.
        case empty(Empty)

        /// A duplicate key was detected during initialization.
        case duplicate(Duplicate)
    }
}

// MARK: - Error Payloads

extension Dictionary.Ordered.Error {
    /// Bounds violation payload.
    public struct Bounds: Sendable, Equatable {
        public let index: Int
        public let count: Int

        @inlinable
        public init(index: Int, count: Int) {
            self.index = index
            self.count = count
        }
    }

    /// Empty collection payload.
    public struct Empty: Sendable, Equatable {
        @inlinable
        public init() {}
    }

    /// Duplicate key payload.
    ///
    /// Data-only struct carrying information about a duplicate key.
    /// Does **not** conform to `Swift.Error`.
    public struct Duplicate {
        /// The duplicate key.
        public let key: Key

        /// Index of the first occurrence.
        public let first: Int

        /// Index where the duplicate was found.
        public let second: Int

        @inlinable
        public init(key: Key, first: Int, second: Int) {
            self.key = key
            self.first = first
            self.second = second
        }
    }
}

// MARK: - Sendable

extension Dictionary.Ordered.Error: Sendable where Key: Sendable {}
extension Dictionary.Ordered.Error.Duplicate: Sendable where Key: Sendable {}

// MARK: - Equatable

extension Dictionary.Ordered.Error: Equatable where Key: Equatable {}
extension Dictionary.Ordered.Error.Duplicate: Equatable where Key: Equatable {}

// MARK: - CustomStringConvertible

extension Dictionary.Ordered.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bounds(let e): return "index \(e.index) out of bounds for count \(e.count)"
        case .empty: return "operation attempted on empty ordered dictionary"
        case .duplicate(let e): return e.description
        }
    }
}

extension Dictionary.Ordered.Error.Duplicate: CustomStringConvertible {
    public var description: String {
        "duplicate key '\(key)' at indices \(first) and \(second)"
    }
}
