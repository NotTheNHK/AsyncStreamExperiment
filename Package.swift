// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AsyncStreamExperiment",
		platforms: [
			.macOS(.v26)
		],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AsyncStreamExperiment",
            targets: ["AsyncStreamExperiment"]
        ),
    ],
		dependencies: [
			.package(
				url: "https://github.com/apple/swift-collections.git",
				.upToNextMinor(from: "1.3.0")
			)
		],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AsyncStreamExperiment",
						dependencies: [
							.product(name: "Collections", package: "swift-collections")
						]
        ),
        .testTarget(
            name: "AsyncStreamExperimentTests",
            dependencies: ["AsyncStreamExperiment"]
        ),
    ]
)
