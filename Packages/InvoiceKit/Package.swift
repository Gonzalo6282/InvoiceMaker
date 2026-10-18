// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InvoiceKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "InvoiceKit", targets: ["InvoiceKit"])
    ],
    targets: [
        .target(name: "InvoiceKit"),
        .testTarget(name: "InvoiceKitTests", dependencies: ["InvoiceKit"]),
    ]
)
