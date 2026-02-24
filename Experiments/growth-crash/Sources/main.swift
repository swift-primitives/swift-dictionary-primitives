import Dictionary_Primitives

#if canImport(Darwin)
import Darwin
#endif

func log(_ msg: String) {
    var msg = msg + "\n"
    msg.withUTF8 { buf in
        _ = unsafe write(2, buf.baseAddress, buf.count)
    }
}

// The direct Buffer.Slab test passes at slot 33 with capacity 36.
// The Dictionary path crashes. So the bug is in Dictionary.set(), not Buffer.Slab.
// Trace BOTH _keys and _values to find which bitmap fails.

func experiment() {
    var dict = Dictionary<String, Int>()

    log("=== Dictionary growth trace (keys + values) ===")

    for i in 0..<40 {
        let keysCap = dict._keys.capacity
        let keysOcc = dict._keys.occupancy
        let keysFull = dict._keys.isFull
        let valsCap = dict._values.capacity
        let valsOcc = dict._values.occupancy
        let valsFull = dict._values.isFull

        if keysFull || keysOcc >= Index<Bit>.Count(Cardinal(30)) {
            log("[\(i)] keys: cap=\(keysCap) occ=\(keysOcc) full=\(keysFull)")
            log("[\(i)] vals: cap=\(valsCap) occ=\(valsOcc) full=\(valsFull)")

            let keysVacant = dict._keys.firstVacant()
            let valsVacant = dict._values.firstVacant()
            log("[\(i)] keysVacant=\(String(describing: keysVacant)) valsVacant=\(String(describing: valsVacant))")

            // Probe keys bitmap at the vacant slot
            if let kv = keysVacant {
                let kocc = dict._keys.isOccupied(at: kv)
                log("[\(i)] keys.isOccupied(at: \(kv)) = \(kocc)")
            }
            // Probe values bitmap at the KEYS vacant slot
            if let kv = keysVacant {
                log("[\(i)] probing vals.isOccupied(at: keys_vacant=\(kv))...")
                let vocc = dict._values.isOccupied(at: kv)
                log("[\(i)] vals.isOccupied(at: \(kv)) = \(vocc)")
            }
        }

        log("[\(i)] calling set...")
        dict.set("key\(i)", i)
        log("[\(i)] set done")

        if keysFull {
            log("[\(i)] >>> GREW: keys \(keysCap)→\(dict._keys.capacity) vals \(valsCap)→\(dict._values.capacity)")
        }
    }

    log("PASSED")
}

experiment()
