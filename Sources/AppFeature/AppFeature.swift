import ComposableArchitecture
import MenuBarSettingsManager
import MenuBarState
import Notifications
import SwiftUI
import XCTestDynamicOverlay
import os.log

public struct AppFeature: ReducerProtocol {
  @Dependency(\.appEnvironment) var environment
  @Dependency(\.menuBarSettingsManager) var menuBarSettingsManager
  @Dependency(\.notifications) var notifications

  public init() {}

  public struct State: Equatable {
    public var appMenuBarState: MenuBarState
    public var systemMenuBarState: SystemMenuBarState

    public init(
      appMenuBarState: MenuBarState = .systemDefault,
      systemMenuBarState: SystemMenuBarState = .inFullScreenOnly
    ) {
      self.appMenuBarState = appMenuBarState
      self.systemMenuBarState = systemMenuBarState
    }
  }

  public enum Action: Equatable {
    case appMenuBarStateSelected(state: MenuBarState)
    case gotAppMenuBarState(TaskResult<MenuBarState>)
    case didSaveAppMenuBarState(TaskResult<MenuBarState>)
    case systemMenuBarStateSelected(state: SystemMenuBarState)
    case gotSystemMenuBarState(SystemMenuBarState)
    case quitButtonPressed
    case fullScreenMenuBarVisibilityChangedNotification
    case menuBarHidingChangedNotification
    case didActivateApplication
    case didTerminateApplication(bundleIdentifier: String)
    case viewAppeared
    case task
    case settingsButtonPressed
  }

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case let .appMenuBarStateSelected(menuBarState):
        return .run { send in
          guard let appInfo = await self.menuBarSettingsManager.getBundleIdentifierOfCurrentApp()
          else { return }

          await send(
            .didSaveAppMenuBarState(
              TaskResult {
                try await self.menuBarSettingsManager.setAppMenuBarState(
                  menuBarState,
                  appInfo.bundleIdentifier
                )

                var appStates: [String: [String: String]] =
                  await self.menuBarSettingsManager.getAppMenuBarStates() ?? .init()

                appStates[appInfo.bundleIdentifier] = [
                  "bundlePath": appInfo.bundleURL.path(percentEncoded: true),
                  "state": menuBarState.stringValue,
                ]

                await self.menuBarSettingsManager.setAppMenuBarStates(appStates)

                return menuBarState
              }
            )
          )
        }
      case let .systemMenuBarStateSelected(menuBarState):
        let oldSystemMenuBarState = state.systemMenuBarState

        state.systemMenuBarState = menuBarState

        return .run { [state] send in
          await self.menuBarSettingsManager.setSystemMenuBarState(state.systemMenuBarState)

          if state.systemMenuBarState.rawValue.menuBarVisibleInFullScreen
            != oldSystemMenuBarState.rawValue.menuBarVisibleInFullScreen
          {
            await self.notifications.postFullScreenMenuBarVisibilityChanged()
          }

          if state.systemMenuBarState.rawValue.hideMenuBarOnDesktop
            != oldSystemMenuBarState.rawValue.hideMenuBarOnDesktop
          {
            await self.notifications.postMenuBarHidingChanged()
          }
        }
      case .quitButtonPressed:
        return .run { _ in
          if let appStates = await self.menuBarSettingsManager.getAppMenuBarStates() {
            var didSetState = false
            for bundleIdentifier in appStates.keys {
              let currentState = try await self.menuBarSettingsManager.getAppMenuBarState(
                bundleIdentifier
              )

              if currentState != .systemDefault {
                try await self.menuBarSettingsManager.setAppMenuBarState(
                  .systemDefault,
                  bundleIdentifier
                )

                if !didSetState { didSetState = true }
              }
            }

            if didSetState {
              await self.notifications.postFullScreenMenuBarVisibilityChanged()
              await self.notifications.postMenuBarHidingChanged()
            }
          }

          await self.environment.terminate()
        }
      case .fullScreenMenuBarVisibilityChangedNotification:
        return .run { send in
          let bundleIdentifier = await self.menuBarSettingsManager
            .getBundleIdentifierOfCurrentApp()?
            .bundleIdentifier

          await send(
            .gotAppMenuBarState(
              TaskResult {
                try await self.menuBarSettingsManager.getAppMenuBarState(bundleIdentifier)
              }
            )
          )
          await send(
            .gotSystemMenuBarState(await self.menuBarSettingsManager.getSystemMenuBarState())
          )
        }
      case .menuBarHidingChangedNotification:
        return .run { send in
          let bundleIdentifier = await self.menuBarSettingsManager
            .getBundleIdentifierOfCurrentApp()?
            .bundleIdentifier

          await send(
            .gotAppMenuBarState(
              TaskResult {
                try await self.menuBarSettingsManager.getAppMenuBarState(bundleIdentifier)
              }
            )
          )
          await send(
            .gotSystemMenuBarState(await self.menuBarSettingsManager.getSystemMenuBarState())
          )
        }
      case let .gotAppMenuBarState(.success(menuBarState)):
        state.appMenuBarState = menuBarState

        return .none
      case let .gotAppMenuBarState(.failure(error)):
        return .run { _ in await self.environment.log(error.localizedDescription) }
      case let .didSaveAppMenuBarState(.success(menuBarState)):
        let oldAppMenuBarState = state.appMenuBarState

        state.appMenuBarState = menuBarState

        return .run { [state] _ in
          if state.appMenuBarState.rawValue.menuBarVisibleInFullScreen
            != oldAppMenuBarState.rawValue.menuBarVisibleInFullScreen
          {
            await self.notifications.postFullScreenMenuBarVisibilityChanged()
          }

          if state.appMenuBarState.rawValue.hideMenuBarOnDesktop
            != oldAppMenuBarState.rawValue.hideMenuBarOnDesktop
          {
            await self.notifications.postMenuBarHidingChanged()
          }

          await self.notifications.postAppMenuBarStateChanged()
        }
      case let .didSaveAppMenuBarState(.failure(error)):
        return .run { _ in await self.environment.log(error.localizedDescription) }
      case let .gotSystemMenuBarState(menuBarState):
        state.systemMenuBarState = menuBarState

        return .none
      case .didActivateApplication:
        return .task {
          await .gotAppMenuBarState(
            TaskResult {
              let bundleIdentifier = await self.menuBarSettingsManager
                .getBundleIdentifierOfCurrentApp()?
                .bundleIdentifier

              let currentState = try await self.menuBarSettingsManager.getAppMenuBarState(
                bundleIdentifier
              )

              if let appStates = await self.menuBarSettingsManager.getAppMenuBarStates() {
                let stringState =
                  appStates[bundleIdentifier ?? ""]?["state"]
                  ?? MenuBarState.systemDefault.stringValue
                let state = MenuBarState(string: stringState)

                if state != currentState {
                  try await self.menuBarSettingsManager.setAppMenuBarState(state, bundleIdentifier)
                  await self.notifications.postFullScreenMenuBarVisibilityChanged()
                  await self.notifications.postMenuBarHidingChanged()

                  return state
                }
              }

              return currentState
            }
          )
        }
      case let .didTerminateApplication(bundleIdentifier):
        return .run { send in
          let currentState = try await self.menuBarSettingsManager.getAppMenuBarState(
            bundleIdentifier
          )

          if currentState != .systemDefault {
            try await self.menuBarSettingsManager.setAppMenuBarState(
              .systemDefault,
              bundleIdentifier
            )

            await self.notifications.postFullScreenMenuBarVisibilityChanged()
            await self.notifications.postMenuBarHidingChanged()
          }
        }

      case .viewAppeared:
        return .run { send in
          if let appStates = await self.menuBarSettingsManager.getAppMenuBarStates() {
            var didSetState = false
            for (bundleIdentifier, value) in appStates {
              if let stringState = value["state"] {
                let currentState = try await self.menuBarSettingsManager.getAppMenuBarState(
                  bundleIdentifier
                )
                let state = MenuBarState(string: stringState)

                if state != currentState {
                  try await self.menuBarSettingsManager.setAppMenuBarState(state, bundleIdentifier)

                  if !didSetState { didSetState = true }
                }
              }
            }

            if didSetState {
              await self.notifications.postFullScreenMenuBarVisibilityChanged()
              await self.notifications.postMenuBarHidingChanged()
            }
          }

          let bundleIdentifier = await self.menuBarSettingsManager
            .getBundleIdentifierOfCurrentApp()?
            .bundleIdentifier

          await send(
            .gotAppMenuBarState(
              TaskResult {
                try await self.menuBarSettingsManager.getAppMenuBarState(bundleIdentifier)
              }
            )
          )
          await send(
            .gotSystemMenuBarState(await self.menuBarSettingsManager.getSystemMenuBarState())
          )
        }
      case .task:
        return .run { send in
          await withTaskGroup(of: Void.self) { group in
            group.addTask {
              for await _ in await self.notifications.fullScreenMenuBarVisibilityChanged() {
                await send(.fullScreenMenuBarVisibilityChangedNotification)
              }
            }
            group.addTask {
              for await _ in await self.notifications.menuBarHidingChanged() {
                await send(.menuBarHidingChangedNotification)
              }
            }
            group.addTask {
              for await _ in await self.notifications.didActivateApplication() {
                await send(.didActivateApplication)
              }
            }
            group.addTask {
              for await bundleIdentifier in await self.notifications.didTerminateApplication() {
                if let bundleIdentifier {
                  await send(.didTerminateApplication(bundleIdentifier: bundleIdentifier))
                }
              }
            }
          }
        }
      case .settingsButtonPressed: return .run { _ in await self.environment.openSettings() }
      }
    }
  }
}

public enum AppFeatureEnvironmentKey: DependencyKey {
  public static let liveValue = AppFeatureEnvironment.live
  public static let testValue = AppFeatureEnvironment.unimplemented
}

extension DependencyValues {
  public var appEnvironment: AppFeatureEnvironment {
    get { self[AppFeatureEnvironmentKey.self] }
    set { self[AppFeatureEnvironmentKey.self] = newValue }
  }
}

public enum MenuBarSettingsManagerKey: DependencyKey {
  public static let liveValue = MenuBarSettingsManager.live
  public static let testValue = MenuBarSettingsManager.unimplemented
}

extension DependencyValues {
  public var menuBarSettingsManager: MenuBarSettingsManager {
    get { self[MenuBarSettingsManagerKey.self] }
    set { self[MenuBarSettingsManagerKey.self] = newValue }
  }
}

public enum NotificationsManagerKey: DependencyKey {
  public static let liveValue = Notifications.live
  public static let testValue = Notifications.unimplemented
}

extension DependencyValues {
  public var notifications: Notifications {
    get { self[NotificationsManagerKey.self] }
    set { self[NotificationsManagerKey.self] = newValue }
  }
}

public struct AppFeatureEnvironment {
  public var log: (String) async -> Void
  public var terminate: () async -> Void
  public var openSettings: () async -> Void
}

extension AppFeatureEnvironment {
  public static let live = Self(
    log: { message in os_log("%{public}@", message) },
    terminate: { await NSApplication.shared.terminate(nil) },
    openSettings: {
      _ = await NSApplication.shared.sendAction(
        Selector(("showSettingsWindow:")),
        to: nil,
        from: nil
      )
    }
  )
}

extension AppFeatureEnvironment {
  public static let unimplemented = Self(
    log: XCTUnimplemented("\(Self.self).log"),
    terminate: XCTUnimplemented("\(Self.self).terminate"),
    openSettings: XCTUnimplemented("\(Self.self).openSettings")
  )
}

public struct AppFeatureView: View {
  // WORKAROUND: onAppear and task are not being called when the view appears
  @MainActor class ForceOnAppear: ObservableObject { init() { Task { objectWillChange.send() } } }
  @StateObject var forceOnAppear = ForceOnAppear()

  let store: StoreOf<AppFeature>

  public init(store: StoreOf<AppFeature>) { self.store = store }

  public var body: some View {
    WithViewStore(store) { viewStore in
      VStack {
        Picker(
          selection: viewStore.binding(
            get: \.appMenuBarState,
            send: { .appMenuBarStateSelected(state: $0) }
          ),
          label: Text("Hide the menu bar in the current application")
        ) { ForEach(MenuBarState.allCases, id: \.self) { Text($0.label) } }
        Picker(
          selection: viewStore.binding(
            get: \.systemMenuBarState,
            send: { .systemMenuBarStateSelected(state: $0) }
          ),
          label: Text("Hide the menu bar system-wide")
        ) { ForEach(SystemMenuBarState.allCases, id: \.self) { Text($0.label) } }
        Button("Settings...") { viewStore.send(.settingsButtonPressed) }
        Divider()
        Button("Quit Hideaway") { viewStore.send(.quitButtonPressed) }
      }
      .pickerStyle(.inline).onAppear { viewStore.send(.viewAppeared) }
      .task { await viewStore.send(.task).finish() }
    }
  }
}
