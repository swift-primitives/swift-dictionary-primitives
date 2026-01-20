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

public import Set_Primitives

// MARK: - Sequence (Copyable values only)
//
// Sequence and Collection conformances are only available when Value is Copyable
// because iteration requires copying elements. For ~Copyable values, use forEach(_:).

extension Dictionary_Primitives.Dictionary.Ordered: Sequence where Value: Copyable {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        var index: Int

        @usableFromInline
        let keys: Set<Key>.Ordered

        @usableFromInline
        let valueStorage: ValueStorage

        @usableFromInline
        let count: Int

        @usableFromInline
        init(keys: Set<Key>.Ordered, valueStorage: ValueStorage) {
            self.index = 0
            self.keys = keys
            self.valueStorage = valueStorage
            self.count = valueStorage.header
        }

        @inlinable
        public mutating func next() -> (key: Key, value: Value)? {
            guard index < count else { return nil }
            let key = keys[index]
            let value = valueStorage._readValue(at: index)
            index += 1
            return (key, value)
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(keys: _keys, valueStorage: _valueStorage)
    }
}

extension Dictionary_Primitives.Dictionary.Ordered.Iterator: @unchecked Sendable where Key: Sendable, Value: Sendable {}

// MARK: - Collection (Copyable values only)

extension Dictionary_Primitives.Dictionary.Ordered: Collection where Value: Copyable {
    public typealias Index = Int
    public typealias Element = (key: Key, value: Value)

    @inlinable
    public var startIndex: Index { 0 }

    @inlinable
    public var endIndex: Index { count }

    @inlinable
    public func index(after i: Index) -> Index {
        i + 1
    }

    @inlinable
    public subscript(position: Index) -> Element {
        precondition(position >= 0 && position < count, "Index out of bounds")
        return (_keys[position], _valueStorage._readValue(at: position))
    }
}

// MARK: - BidirectionalCollection (Copyable values only)

extension Dictionary_Primitives.Dictionary.Ordered: BidirectionalCollection where Value: Copyable {
    @inlinable
    public func index(before i: Index) -> Index {
        i - 1
    }
}

// MARK: - RandomAccessCollection (Copyable values only)

extension Dictionary_Primitives.Dictionary.Ordered: RandomAccessCollection where Value: Copyable {
    @inlinable
    public func distance(from start: Index, to end: Index) -> Int {
        end - start
    }

    @inlinable
    public func index(_ i: Index, offsetBy distance: Int) -> Index {
        i + distance
    }

    @inlinable
    public func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        let result = i + distance
        if distance >= 0 {
            return result <= limit ? result : nil
        } else {
            return result >= limit ? result : nil
        }
    }
}

// MARK: - Bounded Sequence (Copyable values only)

extension Dictionary_Primitives.Dictionary.Ordered.Bounded: Sequence where Value: Copyable {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        var index: Int

        @usableFromInline
        let keys: Set<Key>.Ordered

        @usableFromInline
        let valueStorage: Dictionary<Key, Value>.Ordered.ValueStorage

        @usableFromInline
        let count: Int

        @usableFromInline
        init(keys: Set<Key>.Ordered, valueStorage: Dictionary<Key, Value>.Ordered.ValueStorage) {
            self.index = 0
            self.keys = keys
            self.valueStorage = valueStorage
            self.count = valueStorage.header
        }

        @inlinable
        public mutating func next() -> (key: Key, value: Value)? {
            guard index < count else { return nil }
            let key = keys[index]
            let value = valueStorage._readValue(at: index)
            index += 1
            return (key, value)
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(keys: _keys, valueStorage: _valueStorage)
    }
}

extension Dictionary_Primitives.Dictionary.Ordered.Bounded.Iterator: @unchecked Sendable where Key: Sendable, Value: Sendable {}
