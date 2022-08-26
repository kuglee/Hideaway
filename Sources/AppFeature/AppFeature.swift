import ComposableArchitecture
import MenuBarSettingsManager
import MenuBarState
import SwiftUI
import XCTestDynamicOverlay
import os.log

import struct MenuBarSettingsManager.Unit

public struct AppState: Equatable {
  public var appMenuBarState: MenuBarState
  public var systemMenuBarState: MenuBarState

  public init(appMenuBarState: MenuBarState = .default, systemMenuBarState: MenuBarState = .default)
  {
    self.appMenuBarState = appMenuBarState
    self.systemMenuBarState = systemMenuBarState
  }
}

public enum AppAction: Equatable {
  case appMenuBarStateSelected(state: MenuBarState)
  case gotAppMenuBarState(TaskResult<MenuBarState>)
  case didSetAppMenuBarState(TaskResult<Unit>)
  case systemMenuBarStateSelected(state: MenuBarState)
  case gotSystemMenuBarState(TaskResult<MenuBarState>)
  case didSetSystemMenuBarState(TaskResult<Unit>)
  case quitButtonPressed
  case fullScreenMenuBarVisibilityChangedNotification
  case menuBarHidingChangedNotification
  case didActivateApplication
  case viewAppeared
  case task
}

public struct AppEnvironment {
  public var menuBarSettingsManager: MenuBarSettingsManager
  public var postFullScreenMenuBarVisibilityChanged: () async -> Void
  public var postMenuBarHidingChanged: () async -> Void
  public var fullScreenMenuBarVisibilityChanged: @Sendable () async -> AsyncStream<Void>
  public var menuBarHidingChanged: @Sendable () async -> AsyncStream<Void>
  public var didActivateApplication: @Sendable () async -> AsyncStream<Void>
  public var log: (String) async -> Void
  public var terminate: () async -> Void
}

extension AppEnvironment {
  public static let live = Self(
    menuBarSettingsManager: .live,
    postFullScreenMenuBarVisibilityChanged: {
      DistributedNotificationCenter.default()
        .post(
          name: .AppleInterfaceFullScreenMenuBarVisibilityChangedNotification,
          object: Bundle.main.bundleIdentifier
        )
    },
    postMenuBarHidingChanged: {
      DistributedNotificationCenter.default()
        .post(
          name: .AppleInterfaceMenuBarHidingChangedNotification,
          object: Bundle.main.bundleIdentifier
        )
    },
    fullScreenMenuBarVisibilityChanged: { @MainActor in
      AsyncStream(
        DistributedNotificationCenter.default()
          .notifications(named: .AppleInterfaceFullScreenMenuBarVisibilityChangedNotification)
          .compactMap { ($0.object as? String) == Bundle.main.bundleIdentifier ? nil : () }
      )
    },
    menuBarHidingChanged: { @MainActor in
      AsyncStream(
        DistributedNotificationCenter.default()
          .notifications(named: .AppleInterfaceMenuBarHidingChangedNotification)
          .compactMap { ($0.object as? String) == Bundle.main.bundleIdentifier ? nil : () }
      )
    },
    didActivateApplication: { @MainActor in
      AsyncStream(
        NSWorkspace.shared.notificationCenter
          .notifications(named: NSWorkspace.didActivateApplicationNotification).map { _ in }
      )
    },
    log: { message in os_log("%{public}@", message) },
    terminate: { await NSApplication.shared.terminate(nil) }
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension AppEnvironment {
    public static let unimplemented = Self(
      menuBarSettingsManager: .unimplemented,
      postFullScreenMenuBarVisibilityChanged: XCTUnimplemented(
        "\(Self.self).postFullScreenMenuBarVisibilityChanged"
      ),
      postMenuBarHidingChanged: XCTUnimplemented("\(Self.self).postMenuBarHidingChanged"),
      fullScreenMenuBarVisibilityChanged: XCTUnimplemented(
        "\(Self.self).fullScreenMenuBarVisibilityChanged",
        placeholder: AsyncStream.never
      ),
      menuBarHidingChanged: XCTUnimplemented(
        "\(Self.self).menuBarHidingChanged",
        placeholder: AsyncStream.never
      ),
      didActivateApplication: XCTUnimplemented(
        "\(Self.self).didActivateApplication",
        placeholder: AsyncStream.never
      ),
      log: XCTUnimplemented("\(Self.self).log"),
      terminate: XCTUnimplemented("\(Self.self).terminate")

    )
  }
#endif

extension Notification: @unchecked Sendable {}
extension NotificationCenter.Notifications: @unchecked Sendable {}

public let appReducer: Reducer<AppState, AppAction, AppEnvironment> = Reducer {
  state,
  action,
  environment in
  switch action {
  case let .appMenuBarStateSelected(menuBarState):
    let oldAppMenuBarState = state.appMenuBarState

    state.appMenuBarState = menuBarState

    return .run { [state] send in
      await send(
        .didSetAppMenuBarState(
          TaskResult {
            try await environment.menuBarSettingsManager.setAppMenuBarState(state.appMenuBarState)
          }
        )
      )

      await withTaskGroup(of: Void.self) { group in
        if state.appMenuBarState.rawValue.menuBarVisibleInFullScreen
          != oldAppMenuBarState.rawValue.menuBarVisibleInFullScreen
        {
          group.addTask { await environment.postFullScreenMenuBarVisibilityChanged() }
        }

        if state.appMenuBarState.rawValue.hideMenuBarOnDesktop
          != oldAppMenuBarState.rawValue.hideMenuBarOnDesktop
        {
          group.addTask { await environment.postMenuBarHidingChanged() }
        }
      }
    }
  case let .systemMenuBarStateSelected(menuBarState):
    let oldSystemMenuBarState = state.systemMenuBarState

    state.systemMenuBarState = menuBarState

    return .run { [state] send in
      await send(
        .didSetSystemMenuBarState(
          TaskResult {
            try await environment.menuBarSettingsManager.setSystemMenuBarState(
              state.systemMenuBarState
            )
          }
        )
      )

      await withTaskGroup(of: Void.self) { group in
        if state.systemMenuBarState.rawValue.menuBarVisibleInFullScreen
          != oldSystemMenuBarState.rawValue.menuBarVisibleInFullScreen
        {
          group.addTask { await environment.postFullScreenMenuBarVisibilityChanged() }
        }

        if state.systemMenuBarState.rawValue.hideMenuBarOnDesktop
          != oldSystemMenuBarState.rawValue.hideMenuBarOnDesktop
        {
          group.addTask { await environment.postMenuBarHidingChanged() }
        }
      }
    }
  case .quitButtonPressed: return .run { _ in await environment.terminate() }
  case .fullScreenMenuBarVisibilityChangedNotification:
    return .run { send in
      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          await send(
            .gotAppMenuBarState(
              TaskResult { try await environment.menuBarSettingsManager.getAppMenuBarState() }
            )
          )
        }
        group.addTask {
          await send(
            .gotSystemMenuBarState(
              TaskResult { try await environment.menuBarSettingsManager.getSystemMenuBarState() }
            )
          )
        }
      }
    }
  case .menuBarHidingChangedNotification:
    return .run { send in
      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          await send(
            .gotAppMenuBarState(
              TaskResult { try await environment.menuBarSettingsManager.getAppMenuBarState() }
            )
          )
        }
        group.addTask {
          await send(
            .gotSystemMenuBarState(
              TaskResult { try await environment.menuBarSettingsManager.getSystemMenuBarState() }
            )
          )
        }
      }
    }
  case let .gotAppMenuBarState(.success(menuBarState)):
    state.appMenuBarState = menuBarState

    return .none
  case let .gotAppMenuBarState(.failure(error)):
    return .run { _ in await environment.log(error.localizedDescription) }
  case .didSetAppMenuBarState(.success(_)): return .none
  case let .didSetAppMenuBarState(.failure(error)):
    return .run { _ in await environment.log(error.localizedDescription) }
  case let .gotSystemMenuBarState(.success(menuBarState)):
    state.systemMenuBarState = menuBarState

    return .none
  case let .gotSystemMenuBarState(.failure(error)):
    return .run { _ in await environment.log(error.localizedDescription) }
  case .didSetSystemMenuBarState(.success(_)): return .none
  case let .didSetSystemMenuBarState(.failure(error)):
    return .run { _ in await environment.log(error.localizedDescription) }
  case .didActivateApplication:
    return .task {
      await .gotAppMenuBarState(
        TaskResult { try await environment.menuBarSettingsManager.getAppMenuBarState() }
      )
    }
  case .viewAppeared:
    return .run { send in
      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          await send(
            .gotAppMenuBarState(
              TaskResult { try await environment.menuBarSettingsManager.getAppMenuBarState() }
            )
          )
        }
        group.addTask {
          await send(
            .gotSystemMenuBarState(
              TaskResult { try await environment.menuBarSettingsManager.getSystemMenuBarState() }
            )
          )
        }
      }
    }
  case .task:
    return .run { send in
      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          for await _ in await environment.fullScreenMenuBarVisibilityChanged() {
            await send(.fullScreenMenuBarVisibilityChangedNotification)
          }
        }
        group.addTask {
          for await _ in await environment.menuBarHidingChanged() {
            await send(.menuBarHidingChangedNotification)
          }
        }
        group.addTask {
          for await _ in await environment.didActivateApplication() {
            await send(.didActivateApplication)
          }
        }
      }
    }
  }
}

public struct AppView: View {
  // WORKAROUND: onAppear and task are not being called when the view appears
  @MainActor class ForceOnAppear: ObservableObject { init() { Task { objectWillChange.send() } } }
  @StateObject var forceOnAppear = ForceOnAppear()

  let store: Store<AppState, AppAction>

  public init(store: Store<AppState, AppAction>) { self.store = store }

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
        ) {
          ForEach(MenuBarState.allCases.filter { $0 != .default }, id: \.self) { Text($0.label) }
        }
        Button("Quit Hideaway") { viewStore.send(.quitButtonPressed) }
      }
      .pickerStyle(.inline).onAppear { viewStore.send(.viewAppeared) }
      .task { await viewStore.send(.task).finish() }
    }
  }
}

extension Notification.Name {
  public static var AppleInterfaceFullScreenMenuBarVisibilityChangedNotification: Notification.Name
  { Self.init("AppleInterfaceFullScreenMenuBarVisibilityChangedNotification") }

  public static var AppleInterfaceMenuBarHidingChangedNotification: Notification.Name {
    Self.init("AppleInterfaceMenuBarHidingChangedNotification")
  }
}
