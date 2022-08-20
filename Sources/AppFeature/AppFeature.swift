import ComposableArchitecture
import SwiftUI
import Defaults

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
      setAppMenuBarState(state: menuBarState)

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
      setMenuBarState(state: menuBarState, for: systemBundleIdentifier)

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
    state.systemMenuBarState = getMenuBarState(for: systemBundleIdentifier)

    return .none
  case .menuBarHidingChangedFromOutside:
    state.systemMenuBarState = getMenuBarState(for: systemBundleIdentifier)

    return .none
  case .didActivateApplication:
    state.appMenuBarState = getAppMenuBarState()

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

let systemBundleIdentifier = "-g"

extension Defaults.Keys {
  public static let menuBarVisibleInFullScreenKey: Self = .init("AppleMenuBarVisibleInFullscreen")
  public static let hideMenuBarOnDesktopKey: Self = .init("_HIHideMenuBar")
}

func getBundleIdentifierOfCurrentApp() -> String? {
  NSWorkspace.shared.frontmostApplication?.bundleIdentifier
}

func getMenuBarState(for bundleIdentifier: String) -> MenuBarState {
  let menuBarVisibleInFullScreen = Defaults[.menuBarVisibleInFullScreenKey, bundleIdentifier]
  let hideMenuBarOnDesktop = Defaults[.hideMenuBarOnDesktopKey, bundleIdentifier]

  return .init(
    menuBarVisibleInFullScreen: menuBarVisibleInFullScreen,
    hideMenuBarOnDesktop: hideMenuBarOnDesktop
  )
}

func setMenuBarState(state: MenuBarState, for bundleIdentifier: String) {
  let rawState = state.rawValue
  Defaults[.menuBarVisibleInFullScreenKey, bundleIdentifier] = rawState.menuBarVisibleInFullScreen
  Defaults[.hideMenuBarOnDesktopKey, bundleIdentifier] = rawState.hideMenuBarOnDesktop
}

public func getAppMenuBarState() -> MenuBarState {
  guard let bundleIdentifier = getBundleIdentifierOfCurrentApp() else { return .default }

  return getMenuBarState(for: bundleIdentifier)
}

func setAppMenuBarState(state: MenuBarState) {
  guard let bundleIdentifier = getBundleIdentifierOfCurrentApp() else { return }

  setMenuBarState(state: state, for: bundleIdentifier)
}

public func getSystemMenuBarState() -> MenuBarState {
  return getMenuBarState(for: systemBundleIdentifier)
}

func setSystemMenuBarState(state: MenuBarState) {
  setMenuBarState(state: state, for: systemBundleIdentifier)
}

public enum MenuBarState: CaseIterable {
  case always
  case onDesktopOnly
  case inFullScreenOnly
  case never
  case `default`

  public var label: String {
    switch self {
    case .always: return "Always"
    case .onDesktopOnly: return "On desktop only"
    case .inFullScreenOnly: return "In full screen only"
    case .never: return "Never"
    case .default: return "System default"
    }
  }
}

extension MenuBarState: RawRepresentable {
  public init(rawValue: (menuBarVisibleInFullScreen: Bool?, hideMenuBarOnDesktop: Bool?)) {
    guard let menuBarVisibleInFullScreen = rawValue.menuBarVisibleInFullScreen,
      let hideMenuBarOnDesktop = rawValue.hideMenuBarOnDesktop
    else {
      self = .default
      return
    }

    switch (menuBarVisibleInFullScreen, hideMenuBarOnDesktop) {
    case (false, false): self = .inFullScreenOnly
    case (false, true): self = .always
    case (true, false): self = .never
    case (true, true): self = .onDesktopOnly
    }
  }

  public init(menuBarVisibleInFullScreen: Bool?, hideMenuBarOnDesktop: Bool?) {
    self.init(
      rawValue: (
        menuBarVisibleInFullScreen: menuBarVisibleInFullScreen,
        hideMenuBarOnDesktop: hideMenuBarOnDesktop
      )
    )
  }

  public var rawValue: (menuBarVisibleInFullScreen: Bool?, hideMenuBarOnDesktop: Bool?) {
    switch self {
    case .inFullScreenOnly: return (menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
    case .always: return (menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: true)
    case .never: return (menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: false)
    case .onDesktopOnly: return (menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: true)
    case .default: return (menuBarVisibleInFullScreen: nil, hideMenuBarOnDesktop: nil)
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
