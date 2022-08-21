import ComposableArchitecture
import DefaultDistributedNotificationCenter
import MenuBarSettingsManager
import MenuBarState
import SharedNSWorkspaceNotificationCenter
import SwiftUI

public struct AppState: Equatable {
  public var appMenuBarState: MenuBarState
  public var systemMenuBarState: MenuBarState

  public init(
    appMenuBarState: MenuBarState = .default,
    systemMenuBarState: MenuBarState = .inFullScreenOnly
  ) {
    self.appMenuBarState = appMenuBarState
    self.systemMenuBarState = systemMenuBarState
  }
}

public enum AppAction {
  case appMenuBarStateSelected(state: MenuBarState)
  case systemMenuBarStateSelected(state: MenuBarState)
  case quitButtonPressed
  case fullScreenMenuBarVisibilityChangedFromOutside
  case menuBarHidingChangedFromOutside
  case didActivateApplication
  case viewAppeared
}

public struct AppEnvironment {
  public var menuBarSettingsManager: MenuBarSettingsManager
  public var distributedNotificationCenter: DefaultDistributedNotificationCenter
  public var workspaceNotificationCenter: SharedNSWorkspaceNotificationCenter

  public init(
    menuBarSettingsManager: MenuBarSettingsManager,
    distributedNotificationCenter: DefaultDistributedNotificationCenter,
    workspaceNotificationCenter: SharedNSWorkspaceNotificationCenter
  ) {
    self.menuBarSettingsManager = menuBarSettingsManager
    self.distributedNotificationCenter = distributedNotificationCenter
    self.workspaceNotificationCenter = workspaceNotificationCenter
  }
}

public let appReducer: Reducer<AppState, AppAction, AppEnvironment> = Reducer {
  state,
  action,
  environment in
  switch action {
  case .appMenuBarStateSelected(let menuBarState):
    state.appMenuBarState = menuBarState

    return .fireAndForget {
      environment.menuBarSettingsManager.setAppMenuBarState(menuBarState)
      environment.distributedNotificationCenter.post(
        .AppleInterfaceFullScreenMenuBarVisibilityChangedNotification,
        Bundle.main.bundleIdentifier
      )
      environment.distributedNotificationCenter.post(
        .AppleInterfaceMenuBarHidingChangedNotification,
        Bundle.main.bundleIdentifier
      )
    }
  case .systemMenuBarStateSelected(let menuBarState):
    state.systemMenuBarState = menuBarState

    return .fireAndForget {
      environment.menuBarSettingsManager.setSystemMenuBarState(menuBarState)
      environment.distributedNotificationCenter.post(
        .AppleInterfaceFullScreenMenuBarVisibilityChangedNotification,
        Bundle.main.bundleIdentifier
      )
      environment.distributedNotificationCenter.post(
        .AppleInterfaceMenuBarHidingChangedNotification,
        Bundle.main.bundleIdentifier
      )
    }
  case .quitButtonPressed: return Effect.fireAndForget { NSApplication.shared.terminate(nil) }
  case .fullScreenMenuBarVisibilityChangedFromOutside:
    state.appMenuBarState = environment.menuBarSettingsManager.getAppMenuBarState()
    state.systemMenuBarState = environment.menuBarSettingsManager.getSystemMenuBarState()

    return .none
  case .menuBarHidingChangedFromOutside:
    state.appMenuBarState = environment.menuBarSettingsManager.getAppMenuBarState()
    state.systemMenuBarState = environment.menuBarSettingsManager.getSystemMenuBarState()

    return .none
  case .didActivateApplication:
    state.appMenuBarState = environment.menuBarSettingsManager.getAppMenuBarState()

    return .none
  case .viewAppeared:
    state.appMenuBarState = environment.menuBarSettingsManager.getAppMenuBarState()
    state.systemMenuBarState = environment.menuBarSettingsManager.getSystemMenuBarState()

    return .run { send in
      environment.distributedNotificationCenter.observe(
        .AppleInterfaceFullScreenMenuBarVisibilityChangedNotification
      ) { notification in
        if (notification.object as? String?) != Bundle.main.bundleIdentifier {
          Task { await send(.fullScreenMenuBarVisibilityChangedFromOutside) }
        }
      }
      environment.distributedNotificationCenter.observe(
        .AppleInterfaceMenuBarHidingChangedNotification
      ) { notification in
        if (notification.object as? String?) != Bundle.main.bundleIdentifier {
          Task { await send(.menuBarHidingChangedFromOutside) }
        }
      }
      environment.workspaceNotificationCenter.observe(
        NSWorkspace.didActivateApplicationNotification
      ) { _ in Task { await send(.didActivateApplication) } }
    }
  }
}

public struct AppView: View {
  // WORKAROUND: onAppear is not being called when the view appears
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
