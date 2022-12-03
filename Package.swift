// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "Hideaway",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "App", targets: ["App"]),
    .library(name: "AppFeature", targets: ["AppFeature"]),
    .library(name: "AppMenuBarSaveState", targets: ["AppMenuBarSaveState"]),
    .library(name: "AppList", targets: ["AppList"]),
    .library(name: "AppListItem", targets: ["AppListItem"]),
    .library(name: "Defaults", targets: ["Defaults"]),
    .library(name: "MenuBarSettingsManager", targets: ["MenuBarSettingsManager"]),
    .library(name: "MenuBarState", targets: ["MenuBarState"]),
    .library(name: "Notification", targets: ["Notifications"]),
    .library(name: "SettingsFeature", targets: ["SettingsFeature"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/pointfreeco/swift-composable-architecture",
      from: "0.41.2"
    ),
  ],
  targets: [
    .target(
      name: "App",
      dependencies: [
        "AppFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "MenuBarSettingsManager",
        "SettingsFeature",
      ]
    ),
    .target(
      name: "AppFeature",
      dependencies: [
        "AppMenuBarSaveState",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "MenuBarSettingsManager",
        "MenuBarState",
        "Notifications",
      ]
    ),
    .target(
      name: "AppMenuBarSaveState",
      dependencies: [
        "MenuBarState",
      ]
    ),
    .target(
      name: "AppList",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "AppListItem",
        "AppMenuBarSaveState",
      ]
    ),
    .target(
      name: "AppListItem",
      dependencies: [
        "AppMenuBarSaveState",
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
    .target(
      name: "SettingsFeature",
      dependencies: [
        "AppList",
        "AppListItem",
        "AppMenuBarSaveState",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "MenuBarSettingsManager",
        "MenuBarState",
        "Notifications",
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
    .testTarget(
      name: "AppListItemTests",
      dependencies: [
        "AppListItem",
        "AppMenuBarSaveState",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "MenuBarSettingsManager",
        "MenuBarState",
        "Notifications",
      ]
    ),
    .testTarget(
      name: "AppListTests",
      dependencies: [
        "AppList",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "SettingsFeatureTests",
      dependencies: [
        "SettingsFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
  ]
)
