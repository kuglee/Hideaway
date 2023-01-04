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
  @Dependency(\.menuBarSettingsManager.getAppMenuBarStates) var getAppMenuBarStates
  @Dependency(\.menuBarSettingsManager.setAppMenuBarState) var setAppMenuBarState
  @Dependency(\.menuBarSettingsManager.setAppMenuBarStates) var setAppMenuBarStates
  @Dependency(\.menuBarSettingsManager.getBundleDisplayName) var getBundleDisplayName
  @Dependency(\.menuBarSettingsManager.getBundleIcon) var getBundleIcon
  @Dependency(\.menuBarSettingsManager.getUrlForApplication) var getUrlForApplication
  @Dependency(\.menuBarSettingsManager.isSettableWithoutFullDiskAccess)
  var isSettableWithoutFullDiskAccess
  @Dependency(\.notifications) var notifications

  public init() {}

  public struct State: Equatable, Identifiable, Hashable, Comparable {
    public var menuBarSaveState: AppMenuBarSaveState
    public let id: UUID
    public var appName: String
    public var appIcon: NSImage?
    public var doesNeedFullDiskAccess: Bool

    public init(
      menuBarSaveState: AppMenuBarSaveState,
      id: UUID,
      appName: String,
      appIcon: NSImage? = nil,
      doesNeedFullDiskAccess: Bool = false
    ) {
      self.menuBarSaveState = menuBarSaveState
      self.id = id
      self.appIcon = appIcon
      self.appName = appName
      self.doesNeedFullDiskAccess = doesNeedFullDiskAccess
    }

    public static func < (lhs: AppListItemReducer.State, rhs: AppListItemReducer.State) -> Bool {
      lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
    }
  }

  public enum Action: Equatable {
    case menuBarStateSelected(state: MenuBarState)
    case saveMenuBarStateFailed(oldState: MenuBarState)
  }

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case let .menuBarStateSelected(menuBarState):
        guard menuBarState != state.menuBarSaveState.state else { return .none }

        if !self.isSettableWithoutFullDiskAccess(state.menuBarSaveState.bundleIdentifier) {
          state.doesNeedFullDiskAccess = true

          return .none
        }

        let oldMenuBarState = state.menuBarSaveState.state

        state.menuBarSaveState.state = menuBarState

        return .run { [state, oldMenuBarState] send in
          var appStates: [String: String] = await self.getAppMenuBarStates() ?? .init()

          appStates[state.menuBarSaveState.bundleIdentifier] =
            state.menuBarSaveState.state.stringValue
          await self.setAppMenuBarStates(appStates)

          if await self.environment.getRunningApps()
            .contains(state.menuBarSaveState.bundleIdentifier)
          {
            try await self.setAppMenuBarState(
              state.menuBarSaveState.state,
              state.menuBarSaveState.bundleIdentifier
            )

            if state.menuBarSaveState.state.rawValue.menuBarVisibleInFullScreen
              != oldMenuBarState.rawValue.menuBarVisibleInFullScreen
            {
              await self.notifications.postFullScreenMenuBarVisibilityChanged()
            }

            if state.menuBarSaveState.state.rawValue.hideMenuBarOnDesktop
              != oldMenuBarState.rawValue.hideMenuBarOnDesktop
            {
              await self.notifications.postMenuBarHidingChanged()
            }
          }
        } catch: { error, send in
          await send(.saveMenuBarStateFailed(oldState: oldMenuBarState))
          await self.environment.log(error.localizedDescription)
        }
      case let .saveMenuBarStateFailed(oldState):
        state.menuBarSaveState.state = oldState

        return .none
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

enum NotificationsManagerKey: DependencyKey {
  static let liveValue = Notifications.live
  static let testValue = Notifications.unimplemented
}

extension DependencyValues {
  var notifications: Notifications {
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
        (viewStore.appIcon != nil
          ? Image(nsImage: viewStore.appIcon!) : Image(systemName: "questionmark.app"))
          .resizable().frame(width: 32, height: 32)
        Text(viewStore.appName)
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

public struct AppListItem_Previews: PreviewProvider {
  public static var previews: some View {
    AppListItemView(
      store: Store(
        initialState: AppListItemReducer.State(
          menuBarSaveState: .init(bundleIdentifier: "com.apple.Safari"),
          id: UUID(),
          appName: "Safari"
        ),
        reducer: AppListItemReducer()
      )
    )
  }
}
