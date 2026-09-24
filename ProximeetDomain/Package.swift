// swift-tools-version:5.9
import PackageDescription

// Pure-Swift, in-memory draft state for the Proximeet demo. No platform UI,
// networking or persistence. Strict concurrency checking is enabled for every target.
let strictConcurrency: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "ProximeetDomain",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "ProximeetDomain", targets: ["ProximeetDomain"]),
    ],
    targets: [
        .target(
            name: "ProximeetDomain",
            swiftSettings: strictConcurrency
        ),
        .testTarget(
            name: "ProximeetDomainTests",
            dependencies: ["ProximeetDomain"],
            swiftSettings: strictConcurrency
        ),
    ]
)
