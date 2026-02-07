// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MultiChainKit",
    platforms: [
        .iOS(.v14),
        .macOS(.v12)
    ],
    products: [
        // Full SDK with all chains
        .library(
            name: "MultiChainKit",
            targets: ["MultiChainKit"]
        ),
        // Individual chain modules for selective import
        .library(
            name: "EthereumKit",
            targets: ["EthereumKit"]
        ),
        .library(
            name: "StarknetKit",
            targets: ["StarknetKit"]
        ),
        // Core module only (for building custom implementations)
        .library(
            name: "MultiChainCore",
            targets: ["MultiChainCore"]
        )
    ],
    dependencies: [
        // Large integer arithmetic
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.4.0"),
        // Cryptographic functions (Keccak, PBKDF2, etc.)
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.9.0"),
        // secp256k1 elliptic curve for Ethereum
        .package(url: "https://github.com/GigaBitcoin/secp256k1.swift.git", from: "0.21.1")
    ],
    targets: [
        // MARK: - Core Module
        .target(
            name: "MultiChainCore",
            dependencies: [
                "BigInt",
                "CryptoSwift"
            ],
            path: "Sources/MultiChainCore"
        ),

        // MARK: - Ethereum Module
        .target(
            name: "EthereumKit",
            dependencies: [
                "MultiChainCore",
                "BigInt",
                .product(name: "P256K", package: "secp256k1.swift")
            ],
            path: "Sources/EthereumKit"
        ),

        // MARK: - Starknet Module
        .target(
            name: "StarknetKit",
            dependencies: [
                "MultiChainCore",
                "BigInt",
                "CryptoSwift",
            ],
            path: "Sources/StarknetKit"
        ),

        // MARK: - Unified Entry Point
        .target(
            name: "MultiChainKit",
            dependencies: [
                "MultiChainCore",
                "EthereumKit",
                "StarknetKit"
            ],
            path: "Sources/MultiChainKit"
        ),

        // MARK: - Tests
        .testTarget(
            name: "MultiChainCoreTests",
            dependencies: ["MultiChainCore"],
            path: "Tests/MultiChainCoreTests"
        ),
        .testTarget(
            name: "EthereumKitTests",
            dependencies: ["EthereumKit"],
            path: "Tests/EthereumKitTests"
        ),
        .testTarget(
            name: "StarknetKitTests",
            dependencies: ["StarknetKit"],
            path: "Tests/StarknetKitTests"
        ),
        .testTarget(
            name: "MultiChainKitTests",
            dependencies: ["MultiChainKit"],
            path: "Tests/MultiChainKitTests"
        )
    ]
)
