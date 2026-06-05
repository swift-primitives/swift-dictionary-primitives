import Index_Primitives_Test_Support
import Tagged_Primitives_Test_Support
import Testing

@testable import Dictionary_Primitives

// MARK: - Dictionary Conditional Copyable Tests
//
// Dictionary (unordered) is conditionally Copyable when Value: Copyable.
// Copying SHARES storage: each plane (`_keys`, `_values`) is a
// `Buffer<Storage<…>.Contiguous<Memory.Heap<…>>>.Slab` whose internal `Box` is a reference-semantics
// class, so a copy shares those boxes until a mutation diverges them.
// Copy-on-Write IS implemented (see `Dictionary+CoW.swift`): each mutating op
// installs a private deep copy of the plane(s) it mutates BEFORE writing
// (`ensureUnique()`), so copies are observationally independent.
//
// These tests verify:
// 1. Copyable conformance compiles and produces valid copies
// 2. ARC lifetime management is correct (no double-free)
// 3. Iteration captures an independent snapshot for safe iteration
// 4. Iterable (forEach) iteration works through copies
// 5. Copy-on-Write divergence: mutating one side does not affect a copy,
//    per plane (keys / values) separately (see `Dictionary CoW Tests.swift`)

@Suite("Dictionary Conditional Copyable")
struct DictionaryCopyableTests {

    // MARK: - Conformance

    @Test
    func `Dictionary is Copyable when Value is Copyable`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict.set("b", 2)
        dict.set("c", 3)

        let copy = dict
        #expect(copy.count == 3)
        #expect(copy.contains("a") == true)
        #expect(copy.contains("b") == true)
        #expect(copy.contains("c") == true)
    }

    @Test
    func `empty Dictionary is Copyable`() {
        let dict = Dictionary<String, Int>()
        let copy = dict
        #expect(copy.isEmpty == true)
        #expect(copy.count == .zero)
    }

    @Test
    func `copy reads values via subscript`() {
        var dict = Dictionary<String, Int>()
        dict["x"] = 10
        dict["y"] = 20

        let copy = dict
        #expect(copy["x"] == 10)
        #expect(copy["y"] == 20)
        #expect(copy["z"] == nil)
    }

    // MARK: - Copy After Mutations

    @Test
    func `copy after insert-remove-update reads correct state`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict.set("b", 2)
        dict.set("c", 3)
        _ = dict.remove("b")
        dict.set("d", 4)
        dict.set("a", 99)

        let copy = dict
        #expect(copy.count == 3)
        #expect(copy.contains("a") == true)
        #expect(copy.contains("b") == false)
        #expect(copy.contains("c") == true)
        #expect(copy.contains("d") == true)
    }

    @Test
    func `copy after growth preserves all elements`() {
        var dict = Dictionary<String, Int>()
        for i in 0..<100 {
            dict.set("key\(i)", i)
        }

        let copy = dict
        #expect(copy.count == Index<String>.Count(Cardinal(100 as UInt)))
        for i in 0..<100 {
            #expect(copy.contains("key\(i)") == true)
        }
    }

    @Test
    func `copy after clear is empty`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict.set("b", 2)
        dict.clear(keepingCapacity: true)

        let copy = dict
        #expect(copy.isEmpty == true)
        #expect(copy.count == .zero)
    }

    @Test
    func `copy after drain is empty`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict.set("b", 2)
        dict.drain { _ in }

        let copy = dict
        #expect(copy.isEmpty == true)
    }

    // MARK: - ARC Safety

    @Test
    func `dropping original does not invalidate copy`() {
        var original: Dictionary<String, Int>? = Dictionary<String, Int>()
        original!.set("a", 1)
        original!.set("b", 2)

        let copy = original!
        original = nil
        // Original dropped — the Slab buffer's backing Box alive via copy's ARC reference
        #expect(copy.count == 2)
        #expect(copy.contains("a") == true)
        #expect(copy.contains("b") == true)
    }

    @Test
    func `dropping both original and copy does not double-free`() {
        var original: Dictionary<String, Int>? = Dictionary<String, Int>()
        original!.set("a", 1)
        original!.set("b", 2)

        var copy: Dictionary<String, Int>? = original
        original = nil
        #expect(copy!.count == 2)
        copy = nil
        // No crash = ARC correctly manages the Slab buffer's backing Box lifetime
    }

    @Test
    func `multiple copies share storage safely`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)

        let copy1 = dict
        let copy2 = dict
        let copy3 = copy1

        #expect(copy1.contains("a") == true)
        #expect(copy2.contains("a") == true)
        #expect(copy3.contains("a") == true)
    }

    // MARK: - Sequence on Copy

    @Test
    func `for-in on copy iterates all elements`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict.set("b", 2)
        dict.set("c", 3)

        let copy = dict
        var keys: [String] = []
        copy.forEach { key, _ in
            keys.append(key)
        }
        #expect(keys.sorted() == ["a", "b", "c"])
    }

    @Test
    func `iterator captures snapshot independent of mutations`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict.set("b", 2)

        // Materialise a snapshot via the `Iterable` floor before mutating.
        let snapshot = toArray(dict)

        // Mutate after the snapshot is taken
        dict.set("c", 3)
        _ = dict.remove("a")

        // Snapshot reflects the state at materialisation time, independent of mutations
        let iterKeys = snapshot.map(\.key)
        #expect(iterKeys.sorted() == ["a", "b"])
    }

    @Test
    func `for-in after growth works`() {
        var dict = Dictionary<String, Int>()
        for i in 0..<50 {
            dict.set("k\(i)", i)
        }

        var count = 0
        dict.forEach { key, value in
            #expect(key.hasPrefix("k"))
            #expect(value >= 0 && value < 50)
            count += 1
        }
        #expect(count == 50)
    }
}
