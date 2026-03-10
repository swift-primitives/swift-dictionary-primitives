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

import Testing
@testable import Dictionary_Primitives

@Suite("Dictionary - Deinit")
struct DictionaryDeinitTests {

    final class Tracker: @unchecked Sendable {
        private var _storage: [Int] = []
        var count: Int { _storage.count }
        func append(_ id: Int) { _storage.append(id) }
    }

    struct TrackedValue: ~Copyable {
        let id: Int
        let tracker: Tracker
        init(_ id: Int, tracker: Tracker) { self.id = id; self.tracker = tracker }
        deinit { tracker.append(id) }
    }

    // MARK: - Dictionary.Ordered.Static

    @Test
    func `Static deinit destroys all values`() {
        let tracker = Tracker()
        do {
            var dict = Dictionary<String, TrackedValue>.Ordered.Static<8>()
            try! dict.set("a", TrackedValue(1, tracker: tracker))
            try! dict.set("b", TrackedValue(2, tracker: tracker))
            try! dict.set("c", TrackedValue(3, tracker: tracker))
        }
        #expect(tracker.count == 3)
    }

    @Test
    func `Static empty deinit does not crash`() {
        do {
            let _ = Dictionary<String, TrackedValue>.Ordered.Static<8>()
        }
    }

    // MARK: - Dictionary.Ordered.Small

    @Test
    func `Small deinit destroys all values in inline mode`() {
        let tracker = Tracker()
        do {
            var dict = Dictionary<String, TrackedValue>.Ordered.Small<4>()
            dict.set("a", TrackedValue(1, tracker: tracker))
            dict.set("b", TrackedValue(2, tracker: tracker))
            dict.set("c", TrackedValue(3, tracker: tracker))
        }
        #expect(tracker.count == 3)
    }

    @Test
    func `Small deinit destroys all values after spill`() {
        let tracker = Tracker()
        do {
            var dict = Dictionary<String, TrackedValue>.Ordered.Small<2>()
            dict.set("a", TrackedValue(1, tracker: tracker))
            dict.set("b", TrackedValue(2, tracker: tracker))
            // This triggers spill to heap
            dict.set("c", TrackedValue(3, tracker: tracker))
            dict.set("d", TrackedValue(4, tracker: tracker))
        }
        #expect(tracker.count == 4)
    }

    @Test
    func `Small empty deinit does not crash`() {
        do {
            let _ = Dictionary<String, TrackedValue>.Ordered.Small<4>()
        }
    }
}
