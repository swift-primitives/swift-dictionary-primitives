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
        .library(
            name: "Dictionary Primitives",
            targets: ["Dictionary Primitives"]
        ),
        .library(
            name: "Dictionary Primitives Core",
            targets: ["Dictionary Primitives Core"]
        ),
        .library(
            name: "Dictionary Slab Primitives",
            targets: ["Dictionary Slab Primitives"]
        ),
        .library(
            name: "Dictionary Primitives Test Support",
            targets: ["Dictionary Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-set-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-hash-table-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-tagged-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-collection-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-input-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-sequence-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-property-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-slab-primitives.git", branch: "main"),
    ],
    targets: [

        // MARK: - Core
        .target(
            name: "Dictionary Primitives Core",
            dependencies: [
                .product(name: "Set Primitives", package: "swift-set-primitives"),
                .product(name: "Hash Table Primitives", package: "swift-hash-table-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Buffer Slab Primitive", package: "swift-buffer-slab-primitives"),
            ]
        ),

        // MARK: - Slab
        .target(
            name: "Dictionary Slab Primitives",
            dependencies: [
                "Dictionary Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Buffer Slab Primitive", package: "swift-buffer-slab-primitives"),
            ]
        ),

        // MARK: - Umbrella
        .target(
            name: "Dictionary Primitives",
            dependencies: [
                "Dictionary Primitives Core",
                "Dictionary Slab Primitives",
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "Dictionary Primitives Tests",
            dependencies: [
                "Dictionary Primitives",
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
                .product(name: "Tagged Primitives Test Support", package: "swift-tagged-primitives"),
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "Dictionary Primitives Test Support",
            dependencies: [
                "Dictionary Primitives",
                .product(name: "Set Primitives Test Support", package: "swift-set-primitives"),
                .product(name: "Hash Table Primitives Test Support", package: "swift-hash-table-primitives"),
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
                .product(name: "Tagged Primitives Test Support", package: "swift-tagged-primitives"),
                .product(name: "Collection Primitives Test Support", package: "swift-collection-primitives"),
                .product(name: "Input Primitives Test Support", package: "swift-input-primitives"),
                .product(name: "Sequence Primitives Test Support", package: "swift-sequence-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
            ],
            path: "Tests/Support"
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

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("RawLayout"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
