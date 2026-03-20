// swift-tools-version: 6.2

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
            name: "Dictionary Primitives Test Support",
            targets: ["Dictionary Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-set-primitives"),
        .package(path: "../swift-hash-table-primitives"),
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-identity-primitives"),
        .package(path: "../swift-collection-primitives"),
        .package(path: "../swift-input-primitives"),
        .package(path: "../swift-sequence-primitives"),
        .package(path: "../swift-property-primitives"),
        .package(path: "../swift-buffer-primitives"),
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
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Slab Primitives", package: "swift-buffer-primitives"),
            ]
        ),

        // MARK: - Ordered
        .target(
            name: "Dictionary Ordered Primitives",
            dependencies: [
                "Dictionary Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),

        // MARK: - Bounded
        .target(
            name: "Dictionary Bounded Primitives",
            dependencies: [
                "Dictionary Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),

        // MARK: - Slab
        .target(
            name: "Dictionary Slab Primitives",
            dependencies: [
                "Dictionary Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),

        // MARK: - Umbrella
        .target(
            name: "Dictionary Primitives",
            dependencies: [
                "Dictionary Primitives Core",
                "Dictionary Ordered Primitives",
                "Dictionary Bounded Primitives",
                "Dictionary Slab Primitives",
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "Dictionary Primitives Tests",
            dependencies: [
                "Dictionary Primitives",
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
                .product(name: "Identity Primitives Test Support", package: "swift-identity-primitives"),
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
                .product(name: "Identity Primitives Test Support", package: "swift-identity-primitives"),
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
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("RawLayout"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
