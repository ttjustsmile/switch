// swift-tools-version: 5.9
import PackageDescription

// iOS 17 起步。用到的这几样都是 16.4~17 才有的：
// UnevenRoundedRectangle / presentationCornerRadius / scrollBounceBehavior
// / 双参数版 onChange(of:)。要往下兼容就把这几处各自换掉。
let package = Package(
    name: "Switch",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Switch", targets: ["Switch"])
    ],
    targets: [
        .target(name: "Switch", path: "Sources")
    ]
)
