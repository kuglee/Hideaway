// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "Hideaway",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "App", targets: ["App"]),
    .library(name: "AppFeature", targets: ["AppFeature"]),
    .library(name: "Defaults", targets: ["Defaults"]),
    .library(name: "MenuBarSettingsManager", targets: ["MenuBarSettingsManager"]),
    .library(name: "MenuBarState", targets: ["MenuBarState"]),
    .library(name: "Notification", targets: ["Notifications"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/pointfreeco/swift-composable-architecture",
      branch: "protocol-beta"
    ),
  ],
  targets: [
    .target(
      name: "App",
      dependencies: [
        "AppFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "MenuBarSettingsManager",
      ]
    ),
    .target(
      name: "AppFeature",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "MenuBarSettingsManager",
        "MenuBarState",
        "Notifications",
      ]
    ),
    .target(
      name: "Defaults",
      dependencies: []
    ),
    .target(
      name: "MenuBarSettingsManager",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "Defaults",
        "MenuBarState",
      ]
    ),
    .target(
      name: "MenuBarState",
      dependencies: []
    ),
    .target(
      name: "Notifications",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "AppFeatureTests",
      dependencies: [
        "AppFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "MenuBarSettingsManager",
        "MenuBarState",
      ]
    ),
  ]
)
