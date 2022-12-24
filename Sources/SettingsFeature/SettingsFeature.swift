import AppList
import AppMenuBarSaveState
import ComposableArchitecture
import MenuBarSettingsManager
import MenuBarState
import Notifications
import SwiftUI
import XCTestDynamicOverlay
import os.log

public struct SettingsFeatureReducer: ReducerProtocol {
  @Dependency(\.settingsFeatureEnvironment) var environment
  @Dependency(\.menuBarSettingsManager.getAppMenuBarStates) var getAppMenuBarStates
  @Dependency(\.menuBarSettingsManager.setAppMenuBarStates) var setAppMenuBarStates
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
            .init(menuBarSaveState: appMenuBarSaveState, id: self.uuid())
          )
        }

        return .none
      case .settingsWindowWillClose:
        return .run { _ in await self.environment.setAccessoryActivationPolicy() }
      }
    }

    Scope(state: \State.appList, action: /Action.appList(action:)) { AppListReducer() }
      .onChange(of: \.appList) { appList, _, _ in var appStates = [String: String]()
        for appItem in appList.appListItems {
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

// from Isowords: https://github.com/pointfreeco/isowords/blob/9661c88cbf8e6d0bc41b6069f38ff6df29b9c2c4/Sources/TcaHelpers/OnChange.swift
extension ReducerProtocol {
  @inlinable public func onChange<ChildState: Equatable>(
    of toLocalState: @escaping (State) -> ChildState,
    perform additionalEffects: @escaping (ChildState, inout State, Action) -> Effect<Action, Never>
  ) -> some ReducerProtocol<State, Action> {
    self.onChange(of: toLocalState) { additionalEffects($1, &$2, $3) }
  }

  @inlinable public func onChange<ChildState: Equatable>(
    of toLocalState: @escaping (State) -> ChildState,
    perform additionalEffects: @escaping (ChildState, ChildState, inout State, Action) -> Effect<
      Action, Never
    >
  ) -> some ReducerProtocol<State, Action> {
    ChangeReducer(base: self, toLocalState: toLocalState, perform: additionalEffects)
  }
}

@usableFromInline
struct ChangeReducer<Base: ReducerProtocol, ChildState: Equatable>: ReducerProtocol {
  @usableFromInline let base: Base

  @usableFromInline let toLocalState: (Base.State) -> ChildState

  @usableFromInline let perform:
    (ChildState, ChildState, inout Base.State, Base.Action) -> Effect<Base.Action, Never>

  @usableFromInline init(
    base: Base,
    toLocalState: @escaping (Base.State) -> ChildState,
    perform: @escaping (ChildState, ChildState, inout Base.State, Base.Action) -> Effect<
      Base.Action, Never
    >
  ) {
    self.base = base
    self.toLocalState = toLocalState
    self.perform = perform
  }

  @inlinable public func reduce(into state: inout Base.State, action: Base.Action) -> Effect<
    Base.Action, Never
  > {
    let previousLocalState = self.toLocalState(state)
    let effects = self.base.reduce(into: &state, action: action)
    let localState = self.toLocalState(state)

    return previousLocalState != localState
      ? .merge(effects, self.perform(previousLocalState, localState, &state, action)) : effects
  }
}
