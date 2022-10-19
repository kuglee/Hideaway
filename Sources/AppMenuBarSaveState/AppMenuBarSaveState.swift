import MenuBarState

public struct AppMenuBarSaveState: Equatable {
  public var bundleIdentifier: String
  public var bundlePath: String
  public var state: MenuBarState

  public init(bundleIdentifier: String, bundlePath: String, state: MenuBarState = .systemDefault) {
    self.bundleIdentifier = bundleIdentifier
    self.bundlePath = bundlePath
    self.state = state
  }
}
