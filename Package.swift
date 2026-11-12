// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "AdSurgeADNAdapterForTradPlus",
  platforms: [
    .iOS(.v12)
  ],
  products: [
    .library(
      name: "AdSurgeADNAdapterForTradPlus",
      targets: ["AdSurgeADNAdapterForTradPlusTarget"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/ODCFrontend/adsurge-adn-ios.git", exact: "2.0.2"),
    .package(url: "https://github.com/tradplus/TradPlusAdSDK-SPM.git", "13.7.0"..<"99.0.0"),
  ],
  targets: [
    .target(
      name: "AdSurgeADNAdapterForTradPlusTarget",
      dependencies: [
        .target(name: "AdSurgeADNAdapterForTradPlus"),
        .product(name: "AdSurgeSDK", package: "adsurge-adn-ios"),
        .product(name: "TradPlusAdSDK", package: "TradPlusAdSDK-SPM"),
      ],
      path: "AdSurgeADNAdapterForTradPlusTarget"
    ),
    .binaryTarget(
      name: "AdSurgeADNAdapterForTradPlus",
      url:
        "https://github.com/ODCFrontend/adsurge-tradplus-adapter-ios/releases/download/2.0.200/AdSurgeADNAdapterForTradPlus.zip",
      checksum: "0cb3632ae385bbb8322bf4ca61ab3ee808412018563145440147468f7ed60d52"
    ),
  ]
)
