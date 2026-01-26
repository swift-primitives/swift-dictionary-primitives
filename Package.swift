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
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-collection-primitives"),
        .package(path: "../swift-input-primitives"),
        .package(path: "../swift-sequence-primitives"),
        .package(path: "../swift-property-primitives"),
    ],
    targets: [
        // Internal: Core types with ~Copyable support (no Sequence/Collection conformances)
        .target(
            name: "Dictionary Primitives Core",
            dependencies: [
                .product(name: "Set Primitives", package: "swift-set-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
            ]
        ),
        // Internal: Swift.Sequence.Protocol conformances (supports ~Copyable)
        // Separate module to avoid constraint poisoning on Core types
        .target(
            name: "Dictionary Primitives Sequence",
            dependencies: [
                "Dictionary Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),
        // Public: Re-exports Core and Sequence for users
        .target(
            name: "Dictionary Primitives",
            dependencies: [
                "Dictionary Primitives Core",
                "Dictionary Primitives Sequence",
            ]
        ),
        .testTarget(
            name: "Dictionary Primitives Tests",
            dependencies: ["Dictionary Primitives"]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety()
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
