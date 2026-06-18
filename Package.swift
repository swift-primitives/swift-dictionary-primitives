// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "swift-dictionary-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        // MARK: - Base type
        .library(
            name: "Dictionary Primitive",
            targets: ["Dictionary Primitive"]
        ),

        // MARK: - Umbrella
        .library(
            name: "Dictionary Primitives",
            targets: ["Dictionary Primitives"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-hash-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-hash-table-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-shared-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-linear-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-heap-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-allocation-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ordinal-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-tagged-primitives.git", branch: "main"),
        // NOTE: the iteration concern (swift-iterator-primitives), the Slab plane
        // (swift-buffer-slab-primitives), and the old Core/Slab support deps are NOT
        // dependencies — they retired with the two-planes shape (ADT-families leg 8).
        // The keyed core is iteration-free; `forEach` rides the dense plane.
    ],
    targets: [

        // MARK: - Base type (struct Dictionary<S>: the ADT over the ordered hashed
        // entry column + the key-projected `Hash.Entry` element vocabulary)
        .target(
            name: "Dictionary Primitive",
            dependencies: [
                .product(name: "Hash Indexed Primitive", package: "swift-hash-table-primitives"),
                .product(name: "Hash Table Primitive", package: "swift-hash-table-primitives"),
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
                .product(name: "Shared Primitive", package: "swift-shared-primitives"),
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                .product(name: "Storage Primitive", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),

        // MARK: - Umbrella (the pinned keyed surface + counts; re-exports the base)
        .target(
            name: "Dictionary Primitives",
            dependencies: [
                "Dictionary Primitive",
                .product(name: "Hash Indexed Primitive", package: "swift-hash-table-primitives"),
                .product(name: "Hash Table Primitive", package: "swift-hash-table-primitives"),
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
                .product(name: "Shared Primitive", package: "swift-shared-primitives"),
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                .product(name: "Storage Primitive", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "Dictionary Primitives Tests",
            dependencies: [
                "Dictionary Primitives",
                .product(name: "Hash Table Primitives Test Support", package: "swift-hash-table-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Hash Primitives Standard Library Integration", package: "swift-hash-primitives"),
                .product(name: "Tagged Primitives Standard Library Integration", package: "swift-tagged-primitives"),
                .product(name: "Ordinal Primitives Standard Library Integration", package: "swift-ordinal-primitives"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
