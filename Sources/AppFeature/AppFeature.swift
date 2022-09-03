import ComposableArchitecture
import MenuBarSettingsManager
import MenuBarState
import SwiftUI
import os.log

public struct AppMenuBarSaveState: Equatable {
  public let bundleIdentifier: String
  public let state: MenuBarState?
}

public struct AppFeature: ReducerProtocol {
  @Dependency(\.appEnvironment) var environment
  @Dependency(\.menuBarSettingsManager) var menuBarSettingsManager

  public init() {}

  public struct State: Equatable {
    public var appMenuBarState: MenuBarState?
    public var systemMenuBarState: MenuBarState

    public init(
      appMenuBarState: MenuBarState? = nil,
      systemMenuBarState: MenuBarState = .inFullScreenOnly
    ) {
      self.appMenuBarState = appMenuBarState
      self.systemMenuBarState = systemMenuBarState
    }
  }

  public enum Action: Equatable {
    case appMenuBarStateSelected(state: MenuBarState?)
    case gotAppMenuBarState(TaskResult<MenuBarState?>)
    case didSaveAppMenuBarState(TaskResult<AppMenuBarSaveState>)
    case systemMenuBarStateSelected(state: MenuBarState)
    case gotSystemMenuBarState(MenuBarState)
    case quitButtonPressed
    case fullScreenMenuBarVisibilityChangedNotification
    case menuBarHidingChangedNotification
    case didActivateApplication
    case viewAppeared
    case task
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

          await send(
            .didSaveAppMenuBarState(
              TaskResult {
                try await self.menuBarSettingsManager.setAppMenuBarState(
                  menuBarState,
                  bundleIdentifier
                )

                if let menuBarState {
                  var appStates: [String: [String: Bool]] =
                    await self.menuBarSettingsManager.getAppMenuBarStates() ?? .init()

                  appStates[bundleIdentifier] = menuBarState.dictValue

                  await self.menuBarSettingsManager.setAppMenuBarStates(appStates)
                } else {
                  if var appStates = await self.menuBarSettingsManager.getAppMenuBarStates() {
                    appStates.removeValue(forKey: bundleIdentifier)
                    await self.menuBarSettingsManager.setAppMenuBarStates(appStates)
                  }
                }

                return AppMenuBarSaveState(bundleIdentifier: bundleIdentifier, state: menuBarState)
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
            await self.environment.postFullScreenMenuBarVisibilityChanged()
          }

          if state.systemMenuBarState.rawValue.hideMenuBarOnDesktop
            != oldSystemMenuBarState.rawValue.hideMenuBarOnDesktop
          {
            await self.environment.postMenuBarHidingChanged()
          }
        }
      case .quitButtonPressed:
        return .run { _ in
          if let appStates = await self.menuBarSettingsManager.getAppMenuBarStates() {
            for key in appStates.keys {
              try await self.menuBarSettingsManager.setAppMenuBarState(nil, key)
            }

            await self.environment.postFullScreenMenuBarVisibilityChanged()
            await self.environment.postMenuBarHidingChanged()
          }

          await self.environment.terminate()
        }
      case .fullScreenMenuBarVisibilityChangedNotification:
        return .run { send in
          let bundleIdentifier = await self.menuBarSettingsManager.getBundleIdentifierOfCurrentApp()

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
          let bundleIdentifier = await self.menuBarSettingsManager.getBundleIdentifierOfCurrentApp()

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
      case let .didSaveAppMenuBarState(.success(appMenuBarSaveState)):
        let oldAppMenuBarState = state.appMenuBarState

        state.appMenuBarState = appMenuBarSaveState.state

        return .run { [state] _ in
          if state.appMenuBarState?.rawValue.menuBarVisibleInFullScreen
            != oldAppMenuBarState?.rawValue.menuBarVisibleInFullScreen
          {
            await self.environment.postFullScreenMenuBarVisibilityChanged()
          }

          if state.appMenuBarState?.rawValue.hideMenuBarOnDesktop
            != oldAppMenuBarState?.rawValue.hideMenuBarOnDesktop
          {
            await self.environment.postMenuBarHidingChanged()
          }

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
                .getBundleIdentifierOfCurrentApp()

              return try await self.menuBarSettingsManager.getAppMenuBarState(bundleIdentifier)
            }
          )
        }
      case .viewAppeared:
        return .run { send in
          if let appStates = await self.menuBarSettingsManager.getAppMenuBarStates() {
            for (key, value) in appStates {
              try await self.menuBarSettingsManager.setAppMenuBarState(
                MenuBarState(dictionary: value),
                key
              )
            }

            await self.environment.postFullScreenMenuBarVisibilityChanged()
            await self.environment.postMenuBarHidingChanged()
          }

          let bundleIdentifier = await self.menuBarSettingsManager.getBundleIdentifierOfCurrentApp()

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
              for await _ in await self.environment.fullScreenMenuBarVisibilityChanged() {
                await send(.fullScreenMenuBarVisibilityChangedNotification)
              }
            }
            group.addTask {
              for await _ in await self.environment.menuBarHidingChanged() {
                await send(.menuBarHidingChangedNotification)
              }
            }
            group.addTask {
              for await _ in await self.environment.didActivateApplication() {
                await send(.didActivateApplication)
              }
            }
          }
        }
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

public struct AppFeatureEnvironment {
  public var postFullScreenMenuBarVisibilityChanged: () async -> Void
  public var postMenuBarHidingChanged: () async -> Void
  public var fullScreenMenuBarVisibilityChanged: @Sendable () async -> AsyncStream<Void>
  public var menuBarHidingChanged: @Sendable () async -> AsyncStream<Void>
  public var didActivateApplication: @Sendable () async -> AsyncStream<Void>
  public var log: (String) async -> Void
  public var terminate: () async -> Void
}

extension AppFeatureEnvironment {
  public static let live = Self(
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

  extension AppFeatureEnvironment {
    public static let unimplemented = Self(
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

public struct AppView: View {
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
        ) {
          ForEach(MenuBarState.allCases, id: \.self) { Text($0.label).tag($0 as MenuBarState?) }
          Text("System default").tag(nil as MenuBarState?)
        }
        Picker(
          selection: viewStore.binding(
            get: \.systemMenuBarState,
            send: { .systemMenuBarStateSelected(state: $0) }
          ),
          label: Text("Hide the menu bar system-wide")
        ) { ForEach(MenuBarState.allCases, id: \.self) { Text($0.label) } }
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
