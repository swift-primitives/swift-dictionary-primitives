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

public import Index_Primitives
public import Set_Primitives

// MARK: - Hoisted Error Types (Module Level)
//
// WORKAROUND: Hoisted error types due to Swift generic nesting limitation
// WHY: Swift does not allow nested types inside generic types to be easily accessed.
//      These error types are hoisted to module level and exposed via typealiases to
//      provide the expected Nest.Name API (Dictionary.Ordered.Error, etc.).
// WHEN TO REMOVE: When Swift allows direct generic nested type access (nested types
//                 inside generic types accessible without module-level hoisting)
// TRACKING: [API-EXC-001] in swift-institute documentation

/// Hoisted implementation of ``Dictionary/Ordered/Error``.
///
/// - Note: Use ``Dictionary/Ordered/Error`` in your code, not this type directly.
public enum __DictionaryOrderedError<Key: Hash.`Protocol`>: Swift.Error {
    /// An index was out of bounds.
    case bounds(Bounds)

    /// An operation was attempted on an empty dictionary.
    case empty(Empty)

    /// A duplicate key was detected during initialization.
    case duplicate(Duplicate)

    /// Bounds violation payload.
    public struct Bounds: Sendable, Equatable {
        public let index: Index_Primitives.Index<Key>
        public let count: Index_Primitives.Index<Key>.Count

        @inlinable
        public init(index: Index_Primitives.Index<Key>, count: Index_Primitives.Index<Key>.Count) {
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
    public struct Duplicate {
        /// The duplicate key.
        public let key: Key

        /// Index of the first occurrence.
        public let first: Index_Primitives.Index<Key>

        /// Index where the duplicate was found.
        public let second: Index_Primitives.Index<Key>.Count

        @inlinable
        public init(key: Key, first: Index_Primitives.Index<Key>, second: Index_Primitives.Index<Key>.Count) {
            self.key = key
            self.first = first
            self.second = second
        }
    }
}

/// Hoisted implementation of ``Dictionary/Ordered/Bounded/Error``.
///
/// - Note: Use ``Dictionary/Ordered/Bounded/Error`` in your code, not this type directly.
public enum __DictionaryOrderedBoundedError<Key: Hash.`Protocol`>: Swift.Error {
    /// An index was out of bounds.
    case bounds(index: Index_Primitives.Index<Key>, count: Index_Primitives.Index<Key>.Count)

    /// An operation was attempted on an empty dictionary.
    case empty

    /// A duplicate key was detected.
    case duplicate(key: Key, first: Index_Primitives.Index<Key>, second: Index_Primitives.Index<Key>.Count)

    /// The dictionary is full and cannot accept more pairs.
    case overflow

    /// The requested capacity is invalid (negative).
    case invalidCapacity
}

/// Hoisted implementation of ``Dictionary/Ordered/Inline/Error``.
///
/// - Note: Use ``Dictionary/Ordered/Inline/Error`` in your code, not this type directly.
public enum __DictionaryOrderedInlineError<Key: Hash.`Protocol`>: Swift.Error {
    /// The dictionary is full and cannot accept more pairs.
    case overflow

    /// An index was out of bounds.
    case bounds(Bounds)

    /// A duplicate key was detected.
    case duplicate(key: Key, first: Index_Primitives.Index<Key>, second: Index_Primitives.Index<Key>.Count)

    /// Bounds violation payload.
    public struct Bounds: Sendable, Equatable {
        public let index: Index_Primitives.Index<Key>
        public let count: Index_Primitives.Index<Key>.Count

        @inlinable
        public init(index: Index_Primitives.Index<Key>, count: Index_Primitives.Index<Key>.Count) {
            self.index = index
            self.count = count
        }
    }
}

// MARK: - Sendable

extension __DictionaryOrderedError: Sendable where Key: Sendable {}
extension __DictionaryOrderedError.Duplicate: Sendable where Key: Sendable {}
extension __DictionaryOrderedBoundedError: Sendable where Key: Sendable {}
extension __DictionaryOrderedInlineError: Sendable where Key: Sendable {}

// MARK: - Equatable

extension __DictionaryOrderedError: Equatable where Key: Equatable {}
extension __DictionaryOrderedError.Duplicate: Equatable where Key: Equatable {}
extension __DictionaryOrderedBoundedError: Equatable where Key: Equatable {}
extension __DictionaryOrderedInlineError: Equatable where Key: Equatable {}

// MARK: - CustomStringConvertible

extension __DictionaryOrderedError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bounds(let e):
            return "index \(e.index) out of bounds for count \(e.count)"
        case .empty:
            return "operation attempted on empty ordered dictionary"
        case .duplicate(let e):
            return "duplicate key '\(e.key)' at indices \(e.first) and \(e.second)"
        }
    }
}

extension __DictionaryOrderedBoundedError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bounds(let index, let count):
            return "index \(index) out of bounds for count \(count)"
        case .empty:
            return "operation attempted on empty ordered dictionary"
        case .duplicate(let key, let first, let second):
            return "duplicate key '\(key)' at indices \(first) and \(second)"
        case .overflow:
            return "bounded dictionary is full"
        case .invalidCapacity:
            return "invalid capacity"
        }
    }
}

extension __DictionaryOrderedInlineError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .overflow:
            return "inline dictionary is full"
        case .bounds(let e):
            return "index \(e.index) out of bounds for count \(e.count)"
        case .duplicate(let key, let first, let second):
            return "duplicate key '\(key)' at indices \(first) and \(second)"
        }
    }
}

// MARK: - Typealiases (Nest.Name API)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Errors that can occur during ordered dictionary operations.
    ///
    /// ## Cases
    ///
    /// - ``Dictionary/Ordered/Error/bounds(_:)``: An index was out of bounds.
    /// - ``Dictionary/Ordered/Error/empty(_:)``: An operation was attempted on an empty dictionary.
    /// - ``Dictionary/Ordered/Error/duplicate(_:)``: A duplicate key was detected.
    public typealias Error = __DictionaryOrderedError<Key>
}
