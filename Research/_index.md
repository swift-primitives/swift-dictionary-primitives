# Research Index — swift-dictionary-primitives

| Document | Topic | Date | Status |
|----------|-------|------|--------|
| [cached-value-pointer-int-elimination](cached-value-pointer-int-elimination.md) | Eliminating `Int(bitPattern:)` at `_cachedValuePtr` access sites | 2026-02-10 | SUPERSEDED |
| [value-storage-buffer-layering](value-storage-buffer-layering.md) | Migrating value storage from raw `Storage<Value>` to `Buffer<Value>.Linear` variants | 2026-02-10 | RECOMMENDATION |
| [dictionary-discipline-boundary-analysis](dictionary-discipline-boundary-analysis.md) | Audit of what semantics belong solely to the dictionary layer vs lower layers | 2026-02-14 | RECOMMENDATION |
| [dictionary-operations-audit](dictionary-operations-audit.md) | Inventory of all public operations mapped against canonical Dictionary/Map ADT | 2026-02-16 | RECOMMENDATION |
| [dictionary-removal-strategies](dictionary-removal-strategies.md) | O(1) removal strategies: swap-remove, slab-backed, linked-backed | 2026-02-24 | RECOMMENDATION |
| [dictionary-growth-crash](dictionary-growth-crash.md) | Dictionary growth crash investigation | 2026-02-24 | DECISION |
| [audit.md](audit.md) | Pre-publication dependency-tree audit: multi-type error file (3 `__`-prefixed enums) | 2026-04-08 | LEGACY |
