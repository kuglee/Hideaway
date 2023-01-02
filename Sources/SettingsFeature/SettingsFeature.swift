import AppList
import AppListItem
import AppMenuBarSaveState
import ComposableArchitecture
import ComposableArchitectureExtra
import MenuBarSettingsManager
import MenuBarState
import Notifications
import SwiftUI
import XCTestDynamicOverlay
import os.log

public struct SettingsFeatureReducer: ReducerProtocol {
  @Dependency(\.menuBarSettingsManager.getAppMenuBarStates) var getAppMenuBarStates
  @Dependency(\.menuBarSettingsManager.setAppMenuBarStates) var setAppMenuBarStates
  @Dependency(\.menuBarSettingsManager.getBundleDisplayName) var getBundleDisplayName
  @Dependency(\.menuBarSettingsManager.getUrlForApplication) var getUrlForApplication
  @Dependency(\.notifications) var notifications
  @Dependency(\.settingsFeatureEnvironment) var environment
  @Dependency(\.uuid) var uuid

  public init() {}

  public struct State: Equatable {
    public var appList: AppListReducer.State

    public init(appList: AppListReducer.State = .init()) { self.appList = appList }
  }

  public enum Action: Equatable {
    case appList(action: AppListReducer.Action)
    case gotAppList([String: String])
    case settingsWindowWillClose
    case task
  }

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .appList(action: _): return .none
      case let .gotAppList(appListItems):
        state.appList.appListItems = []

        for (bundleIdentifier, stringState) in getSortedAppListItems(dict: appListItems) {
          // filter apps that don't exist
          guard let _ = self.getUrlForApplication(bundleIdentifier) else { continue }

          let appMenuBarSaveState = AppMenuBarSaveState(
            bundleIdentifier: bundleIdentifier,
            state: MenuBarState.init(string: stringState)
          )

          state.appList.appListItems.append(
            .init(menuBarSaveState: appMenuBarSaveState, id: self.uuid())
          )
        }

        return .none
      case .settingsWindowWillClose:
        return .run { _ in await self.environment.setAccessoryActivationPolicy() }
      case .task:
        return .run { send in
          await withTaskGroup(of: Void.self) { group in
            group.addTask {
              var appMenuBarStateChanged = await self.notifications.appMenuBarStateChanged()
                .makeAsyncIterator()
              repeat {
                guard let appMenuBarStates = await self.getAppMenuBarStates() else { continue }

                await send(.gotAppList(appMenuBarStates))
              } while await appMenuBarStateChanged.next() != nil
            }
            group.addTask {
              for await _ in await self.notifications.settingsWindowWillClose() {
                await send(.settingsWindowWillClose)
              }
            }
            group.addTask {
              for await _ in await self.notifications.settingsWindowDidBecomeMain() {
                guard let appMenuBarStates = await self.getAppMenuBarStates() else { continue }

                await send(.gotAppList(appMenuBarStates))
              }
            }
          }
        }
      }
    }

    Scope(state: \State.appList, action: /Action.appList(action:)) { AppListReducer() }
      .onChange(of: \.appList.appListItems) { appListItems, state, _ in
        state.appList.appListItems = getSortedAppListItems(appListItems: state.appList.appListItems)

        var appStates = [String: String]()
        for appItem in appListItems {
          appStates[appItem.menuBarSaveState.bundleIdentifier] =
            appItem.menuBarSaveState.state.stringValue
        }

        return .run { [appStates] _ in
          await self.setAppMenuBarStates(appStates)
        } catch: { error, send in
          await self.environment.log(error.localizedDescription)
        }
      }
  }

  func getSortedAppListItems(appListItems: IdentifiedArrayOf<AppListItemReducer.State>)
    -> IdentifiedArrayOf<AppListItemReducer.State>
  {
    var appDisplayNames = [String: String]()

    for item in appListItems {
      guard let appBundleURL = self.getUrlForApplication(item.menuBarSaveState.bundleIdentifier),
        let appBundleDisplayName = self.getBundleDisplayName(appBundleURL)
      else { continue }

      appDisplayNames[item.menuBarSaveState.bundleIdentifier] = appBundleDisplayName
    }

    return IdentifiedArray(
      uniqueElements: appListItems.sorted { lhs, rhs in
        guard let lhsAppDisplayName = appDisplayNames[lhs.menuBarSaveState.bundleIdentifier],
          let rhsAppDisplayName = appDisplayNames[rhs.menuBarSaveState.bundleIdentifier]
        else { return true }

        return lhsAppDisplayName.localizedCaseInsensitiveCompare(rhsAppDisplayName)
          == .orderedAscending
      }
    )
  }

  func getSortedAppListItems(dict: [String: String]) -> [(String, String)] {
    var appDisplayNames = [String: String]()

    for bundleIdentifier in dict.keys {
      guard let appBundleURL = self.getUrlForApplication(bundleIdentifier),
        let appBundleDisplayName = self.getBundleDisplayName(appBundleURL)
      else { continue }

      appDisplayNames[bundleIdentifier] = appBundleDisplayName
    }

    return dict.sorted { lhs, rhs in
      guard let lhsAppDisplayName = appDisplayNames[lhs.key],
        let rhsAppDisplayName = appDisplayNames[rhs.key]
      else { return true }

      return lhsAppDisplayName.localizedCaseInsensitiveCompare(rhsAppDisplayName)
        == .orderedAscending
    }
  }

}

public enum SettingsFeatureEnvironmentKey: DependencyKey {
  public static let liveValue = SettingsFeatureEnvironment.live
  public static let testValue = SettingsFeatureEnvironment.unimplemented
}

extension DependencyValues {
  public var settingsFeatureEnvironment: SettingsFeatureEnvironment {
    get { self[SettingsFeatureEnvironmentKey.self] }
    set { self[SettingsFeatureEnvironmentKey.self] = newValue }
  }
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

public struct SettingsFeatureEnvironment {
  public var setAccessoryActivationPolicy: () async -> Void
  public var log: (String) async -> Void
}

extension SettingsFeatureEnvironment {
  public static let live = Self(
    setAccessoryActivationPolicy: {
      func changeToTheNextApp() async {
        await NSApplication.shared.hide(nil)

        // wait for the hiding to finish
        try? await Task.sleep(for: .milliseconds(10))
      }

      await changeToTheNextApp()
      await NSApplication.shared.setActivationPolicy(.accessory)
    },
    log: { message in os_log("%{public}@", message) }

  )
}

extension SettingsFeatureEnvironment {
  public static let unimplemented = Self(
    setAccessoryActivationPolicy: XCTUnimplemented("\(Self.self).setAccessoryActivationPolicy"),
    log: XCTUnimplemented("\(Self.self).log")
  )
}

public struct SettingsFeatureView: View {
  let store: StoreOf<SettingsFeatureReducer>

  public init(store: StoreOf<SettingsFeatureReducer>) { self.store = store }

  public var body: some View {
    WithViewStore(store) { viewStore in
      ScrollView {
        VStack {
          AppListView(
            store: store.scope(state: \.appList, action: SettingsFeatureReducer.Action.appList)
          )
          .task { await viewStore.send(.task).finish() }
        }
        .padding(20)
      }
    }
  }
}

public struct SettingsFeatureView_Previews: PreviewProvider {
  public static var previews: some View {
    SettingsFeatureView(
      store: Store(
        initialState: SettingsFeatureReducer.State(
          appList: AppListReducer.State(
            appListItems: .init(uniqueElements: [
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.Safari"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
            ])
          )
        ),
        reducer: SettingsFeatureReducer()
      )
    )
    .frame(width: 500, height: 300, alignment: .top)
  }
}
