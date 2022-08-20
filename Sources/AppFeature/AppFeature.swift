import ComposableArchitecture
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

// modify defaults using the defaults command because user defaults of system apps can't be
// modified even with sandboxing turned off
public struct Defaults {
  private static let defaultsExecutable = URL(filePath: "/usr/bin/defaults")

  private static func read(bundleIdentifier: String, key: Defaults.Keys) -> Bool? {
    let result = run(command: defaultsExecutable, with: ["read", bundleIdentifier, key.rawValue])

    switch result {
    case .success(let output): return output == "1\n" ? true : false
    case .failure(_): return nil
    }
  }

  private static func writeBool(bundleIdentifier: String, key: Defaults.Keys, value: Bool) {
    _ = run(
      command: defaultsExecutable,
      with: ["write", bundleIdentifier, key.rawValue, "-int", value ? "1" : "0"]
    )
  }

  private static func delete(bundleIdentifier: String, key: Defaults.Keys) {
    _ = run(command: defaultsExecutable, with: ["delete", bundleIdentifier, key.rawValue])
  }

  public static subscript(key: Defaults.Keys, bundleIdentifier: String? = nil) -> Bool? {
    get { Defaults.read(bundleIdentifier: bundleIdentifier ?? systemBundleIdentifier, key: key) }
    set {
      let bundleId = bundleIdentifier ?? systemBundleIdentifier
      if let newValue {
        Defaults.writeBool(bundleIdentifier: bundleId, key: key, value: newValue)
      } else {
        Defaults.delete(bundleIdentifier: bundleId, key: key)
      }
    }
  }
}

extension Defaults {
  public struct Keys: Hashable, Equatable, RawRepresentable {
    public var rawValue: String

    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(rawValue: String) { self.rawValue = rawValue }
  }
}

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

enum CommandError: Error, LocalizedError {
  case runError(message: String)
  case commandError(command: String, errorMessage: String?, exitStatus: Int)

  var localizedDescription: String {
    switch self {
    case .runError(let error): return error
    case .commandError(let command, let errorMessage, let exitStatus):
      var description = "Error: \(command) failed with exit status \(exitStatus)."

      if let errorMessage = errorMessage { description += " Error message: \(errorMessage)" }

      return description
    }
  }
}

func run(command lauchPath: URL, with arguments: [String] = []) -> Result<String?, CommandError> {
  let process = Process()
  process.executableURL = lauchPath
  process.arguments = arguments

  let standardOutput = Pipe()
  let standardError = Pipe()
  process.standardOutput = standardOutput
  process.standardError = standardError

  do { try process.run() } catch { return .failure(.runError(message: error.localizedDescription)) }

  let standardOutputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
  let output = String(data: standardOutputData, encoding: .utf8)
  let standardErrorData = standardError.fileHandleForReading.readDataToEndOfFile()
  let errorMessage = String(data: standardErrorData, encoding: .utf8)

  process.waitUntilExit()

  if process.terminationStatus != 0 {
    return .failure(
      .commandError(
        command: process.executableURL!.lastPathComponent,
        errorMessage: errorMessage,
        exitStatus: Int(process.terminationStatus)
      )
    )
  }

  return .success(output)
}
