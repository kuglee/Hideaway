import ComposableArchitecture
import MenuBarSettingsManager
import MenuBarState
import SwiftUI

public struct AppState: Equatable {
  public var appMenuBarState: MenuBarState
  public var systemMenuBarState: MenuBarState

  public init(appMenuBarState: MenuBarState, systemMenuBarState: MenuBarState) {
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
}

public let appReducer: Reducer<AppState, AppAction, Void> = Reducer { state, action, _ in
  switch action {
  case .appMenuBarStateSelected(let menuBarState):
    state.appMenuBarState = menuBarState

    return .fireAndForget {
      MenuBarSettingsManager.setAppMenuBarState(state: menuBarState)

      DistributedNotificationCenter.default()
        .post(
          name: .AppleInterfaceFullScreenMenuBarVisibilityChangedNotification,
          object: Bundle.main.bundleIdentifier
        )
      DistributedNotificationCenter.default()
        .post(
          name: .AppleInterfaceMenuBarHidingChangedNotification,
          object: Bundle.main.bundleIdentifier
        )
    }
  case .systemMenuBarStateSelected(let menuBarState):
    state.systemMenuBarState = menuBarState

    return .fireAndForget {
      MenuBarSettingsManager.setSystemMenuBarState(state: menuBarState)

      DistributedNotificationCenter.default()
        .post(
          name: .AppleInterfaceFullScreenMenuBarVisibilityChangedNotification,
          object: Bundle.main.bundleIdentifier
        )
      DistributedNotificationCenter.default()
        .post(
          name: .AppleInterfaceMenuBarHidingChangedNotification,
          object: Bundle.main.bundleIdentifier
        )
    }
  case .quitButtonPressed: return Effect.fireAndForget { NSApplication.shared.terminate(nil) }
  case .fullScreenMenuBarVisibilityChangedFromOutside:
    state.appMenuBarState = MenuBarSettingsManager.getAppMenuBarState()
    state.systemMenuBarState = MenuBarSettingsManager.getSystemMenuBarState()

    return .none
  case .menuBarHidingChangedFromOutside:
    state.appMenuBarState = MenuBarSettingsManager.getAppMenuBarState()
    state.systemMenuBarState = MenuBarSettingsManager.getSystemMenuBarState()

    return .none
  case .didActivateApplication:
    state.appMenuBarState = MenuBarSettingsManager.getAppMenuBarState()

    return .none
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
      .pickerStyle(.inline)
      .onAppear {
        DistributedNotificationCenter.default()
          .addObserver(
            forName: .AppleInterfaceFullScreenMenuBarVisibilityChangedNotification,
            object: nil,
            queue: nil
          ) { notification in
            if (notification.object as? String?) != Bundle.main.bundleIdentifier {
              viewStore.send(.fullScreenMenuBarVisibilityChangedFromOutside)
            }
          }
        DistributedNotificationCenter.default()
          .addObserver(
            forName: .AppleInterfaceMenuBarHidingChangedNotification,
            object: nil,
            queue: nil
          ) { notification in
            if (notification.object as? String?) != Bundle.main.bundleIdentifier {
              viewStore.send(.menuBarHidingChangedFromOutside)
            }
          }
        NSWorkspace.shared.notificationCenter.addObserver(
          forName: NSWorkspace.didActivateApplicationNotification,
          object: nil,
          queue: nil
        ) { _ in viewStore.send(.didActivateApplication) }
      }
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
