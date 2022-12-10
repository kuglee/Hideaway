import AppMenuBarSaveState
import ComposableArchitecture
import MenuBarSettingsManager
import MenuBarState
import Notifications
import SwiftUI
import XCTestDynamicOverlay
import os.log

public struct AppListItemReducer: ReducerProtocol {
  @Dependency(\.appListItemEnvironment) var environment
  @Dependency(\.menuBarSettingsManager) var menuBarSettingsManager
  @Dependency(\.notifications) var notifications

  public init() {}

  public struct State: Equatable, Identifiable, Hashable {
    public var menuBarSaveState: AppMenuBarSaveState
    public let id: UUID

    public init(menuBarSaveState: AppMenuBarSaveState, id: UUID) {
      self.menuBarSaveState = menuBarSaveState
      self.id = id
    }
  }

  public enum Action: Equatable {
    case didSaveMenuBarState(MenuBarState)
    case menuBarStateSelected(state: MenuBarState)
  }

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case let .didSaveMenuBarState(menuBarState):
        let oldAppMenuBarState = state.menuBarSaveState.state

        state.menuBarSaveState.state = menuBarState

        return .run { [state] _ in
          if await self.environment.getRunningApps()
            .contains(state.menuBarSaveState.bundleIdentifier)
          {
            try await self.menuBarSettingsManager.setAppMenuBarState(
              state.menuBarSaveState.state,
              state.menuBarSaveState.bundleIdentifier
            )

            if state.menuBarSaveState.state.rawValue.menuBarVisibleInFullScreen
              != oldAppMenuBarState.rawValue.menuBarVisibleInFullScreen
            {
              await self.notifications.postFullScreenMenuBarVisibilityChanged()
            }

            if state.menuBarSaveState.state.rawValue.hideMenuBarOnDesktop
              != oldAppMenuBarState.rawValue.hideMenuBarOnDesktop
            {
              await self.notifications.postMenuBarHidingChanged()
            }
          }
        } catch: { error, _ in
          await self.environment.log(error.localizedDescription)
        }
      case let .menuBarStateSelected(menuBarState):
        guard menuBarState != state.menuBarSaveState.state else { return .none }

        return .run { [state] send in
          var appStates: [String: String] =
            await self.menuBarSettingsManager.getAppMenuBarStates() ?? .init()

          appStates[state.menuBarSaveState.bundleIdentifier] = menuBarState.stringValue
          await self.menuBarSettingsManager.setAppMenuBarStates(appStates)

          await send(.didSaveMenuBarState(menuBarState))
        }
      }
    }
  }
}

public enum AppListItemEnvironmentKey: DependencyKey {
  public static let liveValue = AppListItemEnvironment.live
  public static let testValue = AppListItemEnvironment.unimplemented
}

extension DependencyValues {
  public var appListItemEnvironment: AppListItemEnvironment {
    get { self[AppListItemEnvironmentKey.self] }
    set { self[AppListItemEnvironmentKey.self] = newValue }
  }
}

public struct AppListItemEnvironment {
  public var getRunningApps: () async -> [String]
  public var log: (String) async -> Void
}

extension AppListItemEnvironment {
  public static let live = Self(
    getRunningApps: { @MainActor in
      NSWorkspace.shared.runningApplications.compactMap { app in
        if app.bundleURL?.absoluteString.contains(".app/") != nil,
          let bundleIdentifier = app.bundleIdentifier
        {
          return bundleIdentifier
        }

        return nil
      }
    },
    log: { message in os_log("%{public}@", message) }
  )
}

extension AppListItemEnvironment {
  public static let unimplemented = Self(
    getRunningApps: XCTUnimplemented("\(Self.self).getRunningApps", placeholder: []),
    log: XCTUnimplemented("\(Self.self).log")
  )
}

enum MenuBarSettingsManagerKey: DependencyKey {
  static let liveValue = MenuBarSettingsManager.live
  static let testValue = MenuBarSettingsManager.unimplemented
}

extension DependencyValues {
  var menuBarSettingsManager: MenuBarSettingsManager {
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

public struct AppListItemView: View {
  let store: StoreOf<AppListItemReducer>

  public init(store: StoreOf<AppListItemReducer>) { self.store = store }

  public var body: some View {
    WithViewStore(store) { viewStore in
      HStack {
        Image(nsImage: getAppIcon(bundleIdentifier: viewStore.menuBarSaveState.bundleIdentifier))
        Text("\(getAppName(bundleIdentifier: viewStore.menuBarSaveState.bundleIdentifier))")
        Spacer()
        Picker(
          selection: viewStore.binding(
            get: \.menuBarSaveState.state,
            send: { .menuBarStateSelected(state: $0) }
          ),
          label: EmptyView()
        ) { ForEach(MenuBarState.allCases, id: \.self) { Text($0.label) } }
        .labelsHidden().fixedSize().padding(.trailing, 1)  // bug: List cuts off the trailing edge
      }
    }
  }
}

func getAppName(bundleIdentifier: String) -> String {
  let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)!
  return String(bundleURL.lastPathComponent.dropLast(4))
}

func getAppIcon(bundleIdentifier: String) -> NSImage {
  let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)!

  return NSWorkspace.shared.icon(forFile: bundleURL.relativePath)
}

public struct AppListItem_Previews: PreviewProvider {
  public static var previews: some View {
    AppListItemView(
      store: Store(
        initialState: AppListItemReducer.State(
          menuBarSaveState: .init(bundleIdentifier: "com.apple.Safari"),
          id: UUID()
        ),
        reducer: AppListItemReducer()
      )
    )
  }
}
