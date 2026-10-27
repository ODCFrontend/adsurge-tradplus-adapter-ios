// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "AdSurgeADNAdapterForTradPlus",
  platforms: [
    .iOS(.v13)
  ],
  products: [
    .library(
      name: "AdSurgeADNAdapterForTradPlus",
      targets: ["AdSurgeADNAdapterForTradPlus"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/ODCFrontend/adsurge-adn-ios.git", exact: "2.0.1"),
    .package(url: "https://github.com/tradplus/TradPlusAdSDK-SPM.git", "13.7.0"..<"99.0.0"),
  ],
  targets: [
    .target(
      name: "AdSurgeADNAdapterForTradPlus",
      dependencies: [
        .product(name: "AdSurgeSDK", package: "adsurge-adn-ios"),
        .product(name: "TradPlusAdSDK", package: "TradPlusAdSDK-SPM"),
      ],
      path: "AdSurgeADNAdapterForTradPlus",
      publicHeadersPath: "."
    )
  ]
)
