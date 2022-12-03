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
  @Dependency(\.menuBarSettingsManager.getAppMenuBarStates) var getAppMenuBarStates
  @Dependency(\.notifications) var notifications
  @Dependency(\.uuid) var uuid

  public init() {}

  public struct State: Equatable {
    public var appList: AppListReducer.State

    public init(appList: AppListReducer.State = .init()) { self.appList = appList }
  }

  public enum Action: Equatable {
    case task
    case gotAppList([String: [String: String]])
    case appList(action: AppListReducer.Action)
  }

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        return .run { send in
          var appMenuBarStateChanged = await self.notifications.appMenuBarStateChanged()
            .makeAsyncIterator()
          repeat {
            await send(.gotAppList(self.getAppMenuBarStates() ?? .init()))
          } while await appMenuBarStateChanged.next() != nil
        }
      case .appList(action: _): return .none
      case let .gotAppList(appListItems):
        state.appList.appListItems = []

        for (key, value) in appListItems {
          let bundleIdentifier = key
          let bundlePath = value["bundlePath"]!
          let menuBarState = MenuBarState.init(string: value["state"]!)

          let appMenuBarSaveState = AppMenuBarSaveState(
            bundleIdentifier: bundleIdentifier,
            bundleURL: URL(string: bundlePath)!,
            state: menuBarState
          )

          state.appList.appListItems.append(
            AppListItemReducer.State(menuBarSaveState: appMenuBarSaveState, id: self.uuid())
          )
        }

        return .none
      }
    }
    Scope(state: \State.appList, action: /Action.appList(action:)) { AppListReducer() }
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
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.Safari",
                  bundleURL: URL(
                    string: "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"
                  )!
                ),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
              AppListItemReducer.State(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
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
