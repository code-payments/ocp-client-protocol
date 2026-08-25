// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "ocp-client-protocol",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "OCPClientProtocol",
            targets: ["OCPClientProtocol"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.4.0"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "OCPClientProtocol",
            dependencies: [
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
            ]
        ),
    ]
)
