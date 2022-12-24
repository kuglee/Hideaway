import AppList
import AppListItem
import AppMenuBarSaveState
import ComposableArchitecture
import MenuBarSettingsManager
import MenuBarState
import SwiftUI
import XCTestDynamicOverlay
import os.log

public struct SettingsFeatureReducer: ReducerProtocol {
  @Dependency(\.settingsFeatureEnvironment) var environment
  @Dependency(\.menuBarSettingsManager.getAppMenuBarStates) var getAppMenuBarStates
  @Dependency(\.menuBarSettingsManager.getUrlForApplication) var getUrlForApplication
  @Dependency(\.notifications) var notifications
  @Dependency(\.uuid) var uuid

  public init() {}

  public struct State: Equatable {
    public var appList: AppListReducer.State

    public init(appList: AppListReducer.State = .init()) { self.appList = appList }
  }

  public enum Action: Equatable {
    case task
    case gotAppList([String: String])
    case appList(action: AppListReducer.Action)
    case settingsWindowWillClose
  }

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
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
      case .appList(action: _): return .none
      case let .gotAppList(appListItems):
        state.appList.appListItems = []

        for (bundleIdentifier, stringState) in appListItems {
          // filter apps that don't exist
          guard let _ = self.getUrlForApplication(bundleIdentifier) else { continue }

          let appMenuBarSaveState = AppMenuBarSaveState(
            bundleIdentifier: bundleIdentifier,
            state: MenuBarState.init(string: stringState)
          )

          state.appList.appListItems.append(
            AppListItemReducer.State(menuBarSaveState: appMenuBarSaveState, id: self.uuid())
          )
        }

        return .none
      case .settingsWindowWillClose:
        return .run { _ in await self.environment.setAccessoryActivationPolicy() }
      }
    }
    Scope(state: \State.appList, action: /Action.appList(action:)) { AppListReducer() }
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

public struct SettingsFeatureEnvironment {
  public var setAccessoryActivationPolicy: () async -> Void
}

extension SettingsFeatureEnvironment {
  public static let live = Self(setAccessoryActivationPolicy: {
    func changeToTheNextApp() async {
      await NSApplication.shared.hide(nil)

      // wait for the hiding to finish
      try? await Task.sleep(for: .milliseconds(10))
    }

    await changeToTheNextApp()
    await NSApplication.shared.setActivationPolicy(.accessory)
  })
}

extension SettingsFeatureEnvironment {
  public static let unimplemented = Self(
    setAccessoryActivationPolicy: XCTUnimplemented("\(Self.self).setAccessoryActivationPolicy")
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
              AppListItemReducer.State(
                menuBarSaveState: .init(bundleIdentifier: "com.apple.Safari"),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"),
                id: UUID()
              ),
            ])
          )
        ),
        reducer: SettingsFeatureReducer()
      )
    )
    .frame(width: 500, height: 300, alignment: .top)
  }
}
