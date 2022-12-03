import Foundation
import MenuBarState

public struct AppMenuBarSaveState: Equatable, Hashable {
  public var bundleIdentifier: String
  public var bundleURL: URL
  public var state: MenuBarState

  public init(bundleIdentifier: String, bundleURL: URL, state: MenuBarState = .systemDefault) {
    self.bundleIdentifier = bundleIdentifier
    self.bundleURL = bundleURL
    self.state = state
  }
}
