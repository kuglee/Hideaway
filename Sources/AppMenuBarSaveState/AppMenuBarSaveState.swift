import MenuBarState

public struct AppMenuBarSaveState: Equatable {
  public let bundleIdentifier: String
  public let state: MenuBarState?

  public init(bundleIdentifier: String, state: MenuBarState?) {
    self.bundleIdentifier = bundleIdentifier
    self.state = state
  }
}
