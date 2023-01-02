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
    public var doesCurrentAppNeedFullDiskAccess: Bool

    public init(
      appMenuBarState: MenuBarState = .systemDefault,
      systemMenuBarState: SystemMenuBarState = .inFullScreenOnly,
      doesCurrentAppNeedFullDiskAccess: Bool = false
    ) {
      self.appMenuBarState = appMenuBarState
      self.systemMenuBarState = systemMenuBarState
      self.doesCurrentAppNeedFullDiskAccess = doesCurrentAppNeedFullDiskAccess
    }
  }

  public enum Action: Equatable {
    case appMenuBarStateSelected(state: MenuBarState)
    case gotAppMenuBarState(MenuBarState)
    case saveAppMenuBarStateFailed(oldState: MenuBarState)
    case systemMenuBarStateSelected(state: SystemMenuBarState)
    case gotSystemMenuBarState(SystemMenuBarState)
    case fullScreenMenuBarVisibilityChangedNotification
    case menuBarHidingChangedNotification
    case didActivateApplication(bundleIdentifier: String)
    case didTerminateApplication(bundleIdentifier: String)
    case viewAppeared
    case task
    case settingsButtonPressed
  }

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case let .appMenuBarStateSelected(menuBarState):
        guard let bundleIdentifier = self.menuBarSettingsManager.getBundleIdentifierOfCurrentApp()
        else { return .none }

        if !self.menuBarSettingsManager.isSettableWithoutFullDiskAccess(bundleIdentifier) {
          state.doesCurrentAppNeedFullDiskAccess = true
          
          return .none
        }

        guard menuBarState != state.appMenuBarState else { return .none }

        let oldAppMenuBarState = state.appMenuBarState

        state.appMenuBarState = menuBarState

        return .run { [state, bundleIdentifier] send in
          try await self.menuBarSettingsManager.setAppMenuBarState(menuBarState, bundleIdentifier)

          var appStates: [String: String] =
            await self.menuBarSettingsManager.getAppMenuBarStates() ?? .init()

          appStates[bundleIdentifier] = menuBarState.stringValue

          await self.menuBarSettingsManager.setAppMenuBarStates(appStates)

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

        } catch: { error, send in
          await send(.saveAppMenuBarStateFailed(oldState: oldAppMenuBarState))
          await self.environment.log(error.localizedDescription)
        }
      case let .systemMenuBarStateSelected(menuBarState):
        guard menuBarState != state.systemMenuBarState else { return .none }

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
      case .fullScreenMenuBarVisibilityChangedNotification:
        guard let bundleIdentifier = self.menuBarSettingsManager.getBundleIdentifierOfCurrentApp()
        else { return .none }

        return .run { [state, bundleIdentifier] send in
          if let savedMenuBarState = try await self.setMenuBarStateOfApplication(
            bundleIdentifier: bundleIdentifier
          ), state.appMenuBarState != savedMenuBarState {
            await send(.gotAppMenuBarState(savedMenuBarState))
          }

          let systemMenuBarState = await self.menuBarSettingsManager.getSystemMenuBarState()
          await send(.gotSystemMenuBarState(systemMenuBarState))
        } catch: { error, _ in
          await self.environment.log(error.localizedDescription)
        }
      case .menuBarHidingChangedNotification:
        guard let bundleIdentifier = self.menuBarSettingsManager.getBundleIdentifierOfCurrentApp()
        else { return .none }

        return .run { [state] send in
          if let savedMenuBarState = try await self.setMenuBarStateOfApplication(
            bundleIdentifier: bundleIdentifier
          ), state.appMenuBarState != savedMenuBarState {
            await send(.gotAppMenuBarState(savedMenuBarState))
          }

          let systemMenuBarState = await self.menuBarSettingsManager.getSystemMenuBarState()
          await send(.gotSystemMenuBarState(systemMenuBarState))
        } catch: { error, _ in
          await self.environment.log(error.localizedDescription)
        }
      case let .gotAppMenuBarState(menuBarState):
        state.appMenuBarState = menuBarState
        return .none
      case let .saveAppMenuBarStateFailed(menuBarState):
        state.appMenuBarState = menuBarState
        return .none
      case let .gotSystemMenuBarState(menuBarState):
        state.systemMenuBarState = menuBarState

        return .none
      case let .didActivateApplication(bundleIdentifier):
        state.doesCurrentAppNeedFullDiskAccess = false

        return .run { [state] send in
          if let savedMenuBarState = try await self.setMenuBarStateOfApplication(
            bundleIdentifier: bundleIdentifier
          ), state.appMenuBarState != savedMenuBarState {
            await send(.gotAppMenuBarState(savedMenuBarState))
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
        guard let bundleIdentifier = self.menuBarSettingsManager.getBundleIdentifierOfCurrentApp()
        else { return .none }

        return .run { [state] send in
          let systemMenuBarState = await self.menuBarSettingsManager.getSystemMenuBarState()
          await send(.gotSystemMenuBarState(systemMenuBarState))

          if let savedMenuBarState = try await self.setMenuBarStateOfApplication(
            bundleIdentifier: bundleIdentifier
          ), state.appMenuBarState != savedMenuBarState {
            await send(.gotAppMenuBarState(savedMenuBarState))
          }
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
              for await bundleIdentifier in await self.notifications.didActivateApplication() {
                guard let bundleIdentifier else { return }

                await send(.didActivateApplication(bundleIdentifier: bundleIdentifier))
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

  func setMenuBarStateOfApplication(bundleIdentifier: String) async throws -> MenuBarState? {
    let currentMenuBarState = try await self.menuBarSettingsManager.getAppMenuBarState(
      bundleIdentifier
    )

    guard let appStates = await self.menuBarSettingsManager.getAppMenuBarStates() else {
      return nil
    }

    let savedMenuBarStateString =
      appStates[bundleIdentifier] ?? MenuBarState.systemDefault.stringValue
    let savedMenuBarState = MenuBarState(string: savedMenuBarStateString)

    if savedMenuBarState != currentMenuBarState {
      try await self.menuBarSettingsManager.setAppMenuBarState(savedMenuBarState, bundleIdentifier)
      await self.notifications.postFullScreenMenuBarVisibilityChanged()
      await self.notifications.postMenuBarHidingChanged()
    }

    return savedMenuBarState
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
  public var openSettings: () async -> Void
}

extension AppFeatureEnvironment {
  public static let live = Self(
    log: { message in os_log("%{public}@", message) },
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
        Button("Quit Hideaway") {
          // doesn't work if called from an async context
          NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
      }
      .pickerStyle(.inline).onAppear { viewStore.send(.viewAppeared) }
      .task { await viewStore.send(.task).finish() }
    }
  }
}
