import Dictionary_Primitives
import Hash_Table_Primitives_Test_Support
import Buffer_Primitives_Test_Support
import Hash_Table_Primitive
import Hash_Indexed_Primitive
import Hash_Primitives
import Hash_Primitives_Standard_Library_Integration
import Buffer_Primitive
import Buffer_Linear_Primitive
import Storage_Primitive
import Storage_Contiguous_Primitives
import Memory_Heap_Primitives
import Memory_Allocator_Primitive
import Shared_Primitive
import Index_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Ordinal_Primitives_Standard_Library_Integration
import Testing

// The column-keyed dictionary suite: the ordered hashed entry column direct +
// Shared-wrapped. Entries hash by KEY only (`Hash.Entry` is key-projected).

private typealias HeapStorage<E: ~Copyable> =
    Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>

private typealias EntryColumn<K: Hash.Key & ~Copyable, V: ~Copyable> =
    Hash.Indexed<Buffer<HeapStorage<Hash.Entry<K, V>>>.Linear>

private typealias MoveDictionary<K: Hash.Key & ~Copyable, V: ~Copyable> = Dictionary<EntryColumn<K, V>>
private typealias CoWDictionary<K: Hash.Key, V> = Dictionary<Shared<Hash.Entry<K, V>, EntryColumn<K, V>>>

// MARK: - [DS-024] + coherence (the Shared entry composite is this family's NEW column)

@Suite
struct DictionaryColumnLawTests {

    @Test
    func `the shared entry column obeys the seam ledger laws`() {
        let violations = Seam.Ledger.violations(
            makeEmpty: { Shared(EntryColumn<Int, Int>(minimumCapacity: Index<Hash.Entry<Int, Int>>.Count(4))) },
            element: { Hash.Entry(key: $0, value: $0) }
        )
        #expect(violations.isEmpty, "\(violations)")
    }

    @Test
    func `coherence holds through the dictionary surface`() {
        var direct = MoveDictionary<Int, Int>(minimumCapacity: 4)
        var i = 0
        while i < 16 {
            direct.insert(key: i &* 3, value: i)
            i += 1
        }
        _ = direct.removeValue(forKey: 9)
        _ = direct.removeValue(forKey: 0)
        direct.insert(key: 6, value: 99)         // replacement: value swaps behind a stable key
        let violations = direct.take().checkCoherence()
        #expect(violations.isEmpty, "\(violations)")
    }
}

extension Hash.Indexed<Buffer<HeapStorage<Hash.Entry<Int, Int>>>.Linear> {
    fileprivate borrowing func checkCoherence() -> [String] {
        Hash.Coherence.violations(self)
    }
}

// MARK: - Core keyed ops (the direct column)

@Suite(.serialized)
struct DictionaryCoreTests {

    @Test
    func `insert, displaced hand-back, contains, removeValue, counts`() {
        var d = MoveDictionary<Int, Int>(minimumCapacity: 4)
        let isEmpty = d.isEmpty
        #expect(isEmpty)
        let fresh = d.insert(key: 10, value: 100)
        #expect(fresh == nil)
        let displaced = d.insert(key: 10, value: 101)
        #expect(displaced == 100)
        d.insert(key: 20, value: 200)
        d.insert(key: 30, value: 300)
        let has = d.contains(key: 20), hasNot = d.contains(key: 40)
        #expect(has)
        #expect(!hasNot)
        let removed = d.removeValue(forKey: 20)
        #expect(removed == 200)
        let absent = d.removeValue(forKey: 20)
        #expect(absent == nil)
        let n = d.count
        #expect(n == Index<Hash.Entry<Int, Int>>.Count(2))
    }

    @Test
    func `withValue reads; withMutableValue mutates in place behind the stable key`() {
        var d = MoveDictionary<Int, Int>(minimumCapacity: 4)
        d.insert(key: 1, value: 10)
        let read = d.withValue(forKey: 1) { $0 }
        #expect(read == 10)
        let missing = d.withValue(forKey: 2) { $0 }
        #expect(missing == nil)
        let old = d.withMutableValue(forKey: 1) { value -> Int in
            let was = value
            value += 5
            return was
        }
        #expect(old == 10)
        let now = d.withValue(forKey: 1) { $0 }
        #expect(now == 15)
        let absent: Void? = d.withMutableValue(forKey: 9) { $0 += 1 }
        #expect(absent == nil)
    }

    @Test
    func `iteration is insertion-ordered across growth, removal, and replacement`() {
        var d = MoveDictionary<Int, Int>(minimumCapacity: 2)
        var i = 0
        while i < 12 {
            d.insert(key: i, value: i &* 10)
            i += 1
        }
        _ = d.removeValue(forKey: 5)
        d.insert(key: 3, value: 999)             // replacement keeps the slot's order
        var keys: [Int] = []
        d.forEach { key, _ in keys.append(key) }
        #expect(keys == [0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11])
        let replaced = d.withValue(forKey: 3) { $0 }
        #expect(replaced == 999)
    }

    @Test
    func `removeAll empties; reuse works; direct clone detaches`() {
        var d = MoveDictionary<Int, Int>(minimumCapacity: 4)
        d.insert(key: 1, value: 10)
        d.insert(key: 2, value: 20)
        var c = d.clone()
        _ = c.removeValue(forKey: 1)
        let mineHas = d.contains(key: 1), theirsHas = c.contains(key: 1)
        #expect(mineHas)
        #expect(!theirsHas)
        d.removeAll()
        let isEmpty = d.isEmpty
        #expect(isEmpty)
        d.insert(key: 7, value: 70)
        let v7 = d.withValue(forKey: 7) { $0 }
        #expect(v7 == 70)
    }
}

// MARK: - CoW value semantics (the Shared composite column)

@Suite(.serialized)
struct DictionaryCoWTests {

    @Test
    func `copies share until mutation; inserts detach through the box`() {
        var a = CoWDictionary<Int, Int>(minimumCapacity: 4)
        a.insert(key: 1, value: 10)
        let b = a                                // S5: Dictionary is Copyable because S is
        a.insert(key: 2, value: 20)              // withUnique(consuming:) detaches first
        let mine = a.count, theirs = b.count
        #expect(mine == Index<Hash.Entry<Int, Int>>.Count(2))
        #expect(theirs == Index<Hash.Entry<Int, Int>>.Count(1))
        let aHas2 = a.contains(key: 2), bHas2 = b.contains(key: 2)
        #expect(aHas2)
        #expect(!bHas2)
    }

    @Test
    func `value mutation detaches; the sibling keeps its value`() {
        var a = CoWDictionary<Int, Int>(minimumCapacity: 4)
        a.insert(key: 1, value: 10)
        let b = a
        _ = a.withMutableValue(forKey: 1) { $0 = 11 }
        let mine = a.withValue(forKey: 1) { $0 }, theirs = b.withValue(forKey: 1) { $0 }
        #expect(mine == 11)
        #expect(theirs == 10)
    }

    @Test
    func `removal detaches; the sibling keeps the entry; generic clone detaches`() {
        var a = CoWDictionary<Int, Int>(minimumCapacity: 4)
        a.insert(key: 1, value: 10)
        a.insert(key: 2, value: 20)
        let b = a
        let removed = a.removeValue(forKey: 1)
        #expect(removed == 10)
        let bStillHas = b.contains(key: 1)
        #expect(bStillHas)

        var c = a.clone()
        c.insert(key: 9, value: 90)
        let aHas9 = a.contains(key: 9), cHas9 = c.contains(key: 9)
        #expect(!aHas9)
        #expect(cHas9)
    }

    @Test
    func `removeAll detaches to a fresh box; the sibling is untouched`() {
        var a = CoWDictionary<Int, Int>(minimumCapacity: 4)
        a.insert(key: 1, value: 10)
        let b = a
        a.removeAll()
        let aEmpty = a.isEmpty, bHas = b.contains(key: 1)
        #expect(aEmpty)
        #expect(bHas)
    }
}

// MARK: - Move-only values + teardown

@Suite(.serialized)
struct DictionaryTeardownTests {

    @Test
    func `move-only values flow through and tear down exactly once`() {
        DictProbe.reset()
        do {
            var d = MoveDictionary<Int, DictItem>(minimumCapacity: 4)
            d.insert(key: 1, value: DictItem(10))
            d.insert(key: 2, value: DictItem(20))
            if let displaced: DictItem = d.insert(key: 1, value: DictItem(11)) {
                let id = displaced.id
                #expect(id == 10)                // the displaced OLD value hands back
            } else {
                Issue.record("expected the displaced value")
            }
            if let removed: DictItem = d.removeValue(forKey: 2) {
                let id = removed.id
                #expect(id == 20)
            } else {
                Issue.record("expected the removed value")
            }
        }
        let all = DictProbe.destroyedSorted
        #expect(all == [10, 11, 20])             // displaced + live-at-teardown + removed
    }

    @Test
    func `the boxed move-only lane tears down via the box drain`() {
        DictProbe2.reset()
        do {
            var d = Dictionary<Shared<Hash.Entry<Int, DictItem2>, EntryColumn<Int, DictItem2>>>(minimumCapacity: 4)
            d.insert(key: 7, value: DictItem2(70))
            d.insert(key: 8, value: DictItem2(80))
            let n = d.count
            #expect(n == Index<Hash.Entry<Int, DictItem2>>.Count(2))
        }
        let all = DictProbe2.destroyedSorted
        #expect(all == [70, 80])
    }
}

private struct DictItem: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { DictProbe.recordDestroy(id) }
}

private enum DictProbe {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}

private struct DictItem2: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { DictProbe2.recordDestroy(id) }
}

private enum DictProbe2 {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}

// MARK: - Sendable smoke

@Suite
struct DictionarySendableTests {

    @Test
    func `sendable composes through both columns`() {
        let a = MoveDictionary<Int, Int>(minimumCapacity: 1)
        requireSendable(a)
        let b = CoWDictionary<Int, Int>(minimumCapacity: 1)
        requireSendable(b)
        #expect(Bool(true))
    }
}

private func requireSendable<T: Sendable & ~Copyable>(_ value: borrowing T) {}
