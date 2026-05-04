import Index_Primitives_Test_Support
import Tagged_Primitives_Test_Support
import Testing

@testable import Dictionary_Primitives

// MARK: - Dictionary Conditional Copyable Tests
//
// Dictionary (unordered) is conditionally Copyable when Value: Copyable.
// Uses REFERENCE SEMANTICS — copies share Storage.Slab (class). Headers (struct)
// are independent value copies. No Copy-on-Write is implemented.
//
// These tests verify:
// 1. Copyable conformance compiles and produces valid copies
// 2. ARC lifetime management is correct (no double-free)
// 3. Iterator captures independent snapshot for safe iteration
// 4. Swift.Sequence conformance works through copies

@Suite("Dictionary Conditional Copyable")
struct DictionaryCopyableTests {

    // MARK: - Conformance

    @Test
    func `Dictionary is Copyable when Value is Copyable`() {
        var dict = [String: Int]()
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
        let dict = [String: Int]()
        let copy = dict
        #expect(copy.isEmpty == true)
        #expect(copy.count == .zero)
    }

    @Test
    func `copy reads values via subscript`() {
        var dict = [String: Int]()
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
        var dict = [String: Int]()
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
        var dict = [String: Int]()
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
        var dict = [String: Int]()
        dict.set("a", 1)
        dict.set("b", 2)
        dict.clear(keepingCapacity: true)

        let copy = dict
        #expect(copy.isEmpty == true)
        #expect(copy.count == .zero)
    }

    @Test
    func `copy after drain is empty`() {
        var dict = [String: Int]()
        dict.set("a", 1)
        dict.set("b", 2)
        dict.drain { _ in }

        let copy = dict
        #expect(copy.isEmpty == true)
    }

    // MARK: - ARC Safety

    @Test
    func `dropping original does not invalidate copy`() {
        var original: [String: Int]? = [String: Int]()
        original!.set("a", 1)
        original!.set("b", 2)

        let copy = original!
        original = nil
        // Original dropped — Storage.Slab alive via copy's ARC reference
        #expect(copy.count == 2)
        #expect(copy.contains("a") == true)
        #expect(copy.contains("b") == true)
    }

    @Test
    func `dropping both original and copy does not double-free`() {
        var original: [String: Int]? = [String: Int]()
        original!.set("a", 1)
        original!.set("b", 2)

        var copy: [String: Int]? = original
        original = nil
        #expect(copy!.count == 2)
        copy = nil
        // No crash = ARC correctly manages Storage.Slab lifetime
    }

    @Test
    func `multiple copies share storage safely`() {
        var dict = [String: Int]()
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
        var dict = [String: Int]()
        dict.set("a", 1)
        dict.set("b", 2)
        dict.set("c", 3)

        let copy = dict
        var keys: [String] = []
        for (key, _) in copy {
            keys.append(key)
        }
        #expect(keys.sorted() == ["a", "b", "c"])
    }

    @Test
    func `iterator captures snapshot independent of mutations`() {
        var dict = [String: Int]()
        dict.set("a", 1)
        dict.set("b", 2)

        // Iterator copies slab storage at creation (Dictionary Copyable.swift:40)
        var iter = dict.makeIterator()

        // Mutate after iterator creation
        dict.set("c", 3)
        _ = dict.remove("a")

        // Iterator sees snapshot from creation time
        var iterKeys: [String] = []
        while let pair = iter.next() {
            iterKeys.append(pair.key)
        }
        #expect(iterKeys.sorted() == ["a", "b"])
    }

    @Test
    func `for-in after growth works`() {
        var dict = [String: Int]()
        for i in 0..<50 {
            dict.set("k\(i)", i)
        }

        var count = 0
        for (key, value) in dict {
            #expect(key.hasPrefix("k"))
            #expect(value >= 0 && value < 50)
            count += 1
        }
        #expect(count == 50)
    }
}
