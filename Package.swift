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
        )
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
        // Internal: Core types with ~Copyable support (no Sequence/Collection conformances)
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
        // Variant: Swift.Sequence/Collection for Dictionary.Ordered (Value: Copyable)
        .target(
            name: "Dictionary Ordered Primitives",
            dependencies: [
                "Dictionary Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),
        // Variant: Swift.Sequence/Collection for Dictionary.Ordered.Bounded (Value: Copyable)
        .target(
            name: "Dictionary Bounded Primitives",
            dependencies: [
                "Dictionary Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        // Variant: Swift.Sequence, Drain, Subscript for Dictionary (Value: Copyable)
        .target(
            name: "Dictionary Slab Primitives",
            dependencies: [
                "Dictionary Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),
        // Public: Re-exports Core, Variants, and Sequence for users
        .target(
            name: "Dictionary Primitives",
            dependencies: [
                "Dictionary Primitives Core",
                "Dictionary Ordered Primitives",
                "Dictionary Bounded Primitives",
                "Dictionary Slab Primitives",
            ]
        ),
        .testTarget(
            name: "Dictionary Primitives Tests",
            dependencies: [
                "Dictionary Primitives",
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
                .product(name: "Identity Primitives Test Support", package: "swift-identity-primitives"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("RawLayout"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
