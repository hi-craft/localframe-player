// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocalLibraryCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "LocalLibraryCore", targets: ["LocalLibraryCore"])],
    targets: [
        .target(name: "LocalLibraryCore"),
        .testTarget(name: "LocalLibraryCoreTests", dependencies: ["LocalLibraryCore"])
    ]
)
