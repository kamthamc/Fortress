// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Fortress",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
        .macCatalyst("26.0")
    ],
    products: [
        // We define a library target first, which can be imported into the Xcode app target.
        // We also define an executable/app product if needed, but since Xcode works best with
        // a standard library or local package format, defining a library here is standard
        // for modular SwiftUI codebases. We'll also provide a project file.
        .library(
            name: "Fortress",
            targets: ["Fortress"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Fortress",
            dependencies: [],
            exclude: ["Fortress.entitlements", "FortressApp.swift"],
            resources: []
        ),
        .testTarget(
            name: "FortressTests",
            dependencies: ["Fortress"]
        ),
    ]
)
