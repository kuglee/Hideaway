import Foundation
import MenuBarState

public struct AppMenuBarSaveState: Equatable, Hashable {
  public var bundleIdentifier: String
  public var state: MenuBarState

  public init(bundleIdentifier: String, state: MenuBarState = .systemDefault) {
    self.bundleIdentifier = bundleIdentifier
    self.state = state
  }
}
