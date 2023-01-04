// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "Hideaway",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "AppFeature", targets: ["AppFeature"]),
    .library(name: "AppMenuBarSaveState", targets: ["AppMenuBarSaveState"]),
    .library(name: "AppList", targets: ["AppList"]),
    .library(name: "AppListItem", targets: ["AppListItem"]),
    .library(name: "ComposableArchitectureExtra", targets: ["ComposableArchitectureExtra"]),
    .library(name: "Defaults", targets: ["Defaults"]),
    .library(name: "MenuBarExtraFeature", targets: ["MenuBarExtraFeature"]),
    .library(name: "MenuBarSettingsManager", targets: ["MenuBarSettingsManager"]),
    .library(name: "MenuBarState", targets: ["MenuBarState"]),
    .library(name: "Notification", targets: ["Notifications"]),
    .library(name: "SettingsFeature", targets: ["SettingsFeature"]),
    .library(name: "WelcomeFeature", targets: ["WelcomeFeature"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/pointfreeco/swift-composable-architecture",
      from: "0.41.2"
    ),
  ],
  targets: [
    .target(
      name: "AppFeature",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "ComposableArchitectureExtra",
        "MenuBarExtraFeature",
        "MenuBarSettingsManager",
        "MenuBarState",
        "Notifications",
        "SettingsFeature",
        "WelcomeFeature",
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
        "MenuBarSettingsManager",
        "Notifications",
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
      name: "ComposableArchitectureExtra",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "Defaults",
      dependencies: []
    ),
    .target(
      name: "MenuBarExtraFeature",
      dependencies: [
        "AppMenuBarSaveState",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "MenuBarSettingsManager",
        "MenuBarState",
        "Notifications",
      ]
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
        "AppMenuBarSaveState",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "ComposableArchitectureExtra",
        "MenuBarSettingsManager",
        "MenuBarState",
        "Notifications",
      ]
    ),
    .target(
      name: "WelcomeFeature",
      dependencies: []
    ),
    .testTarget(
      name: "AppFeatureTests",
      dependencies: [
        "AppFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "MenuBarState",
        "Notifications",
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
        "MenuBarSettingsManager",
      ]
    ),
    .testTarget(
      name: "MenuBarExtraFeatureTests",
      dependencies: [
        "MenuBarExtraFeature",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "MenuBarSettingsManager",
        "MenuBarState",
      ]
    ),
    .testTarget(
      name: "SettingsFeatureTests",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "SettingsFeature",
      ]
    ),
  ]
)
