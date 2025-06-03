import CompilerPluginSupport

// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "Quark",
    platforms: [
        .iOS("16.4"),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Quark",
            targets: ["Quark"]
        ),
        .library(
            name: "QuarkTesting",
            targets: ["QuarkTesting"]
        ),
        .plugin(
            name: "QuarkTestsPlugin",
            targets: ["QuarkTestsPlugin"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            from: "1.18.4"
        ),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "601.0.1"),
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.10.1")
    ],
    targets: [
        .target(
            name: "Quark",
            dependencies: [
                .target(name: "QuarkMacros"),
            ]
        ),
        .target(
            name: "QuarkTesting",
            dependencies: [
                .target(name: "Quark"),
                .product(name: "ViewInspector", package: "ViewInspector"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ]
        ),
        .macro(
            name: "QuarkMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .plugin(
            name: "QuarkTestsPlugin",
            capability: .buildTool()
        )
    ]
)
