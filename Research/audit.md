# Audit: swift-dictionary-primitives

## Legacy — Consolidated 2026-04-08

### From: swift-institute/Research/audit-primitives.md (2026-04-03)

**Pre-publication dependency-tree audit — P0/P1/P2 checks**

#### P1: Multi-Type File [API-IMPL-005]

**File**: `Sources/Dictionary Primitives Core/Dictionary.Ordered.Error.swift` (3 types, 192 lines)

| Line | Type |
|------|------|
| 28 | `__DictionaryOrderedError<Key>` |
| 79 | `__DictionaryOrderedBoundedError<Key>` |
| 99 | `__DictionaryOrderedInlineError<Key>` |

**Assessment**: `__`-prefixed internal error enums hoisted to module scope for typed throws. Grouping is justified: related error types for variants of the same data structure sharing documentation context.

**Recommendation**: Accept as-is. The `__` prefix signals implementation infrastructure, not public API surface.

---

### From: swift-institute/Research/audits/implementation-naming-2026-03-20/swift-dictionary-primitives.md (2026-03-20)

**Implementation + naming audit**

HIGH=0, MEDIUM=22, LOW=10, INFO=8
Finding IDs: IMPL-002, IMPL-003, IMPL-010, IMPL-020, IMPL-021, IMPL-033, IMPL-050, IMPL-052, PATTERN-016, PATTERN-017
