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

// Dictionary Primitive declares the base type: the column-generic
// `struct Dictionary<S>` template plus its element vocabulary `Hash.Entry`
// (the key-projected pair). The pinned membership surface lives in the
// umbrella target's `Dictionary+Columns.swift`. No re-exports here — the
// column packages are ordinary dependencies ([MOD-005]: umbrellas re-export
// in-package targets only).
