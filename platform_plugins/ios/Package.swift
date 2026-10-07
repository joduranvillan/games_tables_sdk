// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenTableMultipeer",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "OpenTableMultipeer",
            type: .static,
            targets: ["OpenTableMultipeer"]
        )
    ],
    targets: [
        .target(
            name: "OpenTableMultipeer",
            path: ".",
            sources: [
                "OpenTableMultipeerPlugin.swift",
                "OpenTableMultipeerNetwork.swift",
                "OpenTableMultipeer.swift"
            ],
            linkerSettings: [
                .linkedFramework("MultipeerConnectivity"),
                .linkedFramework("Foundation")
            ]
        )
    ]
)
