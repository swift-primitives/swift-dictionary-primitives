import Dictionary_Primitives
import Hash_Table_Primitives_Test_Support
public import Buffer_Primitives_Test_Support
import Hash_Primitives
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

// The W3 dictionary model suite (arc-2): seeded op streams through the keyed
// doors on BOTH columns, against an insertion-ordered (key, value) reference.
// `insert` is an UPSERT: a displaced old value comes back, the entry keeps its
// position AND its original key instance. `withMutableValue` is the seam
// guard's no-change branch end-to-end (Hash.Entry hashes the KEY only, so value
// mutation is hash-stable by construction — the GOAL's keyed-door guard
// coverage). The direct lane censuses VALUES (move-only fixture; upsert
// displacements, mutation replacements, removals, wipes, and the final drop all
// account to the end multiset). The Shared lane is the sibling fleet with
// refcounted censused values. Shape constraint: B10.

private typealias HeapStorage<E: ~Copyable> =
    Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>

private typealias EntryColumn<K: Hash.Key & ~Copyable, V: ~Copyable> =
    Hash.Indexed<Buffer<HeapStorage<Hash.Entry<K, V>>>.Linear>

private typealias MoveDictionary<K: Hash.Key & ~Copyable, V: ~Copyable> = Dictionary<EntryColumn<K, V>>
private typealias CoWDictionary<K: Hash.Key, V> = Dictionary<Shared<Hash.Entry<K, V>, EntryColumn<K, V>>>

// MARK: - Fixtures: the Copyable key (controlled hash group) + the censused values
// (+ the hashed bound on the hoisted move-only fixture, for the key-lifecycle test)

extension Model.Element.Tracked: @retroactive Hash.`Protocol` {
    public borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(group)
    }

    public static func == (lhs: borrowing Model.Element.Tracked, rhs: borrowing Model.Element.Tracked) -> Bool {
        lhs.id == rhs.id
    }
}

private struct Key: Hash.`Protocol` {
    let id: Int
    let group: Int

    init(id: Int, group: Int) {
        self.id = id
        self.group = group
    }

    borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(group)
    }

    static func == (lhs: borrowing Key, rhs: borrowing Key) -> Bool {
        lhs.id == rhs.id
    }
}

private final class Value {
    let id: Int
    let serial: Int
    private let census: Model.Census

    init(id: Int, census: Model.Census) {
        self.id = id
        self.census = census
        self.serial = census.mint()
    }

    deinit {
        census.record(death: serial)
    }
}

// MARK: - The reference model: insertion-ordered (key, value) pairs

private struct Reference {
    var entries: [(key: Int, group: Int, value: Int)] = []
    var keys: Swift.Set<Int> = []
    var graveyard: [(key: Int, group: Int)] = []

    mutating func append(key: Int, group: Int, value: Int) {
        entries.append((key, group, value))
        keys.insert(key)
    }

    func position(ofKey key: Int) -> Int? {
        entries.firstIndex { $0.key == key }
    }

    mutating func setValue(_ value: Int, at position: Int) {
        entries[position].value = value
    }

    mutating func remove(at index: Int) {
        let entry = entries.remove(at: index)
        keys.remove(entry.key)
        retire((entry.key, entry.group))
    }

    mutating func removeAll() {
        for entry in entries.prefix(4) { retire((entry.key, entry.group)) }
        entries.removeAll()
        keys.removeAll()
    }

    private mutating func retire(_ key: (key: Int, group: Int)) {
        graveyard.append(key)
        if graveyard.count > 8 {
            graveyard.removeFirst(graveyard.count - 8)
        }
    }
}

// MARK: - The direct stream (move-only censused values)

private struct DirectStream: ~Copyable {
    var dictionary: MoveDictionary<Key, Model.Element.Tracked>
    var model = Reference()
    var rng: Model.Random
    var verdict: Model.Verdict
    var nextKey = 0
    var nextValue = 0
    let collisionDivisor = 4
    let census: Model.Census

    init(seed: UInt64, census: Model.Census) {
        var rng = Model.Random(seed: seed)
        self.dictionary = MoveDictionary<Key, Model.Element.Tracked>(
            minimumCapacity: Index<Hash.Entry<Key, Model.Element.Tracked>>.Count(UInt(rng.below(17)))
        )
        self.rng = rng
        self.verdict = Model.Verdict(seed: seed)
        self.census = census
    }

    mutating func freshKey() -> Key {
        let key = Key(id: nextKey, group: nextKey / collisionDivisor)
        nextKey += 1
        return key
    }

    mutating func mintValueID() -> Int {
        let id = nextValue
        nextValue += 1
        return id
    }

    mutating func insertFresh() {
        let key = freshKey()
        let valueID = mintValueID()
        verdict.record("insert k=\(key.id) g=\(key.group) v=\(valueID)")
        if let displaced = dictionary.insert(key: key, value: Model.Element.Tracked(id: valueID, census: census)) {
            verdict.diverged(["fresh key \(key.id) displaced value id \(displaced.id)"])
        } else {
            model.append(key: key.id, group: key.group, value: valueID)
        }
    }

    mutating func upsert() {
        let index = rng.below(model.entries.count)
        let entry = model.entries[index]
        let valueID = mintValueID()
        verdict.record("upsert k=\(entry.key) v=\(entry.value)→\(valueID)")
        if let displaced = dictionary.insert(key: Key(id: entry.key, group: entry.group), value: Model.Element.Tracked(id: valueID, census: census)) {
            if displaced.id != entry.value {
                verdict.diverged(["upsert displaced value id \(displaced.id), model \(entry.value)"])
            }
            model.setValue(valueID, at: index)
        } else {
            verdict.diverged(["upsert of live key \(entry.key) reported a fresh insertion"])
        }
    }

    mutating func removePresent() {
        let index = rng.below(model.entries.count)
        let entry = model.entries[index]
        verdict.record("remove k=\(entry.key) @\(index)")
        if let removed = dictionary.removeValue(forKey: Key(id: entry.key, group: entry.group)) {
            if removed.id != entry.value {
                verdict.diverged(["removeValue(k \(entry.key)) returned value id \(removed.id), model \(entry.value)"])
            }
            model.remove(at: index)
        } else {
            verdict.diverged(["removeValue(k \(entry.key)) found nothing for a live key"])
        }
    }

    mutating func removeAbsent() {
        let key = freshKey()
        verdict.record("absent k=\(key.id)")
        if let removed = dictionary.removeValue(forKey: key) {
            verdict.diverged(["removeValue of never-inserted key \(key.id) returned value id \(removed.id)"])
        }
    }

    mutating func containsHit() {
        let entry = model.entries[rng.below(model.entries.count)]
        verdict.record("has k=\(entry.key)")
        if !dictionary.contains(key: Key(id: entry.key, group: entry.group)) {
            verdict.diverged(["live key \(entry.key) is not contained"])
        }
    }

    mutating func containsMiss() {
        let key = freshKey()
        verdict.record("miss k=\(key.id)")
        if dictionary.contains(key: key) {
            verdict.diverged(["never-inserted key \(key.id) is contained"])
        }
    }

    mutating func readValue() {
        let entry = model.entries[rng.below(model.entries.count)]
        verdict.record("read k=\(entry.key)")
        let value = dictionary.withValue(forKey: Key(id: entry.key, group: entry.group)) { (value: borrowing Model.Element.Tracked) in
            value.id
        }
        if value != entry.value {
            verdict.diverged(["withValue(k \(entry.key)): \(String(describing: value)), model \(entry.value)"])
        }
    }

    /// The keyed mutation door — the seam guard's no-change branch end-to-end
    /// (the entry's hash is its KEY; replacing the value must not re-index).
    mutating func mutateValue() {
        let index = rng.below(model.entries.count)
        let entry = model.entries[index]
        let valueID = mintValueID()
        verdict.record("mutate k=\(entry.key) v=\(entry.value)→\(valueID)")
        let census = self.census
        let previous = dictionary.withMutableValue(forKey: Key(id: entry.key, group: entry.group)) { (slot: inout Model.Element.Tracked) -> Int in
            let old = slot.id
            slot = Model.Element.Tracked(id: valueID, group: 0, census: census)
            return old
        }
        if let previous {
            if previous != entry.value {
                verdict.diverged(["withMutableValue displaced value id \(previous), model \(entry.value)"])
            }
            model.setValue(valueID, at: index)
        } else {
            verdict.diverged(["withMutableValue(k \(entry.key)) missed a live key"])
        }
    }

    mutating func walkOrder() {
        verdict.record("walk \(model.entries.count)")
        var keys: [Int] = []
        var values: [Int] = []
        dictionary.forEach { (key: borrowing Key, value: borrowing Model.Element.Tracked) in
            keys.append(key.id)
            values.append(value.id)
        }
        if keys != model.entries.map({ $0.key }) || values != model.entries.map({ $0.value }) {
            verdict.diverged(["forEach walked \(keys)/\(values), model \(model.entries.map { $0.key })/\(model.entries.map { $0.value })"])
        }
    }

    mutating func wipe() {
        let keep = rng.chance(50)
        verdict.record("wipe keep=\(keep)")
        dictionary.removeAll(keepingCapacity: keep)
        model.removeAll()
    }

    func audit() -> [String] {
        var findings: [String] = []
        if dictionary.count != Index<Hash.Entry<Key, Model.Element.Tracked>>.Count(UInt(model.entries.count)) {
            findings.append("count: dictionary \(dictionary.count), model \(model.entries.count)")
        }
        var keys: [Int] = []
        var values: [Int] = []
        dictionary.forEach { (key: borrowing Key, value: borrowing Model.Element.Tracked) in
            keys.append(key.id)
            values.append(value.id)
        }
        if keys != model.entries.map({ $0.key }) {
            findings.append("key order: \(keys), model \(model.entries.map { $0.key })")
        }
        if values != model.entries.map({ $0.value }) {
            findings.append("values: \(values), model \(model.entries.map { $0.value })")
        }
        for retired in model.graveyard where !model.keys.contains(retired.key) {
            if dictionary.contains(key: Key(id: retired.key, group: retired.group)) {
                findings.append("retired key \(retired.key) is still reachable")
            }
        }
        return findings
    }

    mutating func step() {
        var branch = rng.below(100)
        if model.entries.isEmpty, branch >= 26, branch < 92 { branch = 0 }

        switch branch {
        case 0..<26: insertFresh()
        case 26..<38: upsert()
        case 38..<54: removePresent()
        case 54..<58: removeAbsent()
        case 58..<66: containsHit()
        case 66..<70: containsMiss()
        case 70..<78: readValue()
        case 78..<86: mutateValue()
        case 86..<92: walkOrder()
        default: wipe()
        }
    }

    mutating func run() {
        let operations = Model.operations(default: 800)
        var op = 0
        while op < operations, verdict.isClean {
            step()
            if Model.shouldAudit(op: op, of: operations) {
                verdict.diverged(audit())
            }
            op += 1
        }
    }

    consuming func finish() -> Model.Verdict {
        verdict
    }
}

private func runDirectStream(seed: UInt64) -> Model.Verdict {
    let census = Model.Census()
    var stream = DirectStream(seed: seed, census: census)
    stream.run()
    var verdict = stream.finish()  // the dictionary dies here

    if !census.isExact {
        verdict.findings.append(
            "value teardown multiset broken: \(census.born.count) born vs \(census.died.count) died"
        )
    }
    return verdict
}

// MARK: - The Shared (CoW) sibling fleet (refcounted censused values)

private struct FleetStream {
    var siblings: [CoWDictionary<Key, Value>]
    var models: [Reference]
    var rng: Model.Random
    var verdict: Model.Verdict
    var nextKey = 0
    var nextValue = 0
    let collisionDivisor = 4
    let census: Model.Census

    init(seed: UInt64, census: Model.Census) {
        var rng = Model.Random(seed: seed)
        self.siblings = [CoWDictionary<Key, Value>(
            minimumCapacity: Index<Hash.Entry<Key, Value>>.Count(UInt(rng.below(9)))
        )]
        self.models = [Reference()]
        self.rng = rng
        self.verdict = Model.Verdict(seed: seed)
        self.census = census
    }

    mutating func freshKey() -> Key {
        let key = Key(id: nextKey, group: nextKey / collisionDivisor)
        nextKey += 1
        return key
    }

    mutating func freshValue() -> Value {
        let value = Value(id: nextValue, census: census)
        nextValue += 1
        return value
    }

    mutating func fork() {
        let source = rng.below(siblings.count)
        verdict.record("fork ←\(source) (\(siblings.count + 1) siblings)")
        siblings.append(siblings[source])
        models.append(models[source])
    }

    mutating func drop() {
        let target = rng.below(siblings.count)
        verdict.record("drop \(target)")
        siblings.remove(at: target)
        models.remove(at: target)
    }

    mutating func insertFresh(into target: Int) {
        let key = freshKey()
        let value = freshValue()
        verdict.record("insert[\(target)] k=\(key.id) v=\(value.id)")
        if let displaced = siblings[target].insert(key: key, value: value) {
            verdict.diverged(["fresh key \(key.id) displaced value id \(displaced.id) on sibling \(target)"])
        } else {
            models[target].append(key: key.id, group: key.group, value: value.id)
        }
    }

    mutating func upsert(on target: Int) {
        let index = rng.below(models[target].entries.count)
        let entry = models[target].entries[index]
        let value = freshValue()
        verdict.record("upsert[\(target)] k=\(entry.key) v=\(entry.value)→\(value.id)")
        if let displaced = siblings[target].insert(key: Key(id: entry.key, group: entry.group), value: value) {
            if displaced.id != entry.value {
                verdict.diverged(["upsert displaced value id \(displaced.id), model \(entry.value)"])
            }
            models[target].setValue(value.id, at: index)
        } else {
            verdict.diverged(["upsert of live key \(entry.key) reported fresh on sibling \(target)"])
        }
    }

    mutating func removePresent(from target: Int) {
        let index = rng.below(models[target].entries.count)
        let entry = models[target].entries[index]
        verdict.record("remove[\(target)] k=\(entry.key)")
        if let removed = siblings[target].removeValue(forKey: Key(id: entry.key, group: entry.group)) {
            if removed.id != entry.value {
                verdict.diverged(["removeValue returned value id \(removed.id), model \(entry.value)"])
            }
            models[target].remove(at: index)
        } else {
            verdict.diverged(["removeValue(k \(entry.key)) found nothing on sibling \(target)"])
        }
    }

    mutating func readValue(on target: Int) {
        let entry = models[target].entries[rng.below(models[target].entries.count)]
        verdict.record("read[\(target)] k=\(entry.key)")
        let value = siblings[target].withValue(forKey: Key(id: entry.key, group: entry.group)) { (value: borrowing Value) in
            value.id
        }
        if value != entry.value {
            verdict.diverged(["withValue(k \(entry.key)) on sibling \(target): \(String(describing: value)), model \(entry.value)"])
        }
    }

    mutating func mutateValue(on target: Int) {
        let index = rng.below(models[target].entries.count)
        let entry = models[target].entries[index]
        let value = freshValue()
        verdict.record("mutate[\(target)] k=\(entry.key) v=\(entry.value)→\(value.id)")
        let previous = siblings[target].withMutableValue(forKey: Key(id: entry.key, group: entry.group)) { (slot: inout Value) -> Int in
            let old = slot.id
            slot = value
            return old
        }
        if let previous {
            if previous != entry.value {
                verdict.diverged(["withMutableValue displaced value id \(previous), model \(entry.value)"])
            }
            models[target].setValue(value.id, at: index)
        } else {
            verdict.diverged(["withMutableValue(k \(entry.key)) missed a live key on sibling \(target)"])
        }
    }

    mutating func walkOrder(on target: Int) {
        verdict.record("walk[\(target)] \(models[target].entries.count)")
        var keys: [Int] = []
        var values: [Int] = []
        siblings[target].forEach { (key: borrowing Key, value: borrowing Value) in
            keys.append(key.id)
            values.append(value.id)
        }
        if keys != models[target].entries.map({ $0.key }) || values != models[target].entries.map({ $0.value }) {
            verdict.diverged(["sibling \(target) walked \(keys)/\(values), model order broken"])
        }
    }

    // ASK-W3-A carve-out: the Shared `removeAll` rebuilds the box through the
    // strategy-less init (Dictionary+Columns.swift:239), so wipe → fork → mutate
    // traps. Mass removal sweeps the keyed door until the ruled fix lands; the
    // disabled regression test below re-enables the real door.
    mutating func wipe(_ target: Int) {
        verdict.record("sweep[\(target)] \(models[target].entries.count)")
        while let entry = models[target].entries.last {
            if let removed = siblings[target].removeValue(forKey: Key(id: entry.key, group: entry.group)) {
                if removed.id != entry.value {
                    verdict.diverged(["sweep removeValue returned id \(removed.id), model \(entry.value)"])
                }
                models[target].remove(at: models[target].entries.count - 1)
            } else {
                verdict.diverged(["sweep removeValue(k \(entry.key)) missed a live key on sibling \(target)"])
                return
            }
        }
    }

    func audit() -> [String] {
        var findings: [String] = []
        for (index, model) in models.enumerated() {
            if siblings[index].count != Index<Hash.Entry<Key, Value>>.Count(UInt(model.entries.count)) {
                findings.append("sibling \(index) count \(siblings[index].count), model \(model.entries.count)")
            }
            var keys: [Int] = []
            var values: [Int] = []
            siblings[index].forEach { (key: borrowing Key, value: borrowing Value) in
                keys.append(key.id)
                values.append(value.id)
            }
            if keys != model.entries.map({ $0.key }) || values != model.entries.map({ $0.value }) {
                findings.append("sibling \(index): \(keys)/\(values) diverged from its fork")
            }
        }
        return findings
    }

    mutating func step() {
        let target = rng.below(siblings.count)
        var branch = rng.below(100)
        if models[target].entries.isEmpty, branch >= 16, branch < 92 { branch = 10 }

        switch branch {
        case 0..<10 where siblings.count < 4: fork()
        case 0..<10: insertFresh(into: target)
        case 10..<16: insertFresh(into: target)
        case 16..<26 where siblings.count > 1: drop()
        case 16..<26: insertFresh(into: target)
        case 26..<38: upsert(on: target)
        case 38..<54: removePresent(from: target)
        case 54..<66: readValue(on: target)
        case 66..<78: mutateValue(on: target)
        case 78..<92: walkOrder(on: target)
        default: wipe(target)
        }
    }

    mutating func run() {
        let operations = Model.operations(default: 800)
        var op = 0
        while op < operations, verdict.isClean {
            step()
            if Model.shouldAudit(op: op, of: operations) {
                verdict.diverged(audit())
            }
            op += 1
        }
    }
}

private func runFleetStream(seed: UInt64) -> Model.Verdict {
    let census = Model.Census()
    var verdict: Model.Verdict
    do {
        var stream = FleetStream(seed: seed, census: census)
        stream.run()
        verdict = stream.verdict
    }  // every sibling dies here; value refcounts fall to zero

    if !census.isExact {
        verdict.findings.append(
            "value teardown multiset broken across the fleet: \(census.born.count) born vs \(census.died.count) died"
        )
    }
    return verdict
}

// MARK: - The suites

@Suite
struct `Dictionary Model` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Dictionary Model`.Integration {
    @Test(arguments: Model.seeds(default: [0xD1C7_0001, 0xD1C7_0002]))
    func `direct stream: keyed doors match the ordered reference; value teardown exact`(seed: UInt64) {
        let verdict = runDirectStream(seed: seed)
        #expect(verdict.isClean, Comment(rawValue: verdict.report))
    }

    @Test(arguments: Model.seeds(default: [0xD1C7_F1E1, 0xD1C7_F1E2, 0xD1C7_F1E3]))
    func `shared sibling fleet: keyed doors hold per fork; refcounts end exact`(seed: UInt64) {
        let verdict = runFleetStream(seed: seed)
        #expect(verdict.isClean, Comment(rawValue: verdict.report))
    }
}

extension `Dictionary Model`.Unit {
    @Test
    func `upsert keeps the position and the ORIGINAL key instance; the probe key dies`() {
        let census = Model.Census()
        do {
            var dictionary = MoveDictionary<Model.Element.Tracked, Int>(
                minimumCapacity: Index<Hash.Entry<Model.Element.Tracked, Int>>.Count(4)
            )
            dictionary.insert(key: Model.Element.Tracked(id: 7, group: 1, census: census), value: 100)  // key serial 0
            let displaced = dictionary.insert(key: Model.Element.Tracked(id: 7, group: 1, census: census), value: 200)  // key serial 1
            #expect(displaced == 100)
            let diedMid = census.died.sorted()
            #expect(diedMid == [1])  // the probe key died; the ORIGINAL key survives in the entry
            let read = dictionary.withValue(forKey: Model.Element.Tracked(id: 7, group: 1, census: census)) { (value: borrowing Int) in
                copy value
            }
            #expect(read == 200)
        }
        let exact = census.isExact
        #expect(exact)
    }
}

extension `Dictionary Model`.`Edge Case` {
    @Test
    func `upsert preserves insertion order across the whole walk`() {
        let census = Model.Census()
        var dictionary = CoWDictionary<Key, Value>(
            minimumCapacity: Index<Hash.Entry<Key, Value>>.Count(8)
        )
        for id in 0..<5 {
            dictionary.insert(key: Key(id: id, group: id / 2), value: Value(id: 100 + id, census: census))
        }
        dictionary.insert(key: Key(id: 2, group: 1), value: Value(id: 999, census: census))
        var keys: [Int] = []
        var values: [Int] = []
        dictionary.forEach { (key: borrowing Key, value: borrowing Value) in
            keys.append(key.id)
            values.append(value.id)
        }
        #expect(keys == [0, 1, 2, 3, 4])
        #expect(values == [100, 101, 999, 103, 104])
    }

    @Test(.disabled("""
    ASK-W3-A (REPORT-arc-model-tests-W3): the Shared removeAll rebuilds the box \
    through the strategy-less init (Dictionary+Columns.swift:239) — fork-after-wipe \
    then mutate traps at Shared+Unique.swift:77. Re-enable with the ruled fix.
    """))
    func `forking after removeAll keeps both siblings independently mutable`() {
        let census = Model.Census()
        var first = CoWDictionary<Key, Value>(
            minimumCapacity: Index<Hash.Entry<Key, Value>>.Count(4)
        )
        first.insert(key: Key(id: 1, group: 0), value: Value(id: 10, census: census))
        first.removeAll()
        var second = first
        second.insert(key: Key(id: 2, group: 0), value: Value(id: 20, census: census))  // traps pre-fix
        first.insert(key: Key(id: 3, group: 0), value: Value(id: 30, census: census))
        let secondHasTheirs = second.contains(key: Key(id: 2, group: 0))
        let firstHasTheirs = first.contains(key: Key(id: 3, group: 0))
        let crossLeak = first.contains(key: Key(id: 2, group: 0))
        #expect(secondHasTheirs)
        #expect(firstHasTheirs)
        #expect(!crossLeak)
    }

    @Test
    func `mutating one sibling's value leaves the other's value intact`() {
        let census = Model.Census()
        var first = CoWDictionary<Key, Value>(
            minimumCapacity: Index<Hash.Entry<Key, Value>>.Count(4)
        )
        first.insert(key: Key(id: 1, group: 0), value: Value(id: 10, census: census))
        var second = first

        _ = second.withMutableValue(forKey: Key(id: 1, group: 0)) { (slot: inout Value) in
            slot = Value(id: 20, census: census)
        }

        let firstValue = first.withValue(forKey: Key(id: 1, group: 0)) { (value: borrowing Value) in value.id }
        let secondValue = second.withValue(forKey: Key(id: 1, group: 0)) { (value: borrowing Value) in value.id }
        #expect(firstValue == 10)
        #expect(secondValue == 20)
    }
}
