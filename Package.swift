// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AsyncStreamExperiment",
		platforms: [
			.macOS(.v26)
		],
    products: [
        .library(
            name: "AsyncStreamExperiment",
            targets: ["AsyncStreamExperiment"]
        ),
    ],
		dependencies: [
			.package(
				url: "https://github.com/apple/swift-collections.git",
				.upToNextMinor(from: "1.4.0")
			)
		],
    targets: [
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
