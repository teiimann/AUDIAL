// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Dialito", platforms: [.macOS(.v13)], products: [.executable(name: "Dialito", targets: ["Dialito"])], targets: [.executableTarget(name: "Dialito")])
