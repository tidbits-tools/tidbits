// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NotesCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "NotesCore",
            targets: ["NotesCore"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NotesCore",
            dependencies: []),
        .testTarget(
            name: "NotesCoreTests",
            dependencies: ["NotesCore"]),
    ]
)
