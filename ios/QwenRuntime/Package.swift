// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "QwenRuntime",
  platforms: [.iOS("16.4"), .macOS(.v14)],
  products: [.library(name: "QwenRuntime", targets: ["QwenRuntime"])],
  targets: [
    .binaryTarget(name: "llama",
      url: "https://github.com/ggml-org/llama.cpp/releases/download/b12633/llama-b12633-xcframework.zip",
      checksum: "d0b199082096fc63c875ef55c4675de09b3d42fa25a0b8d2dba736938c9c9bc6"),
    .target(name: "QwenRuntime", dependencies: ["llama"], resources: [.copy("Licenses")])
  ]
)
