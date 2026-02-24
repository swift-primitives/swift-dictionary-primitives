import Testing
@testable import Dictionary_Primitives
import Index_Primitives_Test_Support
import Identity_Primitives_Test_Support

@Suite struct GrowthDebug {
    @Test("growth 34") func g34() {
        var dict = Dictionary<String, Int>()
        for i in 0..<34 { dict.set("key\(i)", i) }
        #expect(dict.count == 34)
    }
    @Test("growth 35") func g35() {
        var dict = Dictionary<String, Int>()
        for i in 0..<35 { dict.set("key\(i)", i) }
        #expect(dict.count == 35)
    }
}
