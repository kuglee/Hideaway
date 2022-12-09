import ComposableArchitecture
import MenuBarSettingsManager
import MenuBarState
import Notifications
import SwiftUI
import XCTestDynamicOverlay
import os.log

public struct AppFeatureReducer: ReducerProtocol {
  @Dependency(\.appFeatureEnvironment) var environment
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
    case gotAppMenuBarState(MenuBarState)
    case didSaveAppMenuBarState(MenuBarState)
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
          guard
            let bundleIdentifier = await self.menuBarSettingsManager
              .getBundleIdentifierOfCurrentApp()
          else { return }

          try await self.menuBarSettingsManager.setAppMenuBarState(menuBarState, bundleIdentifier)

          var appStates: [String: String] =
            await self.menuBarSettingsManager.getAppMenuBarStates() ?? .init()

          appStates[bundleIdentifier] = menuBarState.stringValue

          await self.menuBarSettingsManager.setAppMenuBarStates(appStates)

          await send(.didSaveAppMenuBarState(menuBarState))
        } catch: { error, _ in
          await self.environment.log(error.localizedDescription)
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
          let bundleIdentifier = await self.menuBarSettingsManager.getBundleIdentifierOfCurrentApp()
          let menuBarState = try await self.menuBarSettingsManager.getAppMenuBarState(
            bundleIdentifier
          )
          await send(.gotAppMenuBarState(menuBarState))

          let systemMenuBarState = await self.menuBarSettingsManager.getSystemMenuBarState()
          await send(.gotSystemMenuBarState(systemMenuBarState))
        } catch: { error, _ in
          await self.environment.log(error.localizedDescription)
        }
      case .menuBarHidingChangedNotification:
        return .run { send in
          let bundleIdentifier = await self.menuBarSettingsManager.getBundleIdentifierOfCurrentApp()
          let menuBarState = try await self.menuBarSettingsManager.getAppMenuBarState(
            bundleIdentifier
          )
          await send(.gotAppMenuBarState(menuBarState))

          let systemMenuBarState = await self.menuBarSettingsManager.getSystemMenuBarState()
          await send(.gotSystemMenuBarState(systemMenuBarState))
        } catch: { error, _ in
          await self.environment.log(error.localizedDescription)
        }
      case let .gotAppMenuBarState(menuBarState):
        state.appMenuBarState = menuBarState
        return .none
      case let .didSaveAppMenuBarState(menuBarState):
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
      case let .gotSystemMenuBarState(menuBarState):
        state.systemMenuBarState = menuBarState

        return .none
      case .didActivateApplication:
        return .run { [state] send in
          let bundleIdentifier = await self.menuBarSettingsManager.getBundleIdentifierOfCurrentApp()
          let currentMenuBarState = try await self.menuBarSettingsManager.getAppMenuBarState(
            bundleIdentifier
          )

          if let appStates = await self.menuBarSettingsManager.getAppMenuBarStates() {
            let savedMenuBarStateString =
              appStates[bundleIdentifier ?? ""] ?? MenuBarState.systemDefault.stringValue
            let savedMenuBarState = MenuBarState(string: savedMenuBarStateString)

            if savedMenuBarState != currentMenuBarState {
              try await self.menuBarSettingsManager.setAppMenuBarState(
                savedMenuBarState,
                bundleIdentifier
              )
              await self.notifications.postFullScreenMenuBarVisibilityChanged()
              await self.notifications.postMenuBarHidingChanged()
            }

            if state.appMenuBarState != savedMenuBarState {
              await send(.gotAppMenuBarState(savedMenuBarState))
            }
          }
        } catch: { error, _ in
          await self.environment.log(error.localizedDescription)
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
        } catch: { error, _ in
          await self.environment.log(error.localizedDescription)
        }

      case .viewAppeared:
        return .run { send in
          if let appStates = await self.menuBarSettingsManager.getAppMenuBarStates() {
            var didSetMenuBarState = false
            for (bundleIdentifier, savedMenuBarStateString) in appStates {
              let currentMenuBarState = try await self.menuBarSettingsManager.getAppMenuBarState(
                bundleIdentifier
              )
              let savedMenuBarState = MenuBarState(string: savedMenuBarStateString)

              if savedMenuBarState != currentMenuBarState {
                try await self.menuBarSettingsManager.setAppMenuBarState(
                  savedMenuBarState,
                  bundleIdentifier
                )

                if !didSetMenuBarState { didSetMenuBarState = true }
              }
            }

            if didSetMenuBarState {
              await self.notifications.postFullScreenMenuBarVisibilityChanged()
              await self.notifications.postMenuBarHidingChanged()
            }
          }

          let bundleIdentifier = await self.menuBarSettingsManager.getBundleIdentifierOfCurrentApp()
          let menuBarState = try await self.menuBarSettingsManager.getAppMenuBarState(
            bundleIdentifier
          )
          await send(.gotAppMenuBarState(menuBarState))

          let systemMenuBarState = await self.menuBarSettingsManager.getSystemMenuBarState()
          await send(.gotSystemMenuBarState(systemMenuBarState))
        } catch: { error, _ in
          await self.environment.log(error.localizedDescription)
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
  public var appFeatureEnvironment: AppFeatureEnvironment {
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
      await NSApplication.shared.setActivationPolicy(.regular)

      let success = await NSApplication.shared.sendAction(
        Selector(("showSettingsWindow:")),
        to: nil,
        from: nil
      )

      if success {
        await NSApplication.shared.activate(ignoringOtherApps: true)
      } else {
        await NSApplication.shared.setActivationPolicy(.accessory)
      }
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

  let store: StoreOf<AppFeatureReducer>

  public init(store: StoreOf<AppFeatureReducer>) { self.store = store }

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
          .keyboardShortcut(",", modifiers: .command)
        Divider()
        Button("Quit Hideaway") { viewStore.send(.quitButtonPressed) }
          .keyboardShortcut("q", modifiers: .command)
      }
      .pickerStyle(.inline).onAppear { viewStore.send(.viewAppeared) }
      .task { await viewStore.send(.task).finish() }
    }
  }
}
