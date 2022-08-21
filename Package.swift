// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "Hideaway",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "App", targets: ["App"]),
    .library(name: "AppFeature", targets: ["AppFeature"]),
    .library(name: "DefaultDistributedNotificationCenter", targets: ["DefaultDistributedNotificationCenter"]),
    .library(name: "Defaults", targets: ["Defaults"]),
    .library(name: "MenuBarSettingsManager", targets: ["MenuBarSettingsManager"]),
    .library(name: "MenuBarState", targets: ["MenuBarState"]),
    .library(name: "SharedNSWorkspaceNotificationCenter", targets: ["SharedNSWorkspaceNotificationCenter"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/pointfreeco/swift-composable-architecture",
      from: "0.39.0"
    ),
  ],
  targets: [
    .target(
      name: "App",
      dependencies: [
        "AppFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "DefaultDistributedNotificationCenter",
        "MenuBarSettingsManager",
        "SharedNSWorkspaceNotificationCenter",
      ]
    ),
    .target(
      name: "AppFeature",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "DefaultDistributedNotificationCenter",
        "MenuBarSettingsManager",
        "SharedNSWorkspaceNotificationCenter",
      ]
    ),
    .target(
      name: "DefaultDistributedNotificationCenter",
      dependencies: []
    ),
    .target(
      name: "Defaults",
      dependencies: []
    ),
    .target(
      name: "MenuBarSettingsManager",
      dependencies: [
        "Defaults",
        "MenuBarState",
      ]
    ),
    .target(
      name: "MenuBarState",
      dependencies: []
    ),
    .target(
      name: "SharedNSWorkspaceNotificationCenter",
      dependencies: []
    ),
  ]
)
