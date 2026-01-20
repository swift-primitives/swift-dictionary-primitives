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

/// Namespace for ordered dictionary types.
///
/// This shadows `Swift.Dictionary`. Use `Swift.Dictionary` or module-qualified
/// `Dictionary_Primitives.Dictionary` to disambiguate when both are in scope.
public enum Dictionary<Key: Hashable, Value: ~Copyable>: ~Copyable {
    /// An ordered dictionary that preserves insertion order, supporting move-only values.
    ///
    /// `Ordered` combines the key-value semantics of a dictionary with the ordering
    /// guarantees of an array. Key-value pairs are stored in insertion order and
    /// can be accessed by index.
    ///
    /// ## API
    ///
    /// Key operations use nested accessors:
    ///
    /// ```swift
    /// var dict = Dictionary<String, Int>.Ordered()
    ///
    /// // Value operations
    /// dict.values.set("apple", 1)
    /// dict.values.set("banana", 2)
    /// let removed = dict.values.remove("apple")
    ///
    /// // Key operations
    /// if let idx = dict.keys.index("banana") { ... }
    ///
    /// // Subscript access
    /// dict["cherry"] = 3
    /// let value = dict["cherry"]
    /// ```
    ///
    /// ## Ordering Semantics
    ///
    /// - Setting a new key adds to the end
    /// - Updating existing key does NOT move position
    /// - Removal shifts subsequent pairs (indices change)
    /// - Re-insertion after removal goes to end
    ///
    /// ## Move-Only Support
    ///
    /// Both the dictionary and its values can be `~Copyable`:
    ///
    /// ```swift
    /// struct FileHandle: ~Copyable { ... }
    /// var dict = Dictionary<String, FileHandle>.Ordered()
    /// dict.set("primary", FileHandle())
    /// ```
    ///
    /// Note: Keys must always be `Hashable` (which implies `Copyable`).
    ///
    /// ## Copy-on-Write
    ///
    /// When `Value` is `Copyable`, `Dictionary.Ordered` uses copy-on-write semantics:
    /// copies share storage until mutation.
    ///
    /// ## Thread Safety
    ///
    /// Not thread-safe for concurrent mutation. Synchronize externally.
    ///
    /// ## Complexity
    ///
    /// - Set/get/remove by key: O(1) average
    /// - Index lookup: O(1) average
    /// - Random access by index: O(1)
    ///
    /// ## Variants
    ///
    /// - ``Dictionary/Ordered``: Dynamically-growing storage (this type)
    /// - ``Dictionary/Ordered/Bounded``: Fixed-capacity, throws on overflow
    /// - ``Dictionary/Ordered/Inline``: Zero-allocation inline storage with compile-time capacity
    /// - ``Dictionary/Ordered/Small``: Inline storage with automatic spill to heap
    @safe
    public struct Ordered: ~Copyable {

        // MARK: - ValueStorage (nested to inherit Value's ~Copyable context)

        /// Internal storage class for values using ManagedBuffer.
        ///
        /// Declared as a nested class inside `Ordered` so that the `Value` generic
        /// inherits the `~Copyable` suppression from the outer type.
        @usableFromInline
        final class ValueStorage: ManagedBuffer<Int, Value> {

            /// Creates empty storage with the specified minimum capacity.
            @usableFromInline
            static func create(minimumCapacity: Int) -> ValueStorage {
                let storage = ValueStorage.create(minimumCapacity: minimumCapacity) { _ in 0 }
                return unsafe unsafeDowncast(storage, to: ValueStorage.self)
            }

            deinit {
                let count = header
                guard count > 0 else { return }
                _ = unsafe withUnsafeMutablePointerToElements { elements in
                    for i in 0..<count {
                        unsafe (elements + i).deinitialize(count: 1)
                    }
                }
            }

            /// Returns pointer to element storage.
            @usableFromInline
            var _elementsPointer: UnsafeMutablePointer<Value> {
                unsafe withUnsafeMutablePointerToElements { unsafe $0 }
            }

            /// Initializes value at the given index.
            @usableFromInline
            func _initializeValue(at index: Int, to value: consuming Value) {
                let ptr = unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
                unsafe ptr.initialize(to: value)
            }

            /// Moves value from the given index.
            @usableFromInline
            func _moveValue(at index: Int) -> Value {
                unsafe withUnsafeMutablePointerToElements { elements in
                    unsafe (elements + index).move()
                }
            }

            /// Shifts values left from `from` to fill gap at removed index, then decrements header count.
            @usableFromInline
            func _shiftValuesLeftAndDecrement(removedAt index: Int, count: Int) {
                guard index < count - 1 else {
                    // Last element, no shift needed
                    header = count - 1
                    return
                }
                _ = unsafe withUnsafeMutablePointerToElements { elements in
                    // Move elements from index+1..count to index..count-1
                    for i in index..<(count - 1) {
                        unsafe (elements + i).initialize(to: (elements + i + 1).move())
                    }
                }
                header = count - 1
            }

            /// Moves all values to new storage.
            @usableFromInline
            func _moveAllValues(to newStorage: ValueStorage) {
                let count = header
                guard count > 0 else { return }
                _ = unsafe withUnsafeMutablePointerToElements { src in
                    unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                        for i in 0..<count {
                            unsafe (dst + i).initialize(to: (src + i).move())
                        }
                    }
                }
            }

            /// Deinitializes all values.
            @usableFromInline
            func _deinitializeAllValues() {
                let count = header
                guard count > 0 else { return }
                _ = unsafe withUnsafeMutablePointerToElements { elements in
                    for i in 0..<count {
                        unsafe (elements + i).deinitialize(count: 1)
                    }
                }
                header = 0
            }
        }

        @usableFromInline
        var _keys: Set<Key>.Ordered

        @usableFromInline
        var _valueStorage: ValueStorage

        /// Cached pointer to value storage. Stored in struct to enable property-based access.
        /// CRITICAL: Must be updated whenever _valueStorage is replaced (reallocation, CoW copy).
        @usableFromInline
        var _cachedValuePtr: UnsafeMutablePointer<Value>

        /// Creates an empty ordered dictionary.
        @inlinable
        public init() {
            self._keys = Set<Key>.Ordered()
            self._valueStorage = ValueStorage.create(minimumCapacity: 0)
            unsafe (self._cachedValuePtr = _valueStorage._elementsPointer)
        }

        // Note: No deinit needed - ValueStorage handles cleanup

        // MARK: - Bounded Variant

        /// A fixed-capacity ordered dictionary that throws on overflow.
        ///
        /// `Dictionary.Ordered.Bounded` allocates storage upfront and throws when
        /// inserting a key-value pair would exceed the capacity.
        ///
        /// ## Example
        ///
        /// ```swift
        /// var dict = try Dictionary<String, Int>.Ordered.Bounded(capacity: 10)
        /// try dict.set("apple", 1)
        /// try dict.set("banana", 2)
        /// dict["apple"]  // Optional(1)
        /// ```
        ///
        /// ## Move-Only Support
        ///
        /// Both the dictionary and its values can be `~Copyable`:
        ///
        /// ```swift
        /// struct FileHandle: ~Copyable { ... }
        /// var dict = try Dictionary<String, FileHandle>.Ordered.Bounded(capacity: 5)
        /// try dict.set("primary", FileHandle())
        /// ```
        @safe
        public struct Bounded: ~Copyable {
            @usableFromInline
            var _keys: Set<Key>.Ordered

            @usableFromInline
            var _valueStorage: ValueStorage

            /// Cached pointer to value storage.
            @usableFromInline
            var _cachedValuePtr: UnsafeMutablePointer<Value>

            /// The maximum number of key-value pairs the dictionary can hold.
            public let capacity: Int

            /// Creates a bounded ordered dictionary with the specified capacity.
            ///
            /// - Parameter capacity: Maximum number of pairs. Must be non-negative.
            /// - Throws: ``Dictionary/Ordered/Bounded/Error/invalidCapacity`` if capacity is negative.
            @inlinable
            public init(capacity: Int) throws(__DictionaryOrderedBoundedError<Key>) {
                guard capacity >= 0 else {
                    throw .invalidCapacity
                }
                self._keys = Set<Key>.Ordered()
                self._keys.reserve(capacity)
                self._valueStorage = ValueStorage.create(minimumCapacity: capacity)
                unsafe (self._cachedValuePtr = _valueStorage._elementsPointer)
                self.capacity = capacity
            }

            // Note: No deinit needed - ValueStorage handles cleanup
        }

        // MARK: - Inline Variant

        /// A fixed-capacity, inline-storage ordered dictionary with compile-time capacity.
        ///
        /// `Dictionary.Ordered.Inline` stores elements directly within the struct's memory layout,
        /// requiring no heap allocation. The capacity is specified as a compile-time
        /// generic parameter.
        ///
        /// - Note: This type is declared inside `Ordered` (not in an extension) due to a
        ///   Swift compiler bug where nested types with value generic parameters declared
        ///   in extensions do not properly inherit `~Copyable` constraints from the outer type.
        public struct Inline<let capacity: Int>: ~Copyable {
            /// Maximum value stride supported by inline storage (64 bytes per slot).
            @usableFromInline
            static var _maxValueStride: Int { 64 }

            /// Raw byte storage for values. Each slot is 64 bytes (8 Ints on 64-bit).
            @usableFromInline
            var _values: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

            /// Keys stored inline.
            @usableFromInline
            var _keys: InlineArray<capacity, Key?>

            /// Hash table for O(1) key lookup (maps hash bucket to key index, -1 for empty).
            @usableFromInline
            var _hashTable: InlineArray<capacity, Int>

            /// Current element count.
            @usableFromInline
            var _count: Int

            /// Creates an empty inline ordered dictionary.
            @inlinable
            public init() {
                precondition(
                    MemoryLayout<Value>.stride <= Self._maxValueStride,
                    "Value stride (\(MemoryLayout<Value>.stride)) exceeds inline storage slot size (\(Self._maxValueStride) bytes). Use Dictionary.Ordered.Bounded instead."
                )
                precondition(
                    MemoryLayout<Value>.alignment <= MemoryLayout<Int>.alignment,
                    "Value alignment (\(MemoryLayout<Value>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment)). Use Dictionary.Ordered.Bounded instead."
                )
                self._values = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
                self._keys = InlineArray(repeating: nil)
                self._hashTable = InlineArray(repeating: -1)
                self._count = 0
            }

            deinit {
                let count = _count
                guard count > 0 else { return }

                let stride = MemoryLayout<Value>.stride
                unsafe Swift.withUnsafeBytes(of: _values) { bytes in
                    let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for i in 0..<count {
                        let valuePtr = unsafe (basePtr + i * stride)
                            .assumingMemoryBound(to: Value.self)
                        unsafe valuePtr.deinitialize(count: 1)
                    }
                }
            }

            /// Returns a mutable pointer to the value at the given index.
            @usableFromInline
            @unsafe
            mutating func _pointerToValue(at index: Int) -> UnsafeMutablePointer<Value> {
                let stride = MemoryLayout<Value>.stride
                return unsafe Swift.withUnsafeMutablePointer(to: &_values) { storagePtr in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let valuePtr = unsafe (basePtr + index * stride)
                        .assumingMemoryBound(to: Value.self)
                    return unsafe valuePtr
                }
            }

            /// Returns a read-only pointer to the value at the given index.
            @usableFromInline
            @unsafe
            func _readPointerToValue(at index: Int) -> UnsafePointer<Value> {
                let stride = MemoryLayout<Value>.stride
                return unsafe Swift.withUnsafePointer(to: _values) { storagePtr in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let valuePtr = unsafe (basePtr + index * stride)
                        .assumingMemoryBound(to: Value.self)
                    return unsafe valuePtr
                }
            }
        }

        // MARK: - Small Variant

        /// An ordered dictionary with small-buffer optimization (SmallVec pattern).
        ///
        /// `Dictionary.Ordered.Small` stores up to `inlineCapacity` elements in inline storage,
        /// then automatically spills to heap storage when that capacity is exceeded.
        /// This provides the performance benefits of inline storage for common cases
        /// while supporting unbounded growth.
        ///
        /// ## Example
        ///
        /// ```swift
        /// var dict = Dictionary<String, Int>.Ordered.Small<4>()  // Inline up to 4 elements
        /// dict.set("a", 1)  // Inline
        /// dict.set("b", 2)  // Inline
        /// dict.set("c", 3)  // Inline
        /// dict.set("d", 4)  // Inline
        /// dict.set("e", 5)  // Spills to heap, moves all elements
        /// ```
        ///
        /// ## Non-Copyable
        ///
        /// `Dictionary.Ordered.Small` is unconditionally `~Copyable` (move-only) because it requires
        /// a deinitializer to clean up inline storage.
        ///
        /// - Note: This type is declared inside `Ordered` (not in an extension) due to a
        ///   Swift compiler bug where nested types with value generic parameters declared
        ///   in extensions do not properly inherit `~Copyable` constraints from the outer type.
        @safe
        public struct Small<let inlineCapacity: Int>: ~Copyable {
            /// Maximum value stride supported by inline storage (64 bytes per slot).
            @usableFromInline
            static var _maxValueStride: Int { 64 }

            /// Raw byte storage for inline values.
            @usableFromInline
            var _inlineValues: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

            /// Keys stored inline.
            @usableFromInline
            var _inlineKeys: InlineArray<inlineCapacity, Key?>

            /// Hash table for inline mode.
            @usableFromInline
            var _inlineHashTable: InlineArray<inlineCapacity, Int>

            /// Current element count (valid in both inline and heap modes).
            @usableFromInline
            var _count: Int

            /// Heap storage for keys when spilled. Nil when using inline storage.
            @usableFromInline
            var _heapKeys: Set<Key>.Ordered?

            /// Heap storage for values when spilled. Nil when using inline storage.
            @usableFromInline
            var _heapValues: ValueStorage?

            /// Cached pointer to heap values. Only valid when _heapValues is non-nil.
            @usableFromInline
            var _heapValuePtr: UnsafeMutablePointer<Value>?

            /// Creates an empty small ordered dictionary.
            @inlinable
            public init() {
                precondition(
                    MemoryLayout<Value>.stride <= Self._maxValueStride,
                    "Value stride (\(MemoryLayout<Value>.stride)) exceeds inline storage slot size (\(Self._maxValueStride) bytes). Use Dictionary.Ordered.Bounded instead."
                )
                precondition(
                    MemoryLayout<Value>.alignment <= MemoryLayout<Int>.alignment,
                    "Value alignment (\(MemoryLayout<Value>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment)). Use Dictionary.Ordered.Bounded instead."
                )
                self._inlineValues = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
                self._inlineKeys = InlineArray(repeating: nil)
                self._inlineHashTable = InlineArray(repeating: -1)
                self._count = 0
                self._heapKeys = nil
                self._heapValues = nil
                unsafe (self._heapValuePtr = nil)
            }

            deinit {
                let count = _count
                guard count > 0 else { return }

                if _heapValues != nil {
                    // Elements are on heap - ValueStorage handles cleanup via its deinit
                    // Set header count for proper cleanup
                    _heapValues!.header = count
                } else {
                    // Elements are inline - clean up manually
                    let stride = MemoryLayout<Value>.stride
                    unsafe Swift.withUnsafeBytes(of: _inlineValues) { bytes in
                        let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                        for i in 0..<count {
                            let valuePtr = unsafe (basePtr + i * stride)
                                .assumingMemoryBound(to: Value.self)
                            unsafe valuePtr.deinitialize(count: 1)
                        }
                    }
                }
            }

            /// Whether the dictionary is currently using heap storage.
            @inlinable
            public var isSpilled: Bool { _heapKeys != nil }

            // MARK: - Internal Helpers

            /// Returns a mutable pointer to the inline value at the given index.
            @usableFromInline
            @unsafe
            mutating func _inlinePointerToValue(at index: Int) -> UnsafeMutablePointer<Value> {
                let stride = MemoryLayout<Value>.stride
                return unsafe Swift.withUnsafeMutablePointer(to: &_inlineValues) { storagePtr in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let valuePtr = unsafe (basePtr + index * stride)
                        .assumingMemoryBound(to: Value.self)
                    return unsafe valuePtr
                }
            }

            /// Returns a read-only pointer to the inline value at the given index.
            @usableFromInline
            @unsafe
            func _inlineReadPointerToValue(at index: Int) -> UnsafePointer<Value> {
                let stride = MemoryLayout<Value>.stride
                return unsafe Swift.withUnsafePointer(to: _inlineValues) { storagePtr in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let valuePtr = unsafe (basePtr + index * stride)
                        .assumingMemoryBound(to: Value.self)
                    return unsafe valuePtr
                }
            }

            /// Spills inline storage to heap.
            @usableFromInline
            mutating func _spillToHeap(minimumCapacity: Int) {
                precondition(_heapKeys == nil, "Already spilled")

                // Create heap storage with growth factor
                let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
                let newKeys = Set<Key>.Ordered()
                let newValues = ValueStorage.create(minimumCapacity: newCapacity)

                // Move keys from inline to heap
                var heapKeys = newKeys
                for i in 0..<_count {
                    if let key = _inlineKeys[i] {
                        heapKeys.insert(key)
                    }
                }

                // Move values from inline to heap
                let stride = MemoryLayout<Value>.stride
                _ = unsafe Swift.withUnsafeBytes(of: _inlineValues) { bytes in
                    unsafe newValues.withUnsafeMutablePointerToElements { heapPtr in
                        let inlineBase = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                        for i in 0..<_count {
                            let inlineValue = unsafe (inlineBase + i * stride)
                                .assumingMemoryBound(to: Value.self)
                            unsafe (heapPtr + i).initialize(to: inlineValue.move())
                        }
                    }
                }
                newValues.header = _count

                _heapKeys = heapKeys
                _heapValues = newValues
                unsafe (_heapValuePtr = newValues._elementsPointer)
            }
        }
    }
}

// MARK: - Conditional Copyable

/// `Dictionary.Ordered` is `Copyable` when its values are `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Dictionary_Primitives.Dictionary.Ordered: Copyable where Value: Copyable {}

/// `Dictionary.Ordered.Bounded` is `Copyable` when its values are `Copyable`.
extension Dictionary_Primitives.Dictionary.Ordered.Bounded: Copyable where Value: Copyable {}

// Note: Dictionary.Ordered.Small and Dictionary.Ordered.Inline are UNCONDITIONALLY ~Copyable due to deinit requirement

// MARK: - ValueStorage Copyable Helpers

extension Dictionary_Primitives.Dictionary.Ordered.ValueStorage where Value: Copyable {

    /// Creates a copy of this storage with all values duplicated.
    @usableFromInline
    func copy() -> Dictionary<Key, Value>.Ordered.ValueStorage {
        let count = header
        guard count > 0 else {
            return Dictionary<Key, Value>.Ordered.ValueStorage.create(minimumCapacity: 0)
        }

        let new = Dictionary<Key, Value>.Ordered.ValueStorage.create(minimumCapacity: capacity)
        new.header = count

        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe new.withUnsafeMutablePointerToElements { dst in
                for i in 0..<count {
                    unsafe (dst + i).initialize(to: src[i])
                }
            }
        }

        return new
    }

    /// Reads value at the given index.
    @usableFromInline
    func _readValue(at index: Int) -> Value {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe elements[index]
        }
    }

    /// Copies all values to new storage.
    @usableFromInline
    func _copyAllValues(to newStorage: Dictionary<Key, Value>.Ordered.ValueStorage) {
        let count = header
        guard count > 0 else { return }
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                for i in 0..<count {
                    unsafe (dst + i).initialize(to: src[i])
                }
            }
        }
    }
}

// MARK: - Initialization

extension Dictionary_Primitives.Dictionary.Ordered where Value: ~Copyable {
    /// Creates an ordered dictionary with reserved capacity.
    ///
    /// Pre-allocates storage for the specified number of elements.
    ///
    /// - Parameter capacity: Number of elements to reserve space for. Must be non-negative.
    /// - Throws: ``Dictionary/Ordered/Error/bounds(_:)`` if capacity is negative.
    @inlinable
    public init(reservingCapacity capacity: Int) throws(Error) {
        guard capacity >= 0 else {
            throw .bounds(.init(index: capacity, count: 0))
        }

        self._keys = Set<Key>.Ordered()
        self._keys.reserve(capacity)
        self._valueStorage = ValueStorage.create(minimumCapacity: capacity)
        unsafe (self._cachedValuePtr = _valueStorage._elementsPointer)
    }
}

extension Dictionary_Primitives.Dictionary.Ordered where Value: Copyable {
    /// Creates an ordered dictionary from key-value pairs.
    ///
    /// - Parameter pairs: The key-value pairs.
    /// - Throws: `Ordered.Error.duplicate` if duplicate keys are found.
    @inlinable
    public init(_ pairs: some Sequence<(Key, Value)>) throws(Error) {
        self.init()
        for (key, value) in pairs {
            let (inserted, _) = _keys.insert(key)
            if !inserted {
                let first = _keys.index(key)!
                throw .duplicate(.init(key: key, first: first, second: _keys.count))
            }
            ensureCapacity(_valueStorage.header + 1)
            _valueStorage._initializeValue(at: _valueStorage.header, to: value)
            _valueStorage.header += 1
        }
    }

    /// Creates an ordered dictionary from key-value pairs, using a closure to resolve duplicates.
    ///
    /// - Parameters:
    ///   - pairs: The key-value pairs.
    ///   - combine: A closure that receives the existing and new values, returning the value to keep.
    @inlinable
    public init(
        _ pairs: some Sequence<(Key, Value)>,
        uniquingKeysWith combine: (Value, Value) throws -> Value
    ) rethrows {
        self.init()
        for (key, value) in pairs {
            if let existingIndex = _keys.index(key) {
                let existingValue = _valueStorage._readValue(at: existingIndex)
                let newValue = try combine(existingValue, value)
                // Deinitialize old and initialize new
                _ = _valueStorage._moveValue(at: existingIndex)
                _valueStorage._initializeValue(at: existingIndex, to: newValue)
            } else {
                ensureCapacity(_valueStorage.header + 1)
                _keys.insert(key)
                _valueStorage._initializeValue(at: _valueStorage.header, to: value)
                _valueStorage.header += 1
            }
        }
    }
}

// MARK: - Properties

extension Dictionary_Primitives.Dictionary.Ordered where Value: ~Copyable {
    /// The number of key-value pairs.
    @inlinable
    public var count: Int {
        _keys.count
    }

    /// Whether the dictionary is empty.
    @inlinable
    public var isEmpty: Bool {
        _keys.isEmpty
    }

    /// The current capacity.
    @inlinable
    public var capacity: Int {
        _valueStorage.capacity
    }
}

// MARK: - Contains

extension Dictionary_Primitives.Dictionary.Ordered where Value: ~Copyable {
    /// Returns whether the dictionary contains the given key.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if the key exists.
    @inlinable
    public func contains(_ key: Key) -> Bool {
        _keys.contains(key)
    }
}

// MARK: - Capacity Management

extension Dictionary_Primitives.Dictionary.Ordered where Value: ~Copyable {
    /// Ensures the dictionary has capacity for at least the specified number of elements.
    @usableFromInline
    mutating func ensureCapacity(_ minimumCapacity: Int) {
        guard _valueStorage.capacity < minimumCapacity else { return }

        // Growth factor 2.0, minimum capacity 4
        let newCapacity = Swift.max(minimumCapacity, _valueStorage.capacity * 2, 4)
        let newStorage = ValueStorage.create(minimumCapacity: newCapacity)
        let currentCount = _valueStorage.header

        _valueStorage._moveAllValues(to: newStorage)
        newStorage.header = currentCount
        _valueStorage = newStorage
        unsafe (_cachedValuePtr = _valueStorage._elementsPointer)  // CRITICAL: Update cached pointer
    }

    /// Reserves enough space for the specified number of pairs.
    ///
    /// - Parameter minimumCapacity: The minimum number of pairs.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        _keys.reserve(minimumCapacity)
        ensureCapacity(minimumCapacity)
    }
}

// MARK: - Core Operations (Base - for ~Copyable values)

extension Dictionary_Primitives.Dictionary.Ordered where Value: ~Copyable {
    /// Sets the value for the given key.
    ///
    /// - Parameters:
    ///   - key: The key.
    ///   - value: The value to associate with the key.
    /// - Complexity: O(1) amortized.
    @inlinable
    public mutating func set(_ key: Key, _ value: consuming Value) {
        if let existingIndex = _keys.index(key) {
            _ = _valueStorage._moveValue(at: existingIndex)
            _valueStorage._initializeValue(at: existingIndex, to: value)
        } else {
            ensureCapacity(_valueStorage.header + 1)
            _keys.insert(key)
            _valueStorage._initializeValue(at: _valueStorage.header, to: value)
            _valueStorage.header += 1
        }
    }

    /// Removes the value for the given key.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if not present.
    /// - Complexity: O(n) due to index shifting.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        guard let index = _keys.index(key) else { return nil }
        let count = _valueStorage.header
        _keys.remove(key)
        let value = _valueStorage._moveValue(at: index)
        _valueStorage._shiftValuesLeftAndDecrement(removedAt: index, count: count)
        return value
    }

    /// Removes all key-value pairs.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        _keys.clear(keepingCapacity: keepingCapacity)
        _valueStorage._deinitializeAllValues()
        if !keepingCapacity {
            _valueStorage = ValueStorage.create(minimumCapacity: 0)
            unsafe (_cachedValuePtr = _valueStorage._elementsPointer)
        }
    }
}

// MARK: - Copy-on-Write (Copyable values only)

extension Dictionary_Primitives.Dictionary.Ordered where Value: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_valueStorage) {
            _valueStorage = _valueStorage.copy()
            unsafe (_cachedValuePtr = _valueStorage._elementsPointer)  // CRITICAL: Update cached pointer
        }
    }

    /// Sets the value for the given key (CoW-aware).
    ///
    /// This method shadows the base `set(_:_:)` when `Value: Copyable`,
    /// providing copy-on-write semantics.
    @inlinable
    public mutating func set(_ key: Key, _ value: Value) {
        makeUnique()
        if let existingIndex = _keys.index(key) {
            _ = _valueStorage._moveValue(at: existingIndex)
            _valueStorage._initializeValue(at: existingIndex, to: value)
        } else {
            ensureCapacity(_valueStorage.header + 1)
            _keys.insert(key)
            _valueStorage._initializeValue(at: _valueStorage.header, to: value)
            _valueStorage.header += 1
        }
    }

    /// Removes the value for the given key (CoW-aware).
    ///
    /// This method shadows the base `remove(_:)` when `Value: Copyable`,
    /// providing copy-on-write semantics.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if not present.
    /// - Complexity: O(n) due to index shifting, O(n) if copy triggered.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        makeUnique()
        guard let index = _keys.index(key) else { return nil }
        let count = _valueStorage.header
        _keys.remove(key)
        let value = _valueStorage._moveValue(at: index)
        _valueStorage._shiftValuesLeftAndDecrement(removedAt: index, count: count)
        return value
    }

    /// Removes all key-value pairs (CoW-aware).
    ///
    /// This method shadows the base `clear(keepingCapacity:)` when `Value: Copyable`,
    /// providing copy-on-write semantics.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        makeUnique()
        _keys.clear(keepingCapacity: keepingCapacity)
        _valueStorage._deinitializeAllValues()
        if !keepingCapacity {
            _valueStorage = ValueStorage.create(minimumCapacity: 0)
            unsafe (_cachedValuePtr = _valueStorage._elementsPointer)
        }
    }
}

// MARK: - Subscript Access (Copyable values only)

extension Dictionary_Primitives.Dictionary.Ordered where Value: Copyable {
    /// Accesses the value for the given key.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The value if the key exists, or `nil`.
    @inlinable
    public subscript(key: Key) -> Value? {
        get {
            guard let index = _keys.index(key) else { return nil }
            return _valueStorage._readValue(at: index)
        }
        set {
            if let newValue = newValue {
                set(key, newValue)
            } else {
                remove(key)
            }
        }
    }

    /// Accesses the key-value pair at the given index.
    ///
    /// - Parameter index: The index of the pair.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public subscript(index index: Int) -> (key: Key, value: Value) {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return (_keys[index], _valueStorage._readValue(at: index))
    }
}

// MARK: - Peek (for ~Copyable values)

extension Dictionary_Primitives.Dictionary.Ordered where Value: ~Copyable {
    /// Accesses the value for the given key via closure (for ~Copyable values).
    ///
    /// - Parameters:
    ///   - key: The key to look up.
    ///   - body: A closure that receives a borrowed reference to the value.
    /// - Returns: The result of the closure, or `nil` if the key doesn't exist.
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        guard let index = _keys.index(key) else { return nil }
        return unsafe _valueStorage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + index).pointee)
        }
    }

    /// Accesses the value at the given index via closure (for ~Copyable values).
    ///
    /// - Parameters:
    ///   - index: The index.
    ///   - body: A closure that receives a borrowed reference to the value.
    /// - Returns: The result of the closure.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return unsafe _valueStorage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + index).pointee)
        }
    }
}

// MARK: - forEach (for ~Copyable values)

extension Dictionary_Primitives.Dictionary.Ordered where Value: ~Copyable {
    /// Calls the given closure for each key-value pair in the dictionary.
    ///
    /// Elements are visited in insertion order.
    ///
    /// - Parameter body: A closure that receives each key and borrowed value.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach(_ body: (Key, borrowing Value) -> Void) {
        let count = _valueStorage.header
        guard count > 0 else { return }
        _ = unsafe _valueStorage.withUnsafeMutablePointerToElements { elements in
            for i in 0..<count {
                body(_keys[i], unsafe (elements + i).pointee)
            }
        }
    }
}

// MARK: - Sendable

extension Dictionary_Primitives.Dictionary.Ordered: @unchecked Sendable where Key: Sendable, Value: Sendable {}
extension Dictionary_Primitives.Dictionary.Ordered.Bounded: @unchecked Sendable where Key: Sendable, Value: Sendable {}
extension Dictionary_Primitives.Dictionary.Ordered.Inline: @unchecked Sendable where Key: Sendable, Value: Sendable {}
extension Dictionary_Primitives.Dictionary.Ordered.Small: @unchecked Sendable where Key: Sendable, Value: Sendable {}

// MARK: - Equatable (Copyable values only)

extension Dictionary_Primitives.Dictionary.Ordered: Equatable where Value: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs._keys == rhs._keys else { return false }
        let count = lhs._valueStorage.header
        for i in 0..<count {
            if lhs._valueStorage._readValue(at: i) != rhs._valueStorage._readValue(at: i) {
                return false
            }
        }
        return true
    }
}

// MARK: - Hashable (Copyable values only)

extension Dictionary_Primitives.Dictionary.Ordered: Hashable where Value: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for i in 0..<count {
            hasher.combine(_keys[i])
            hasher.combine(_valueStorage._readValue(at: i))
        }
    }
}

// MARK: - CustomStringConvertible

extension Dictionary_Primitives.Dictionary.Ordered: CustomStringConvertible where Value: Copyable {
    public var description: String {
        var result = "Dictionary.Ordered(["
        var first = true
        for i in 0..<count {
            if !first { result += ", " }
            result += "\(_keys[i]): \(_valueStorage._readValue(at: i))"
            first = false
        }
        result += "])"
        return result
    }
}

// MARK: - Bounded Variant Extensions

extension Dictionary_Primitives.Dictionary.Ordered.Bounded where Value: ~Copyable {
    /// Errors that can occur during bounded ordered dictionary operations.
    public typealias Error = __DictionaryOrderedBoundedError<Key>

    /// The number of key-value pairs.
    @inlinable
    public var count: Int { _keys.count }

    /// Whether the dictionary is empty.
    @inlinable
    public var isEmpty: Bool { _keys.isEmpty }

    /// Whether the dictionary is at capacity.
    @inlinable
    public var isFull: Bool { _keys.count >= capacity }

    /// Returns whether the dictionary contains the given key.
    @inlinable
    public func contains(_ key: Key) -> Bool {
        _keys.contains(key)
    }

    /// Sets a value for the given key.
    ///
    /// - Parameters:
    ///   - key: The key.
    ///   - value: The value to associate with the key.
    /// - Throws: ``Dictionary/Ordered/Bounded/Error/overflow`` if the dictionary is full
    ///   and the key is new.
    @inlinable
    public mutating func set(_ key: Key, _ value: consuming Value) throws(Error) {
        if let existingIndex = _keys.index(key) {
            _ = _valueStorage._moveValue(at: existingIndex)
            _valueStorage._initializeValue(at: existingIndex, to: value)
        } else {
            guard _keys.count < capacity else {
                throw .overflow
            }
            _keys.insert(key)
            _valueStorage._initializeValue(at: _valueStorage.header, to: value)
            _valueStorage.header += 1
        }
    }

    /// Removes a key-value pair.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if the key was not present.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        guard let index = _keys.index(key) else { return nil }
        let count = _valueStorage.header
        _keys.remove(key)
        let value = _valueStorage._moveValue(at: index)
        _valueStorage._shiftValuesLeftAndDecrement(removedAt: index, count: count)
        return value
    }

    /// Removes all key-value pairs.
    @inlinable
    public mutating func clear() {
        _keys.clear(keepingCapacity: true)
        _valueStorage._deinitializeAllValues()
    }
}

extension Dictionary_Primitives.Dictionary.Ordered.Bounded where Value: Copyable {
    /// Accesses the value for the given key.
    @inlinable
    public subscript(key: Key) -> Value? {
        get {
            guard let index = _keys.index(key) else { return nil }
            return _valueStorage._readValue(at: index)
        }
    }

    /// Accesses the key-value pair at the given index.
    @inlinable
    public subscript(index index: Int) -> (key: Key, value: Value) {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return (_keys[index], _valueStorage._readValue(at: index))
    }
}

extension Dictionary_Primitives.Dictionary.Ordered.Bounded where Value: ~Copyable {
    /// Accesses the value for the given key via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        guard let index = _keys.index(key) else { return nil }
        return unsafe _valueStorage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + index).pointee)
        }
    }

    /// Accesses the value at the given index via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return unsafe _valueStorage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + index).pointee)
        }
    }
}

extension Dictionary_Primitives.Dictionary.Ordered.Bounded: Equatable where Value: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs._keys == rhs._keys else { return false }
        let count = lhs._valueStorage.header
        for i in 0..<count {
            if lhs._valueStorage._readValue(at: i) != rhs._valueStorage._readValue(at: i) {
                return false
            }
        }
        return true
    }
}

extension Dictionary_Primitives.Dictionary.Ordered.Bounded: Hashable where Value: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for i in 0..<count {
            hasher.combine(_keys[i])
            hasher.combine(_valueStorage._readValue(at: i))
        }
    }
}

// MARK: - Inline Variant Extensions

extension Dictionary_Primitives.Dictionary.Ordered.Inline where Value: ~Copyable {
    /// Errors that can occur during inline ordered dictionary operations.
    public typealias Error = __DictionaryOrderedInlineError<Key>

    /// The number of key-value pairs.
    @inlinable
    public var count: Int { _count }

    /// Whether the dictionary is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Whether the dictionary is at capacity.
    @inlinable
    public var isFull: Bool { _count >= capacity }

    /// Returns whether the dictionary contains the given key.
    @inlinable
    public func contains(_ key: Key) -> Bool {
        index(of: key) != nil
    }

    /// Returns the index of the given key, or nil if not present.
    @inlinable
    public func index(of key: Key) -> Int? {
        // Linear search for simplicity in inline storage
        for i in 0..<_count {
            if _keys[i] == key {
                return i
            }
        }
        return nil
    }

    /// Sets a value for the given key.
    ///
    /// - Parameters:
    ///   - key: The key.
    ///   - value: The value to associate with the key.
    /// - Throws: ``Dictionary/Ordered/Inline/Error/overflow`` if the dictionary is full
    ///   and the key is new.
    @inlinable
    public mutating func set(_ key: Key, _ value: consuming Value) throws(Error) {
        if let existingIndex = index(of: key) {
            // Update existing
            let ptr = unsafe _pointerToValue(at: existingIndex)
            unsafe ptr.deinitialize(count: 1)
            unsafe ptr.initialize(to: value)
        } else {
            guard _count < capacity else {
                throw .overflow
            }
            // Insert new
            _keys[_count] = key
            let ptr = unsafe _pointerToValue(at: _count)
            unsafe ptr.initialize(to: value)
            _count += 1
        }
    }

    /// Removes a key-value pair.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if the key was not present.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        guard let index = index(of: key) else { return nil }

        let ptr = unsafe _pointerToValue(at: index)
        let value = unsafe ptr.move()

        // Shift keys and values left
        for i in index..<(_count - 1) {
            _keys[i] = _keys[i + 1]
            let srcPtr = unsafe _pointerToValue(at: i + 1)
            let dstPtr = unsafe _pointerToValue(at: i)
            unsafe dstPtr.initialize(to: srcPtr.move())
        }
        _keys[_count - 1] = nil
        _count -= 1

        return value
    }

    /// Removes all key-value pairs.
    @inlinable
    public mutating func clear() {
        for i in 0..<_count {
            let ptr = unsafe _pointerToValue(at: i)
            unsafe ptr.deinitialize(count: 1)
            _keys[i] = nil
        }
        _count = 0
    }
}

extension Dictionary_Primitives.Dictionary.Ordered.Inline where Value: Copyable {
    /// Accesses the value for the given key.
    @inlinable
    public subscript(key: Key) -> Value? {
        get {
            guard let index = index(of: key) else { return nil }
            return unsafe _readPointerToValue(at: index).pointee
        }
    }

    /// Accesses the key-value pair at the given index.
    @inlinable
    public subscript(index index: Int) -> (key: Key, value: Value) {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return (_keys[index]!, unsafe _readPointerToValue(at: index).pointee)
    }
}

extension Dictionary_Primitives.Dictionary.Ordered.Inline where Value: ~Copyable {
    /// Accesses the value for the given key via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        guard let index = index(of: key) else { return nil }
        return body(unsafe _readPointerToValue(at: index).pointee)
    }

    /// Accesses the value at the given index via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return body(unsafe _readPointerToValue(at: index).pointee)
    }
}

// Note: Inline is unconditionally ~Copyable (has deinit), cannot conform to Equatable/Hashable
// which require Copyable. Use isEqual(to:) method instead if needed.

// MARK: - Small Variant Extensions

extension Dictionary_Primitives.Dictionary.Ordered.Small where Value: ~Copyable {
    /// The number of key-value pairs.
    @inlinable
    public var count: Int { _count }

    /// Whether the dictionary is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Returns whether the dictionary contains the given key.
    @inlinable
    public func contains(_ key: Key) -> Bool {
        if let heapKeys = _heapKeys {
            return heapKeys.contains(key)
        }
        return _inlineIndex(of: key) != nil
    }

    /// Returns the index of the given key in inline storage.
    @usableFromInline
    func _inlineIndex(of key: Key) -> Int? {
        for i in 0..<_count {
            if _inlineKeys[i] == key {
                return i
            }
        }
        return nil
    }

    /// Sets a value for the given key.
    ///
    /// - Parameters:
    ///   - key: The key.
    ///   - value: The value to associate with the key.
    @inlinable
    public mutating func set(_ key: Key, _ value: consuming Value) {
        if let heapKeys = _heapKeys {
            // Heap mode
            if let existingIndex = heapKeys.index(key) {
                _ = _heapValues!._moveValue(at: existingIndex)
                _heapValues!._initializeValue(at: existingIndex, to: value)
            } else {
                // Ensure capacity
                if _heapValues!.capacity <= _count {
                    let newCapacity = Swift.max(_count * 2, 8)
                    let newStorage = Dictionary<Key, Value>.Ordered.ValueStorage.create(minimumCapacity: newCapacity)
                    _heapValues!._moveAllValues(to: newStorage)
                    newStorage.header = _count
                    _heapValues = newStorage
                    unsafe (_heapValuePtr = newStorage._elementsPointer)
                }
                _heapKeys!.insert(key)
                _heapValues!._initializeValue(at: _heapValues!.header, to: value)
                _heapValues!.header += 1
                _count += 1
            }
        } else {
            // Inline mode
            if let existingIndex = _inlineIndex(of: key) {
                let ptr = unsafe _inlinePointerToValue(at: existingIndex)
                unsafe ptr.deinitialize(count: 1)
                unsafe ptr.initialize(to: value)
            } else if _count < inlineCapacity {
                // Still room in inline storage
                _inlineKeys[_count] = key
                let ptr = unsafe _inlinePointerToValue(at: _count)
                unsafe ptr.initialize(to: value)
                _count += 1
            } else {
                // Need to spill to heap
                _spillToHeap(minimumCapacity: _count + 1)
                _heapKeys!.insert(key)
                _heapValues!._initializeValue(at: _heapValues!.header, to: value)
                _heapValues!.header += 1
                _count += 1
            }
        }
    }

    /// Removes a key-value pair.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if the key was not present.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        if let heapKeys = _heapKeys {
            // Heap mode
            guard let index = heapKeys.index(key) else { return nil }
            let count = _heapValues!.header
            _heapKeys!.remove(key)
            let value = _heapValues!._moveValue(at: index)
            _heapValues!._shiftValuesLeftAndDecrement(removedAt: index, count: count)
            _count -= 1
            return value
        } else {
            // Inline mode
            guard let index = _inlineIndex(of: key) else { return nil }

            let ptr = unsafe _inlinePointerToValue(at: index)
            let value = unsafe ptr.move()

            // Shift keys and values left
            for i in index..<(_count - 1) {
                _inlineKeys[i] = _inlineKeys[i + 1]
                let srcPtr = unsafe _inlinePointerToValue(at: i + 1)
                let dstPtr = unsafe _inlinePointerToValue(at: i)
                unsafe dstPtr.initialize(to: srcPtr.move())
            }
            _inlineKeys[_count - 1] = nil
            _count -= 1

            return value
        }
    }

    /// Removes all key-value pairs.
    @inlinable
    public mutating func clear() {
        if let heapValues = _heapValues {
            _heapKeys!.clear(keepingCapacity: true)
            heapValues._deinitializeAllValues()
        } else {
            for i in 0..<_count {
                let ptr = unsafe _inlinePointerToValue(at: i)
                unsafe ptr.deinitialize(count: 1)
                _inlineKeys[i] = nil
            }
        }
        _count = 0
    }
}

extension Dictionary_Primitives.Dictionary.Ordered.Small where Value: Copyable {
    /// Accesses the value for the given key.
    @inlinable
    public subscript(key: Key) -> Value? {
        get {
            if let heapKeys = _heapKeys {
                guard let index = heapKeys.index(key) else { return nil }
                return _heapValues!._readValue(at: index)
            }
            guard let index = _inlineIndex(of: key) else { return nil }
            return unsafe _inlineReadPointerToValue(at: index).pointee
        }
    }

    /// Accesses the key-value pair at the given index.
    @inlinable
    public subscript(index index: Int) -> (key: Key, value: Value) {
        precondition(index >= 0 && index < count, "Index out of bounds")
        if let heapKeys = _heapKeys {
            return (heapKeys[index], _heapValues!._readValue(at: index))
        }
        return (_inlineKeys[index]!, unsafe _inlineReadPointerToValue(at: index).pointee)
    }
}

extension Dictionary_Primitives.Dictionary.Ordered.Small where Value: ~Copyable {
    /// Accesses the value for the given key via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        if let heapKeys = _heapKeys {
            guard let index = heapKeys.index(key) else { return nil }
            return unsafe _heapValues!.withUnsafeMutablePointerToElements { elements in
                body(unsafe (elements + index).pointee)
            }
        }
        guard let index = _inlineIndex(of: key) else { return nil }
        return body(unsafe _inlineReadPointerToValue(at: index).pointee)
    }

    /// Accesses the value at the given index via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(atIndex index: Int, _ body: (borrowing Value) -> R) -> R {
        precondition(index >= 0 && index < count, "Index out of bounds")
        if let heapValues = _heapValues {
            return unsafe heapValues.withUnsafeMutablePointerToElements { elements in
                body(unsafe (elements + index).pointee)
            }
        }
        return body(unsafe _inlineReadPointerToValue(at: index).pointee)
    }
}

// Note: Small is unconditionally ~Copyable (has deinit), cannot conform to Equatable/Hashable
// which require Copyable. Use isEqual(to:) method instead if needed.
