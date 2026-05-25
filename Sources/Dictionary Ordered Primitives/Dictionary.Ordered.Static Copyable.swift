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

public import Buffer_Linear_Primitive
public import Dictionary_Primitives_Core
public import Index_Primitives
internal import Sequence_Primitives
public import Buffer_Linear_Inline_Primitive

// Note: Dictionary.Ordered.Static is unconditionally ~Copyable (inline storage requires deinit),
// so it cannot conform to Swift.Sequence which requires Copyable.
// It conforms to Sequence.Protocol which supports ~Copyable containers.

// ============================================================================
// MARK: - Iterator
// ============================================================================

extension Dictionary_Primitives_Core.Dictionary.Ordered.Static where Value: Copyable {
    /// Iterator for Dictionary.Ordered.Static key-value pairs.
    ///
    /// Copies keys and values to `Buffer.Linear` snapshots for safe iteration,
    /// avoiding pointer escape issues with inline storage.
    ///
    /// - Note: Uses `_element` for single-element Optional inline span production.
    ///   The underlying `_keys` and `_values` snapshots are contiguous `Buffer.Linear`s —
    ///   composing two `Buffer.Linear.Iterator`s could eliminate the buffer,
    ///   but tuple packaging prevents direct delegation.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        public typealias Element = (key: Key, value: Value)

        @usableFromInline
        let _keys: Buffer<Key>.Linear

        @usableFromInline
        let _values: Buffer<Value>.Linear

        @usableFromInline
        let _end: Index_Primitives.Index<Key>.Count

        @usableFromInline
        var _position: Index_Primitives.Index<Key> = .zero

        @usableFromInline
        var _element: Element? = nil

        @usableFromInline
        init(keys: Buffer<Key>.Linear, values: Buffer<Value>.Linear) {
            self._keys = keys
            self._values = values
            self._end = keys.count
        }

        @_lifetime(&self)
        @inlinable
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            let ptr = unsafe withUnsafeMutablePointer(to: &_element) { p in
                unsafe UnsafePointer<Element>(
                    unsafe UnsafeRawPointer(p).assumingMemoryBound(to: Element.self)
                )
            }
            guard maximumCount > .zero else {
                let span = unsafe Span(_unsafeStart: ptr, count: 0)
                return unsafe _overrideLifetime(span, mutating: &self)
            }
            guard let value = next() else {
                let span = unsafe Span(_unsafeStart: ptr, count: 0)
                return unsafe _overrideLifetime(span, mutating: &self)
            }
            _element = value
            let span = unsafe Span(_unsafeStart: ptr, count: 1)
            return unsafe _overrideLifetime(span, mutating: &self)
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _position < _end else { return nil }
            let key = _keys[_position]
            let value = _values[_position.retag(Value.self)]
            _position += .one
            return (key, value)
        }
    }
}

extension Dictionary_Primitives_Core.Dictionary.Ordered.Static.Iterator: Sendable
where Key: Sendable, Value: Sendable {}

// ============================================================================
// MARK: - Sequence.Protocol Conformance
// ============================================================================

extension Dictionary_Primitives_Core.Dictionary.Ordered.Static: Sequence.`Protocol` where Value: Copyable {
    /// Returns an iterator over the dictionary's key-value pairs.
    ///
    /// Copies keys and values to `Buffer.Linear` snapshots for safe iteration,
    /// avoiding pointer escape issues with inline storage.
    /// Pairs are yielded in insertion order.
    ///
    /// - Note: Incurs O(n) copy cost. For performance-critical code, use
    ///   the `withValue(forKey:_:)` method or index-based access instead.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        var keySnapshot = Buffer<Key>.Linear(minimumCapacity: _keys.count)
        var valueSnapshot = Buffer<Value>.Linear(minimumCapacity: _values.count)
        var i: Index_Primitives.Index<Key> = .zero
        let end = _keys.count.map(Ordinal.init)
        while i < end {
            keySnapshot.append(_keys[i])
            valueSnapshot.append(_values[i.retag(Value.self)])
            i += .one
        }
        return Iterator(keys: keySnapshot, values: valueSnapshot)
    }

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// ============================================================================
// MARK: - Sequence.Clearable Conformance
// ============================================================================

extension Dictionary_Primitives_Core.Dictionary.Ordered.Static: Sequence.Clearable where Value: Copyable {
    /// Removes all key-value pairs from the dictionary.
    ///
    /// This enables `.forEach.consuming { }` pattern via `Property.Inout` extension.
    @inlinable
    public mutating func removeAll() {
        clear()
    }
}
