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

// Umbrella per [MOD-005]. Re-export the in-package targets so a single
// `import Dictionary_Primitives` surfaces the whole package.
//
// NB: the pre-tranche `Dictionary Primitives Core` / `Dictionary Slab Primitives`
// targets are RETIRED (ADT-families leg 8, 2026-06-10) — the two-Slab-planes
// dictionary is replaced by the column-generic `Dictionary<S>` over
// `Hash.Indexed` with key-projected `Hash.Entry` elements. The column packages
// are ordinary dependencies, never re-exported (zero cross-package re-exports).

@_exported public import Dictionary_Primitive
