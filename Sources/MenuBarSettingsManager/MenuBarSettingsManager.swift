import Defaults
import AppKit
import MenuBarState

extension Defaults.Keys {
  public static let menuBarVisibleInFullScreenKey: Self = .init("AppleMenuBarVisibleInFullscreen")
  public static let hideMenuBarOnDesktopKey: Self = .init("_HIHideMenuBar")
}

public struct MenuBarSettingsManager {
  static let systemBundleIdentifier = "-g"

  private static func getMenuBarState(for bundleIdentifier: String) -> MenuBarState {
    let menuBarVisibleInFullScreen = Defaults[.menuBarVisibleInFullScreenKey, bundleIdentifier]
    let hideMenuBarOnDesktop = Defaults[.hideMenuBarOnDesktopKey, bundleIdentifier]

    return .init(
      menuBarVisibleInFullScreen: menuBarVisibleInFullScreen,
      hideMenuBarOnDesktop: hideMenuBarOnDesktop
    )
  }

  private static func setMenuBarState(state: MenuBarState, for bundleIdentifier: String) {
    let rawState = state.rawValue
    Defaults[.menuBarVisibleInFullScreenKey, bundleIdentifier] = rawState.menuBarVisibleInFullScreen
    Defaults[.hideMenuBarOnDesktopKey, bundleIdentifier] = rawState.hideMenuBarOnDesktop
  }

  public static func getAppMenuBarState() -> MenuBarState {
    guard let bundleIdentifier = getBundleIdentifierOfCurrentApp() else { return .default }

    return getMenuBarState(for: bundleIdentifier)
  }

  public static func setAppMenuBarState(state: MenuBarState) {
    guard let bundleIdentifier = getBundleIdentifierOfCurrentApp() else { return }

    setMenuBarState(state: state, for: bundleIdentifier)
  }

  public static func getSystemMenuBarState() -> MenuBarState {
    return getMenuBarState(for: systemBundleIdentifier)
  }

  public static func setSystemMenuBarState(state: MenuBarState) {
    setMenuBarState(state: state, for: systemBundleIdentifier)
  }
}

func getBundleIdentifierOfCurrentApp() -> String? {
  NSWorkspace.shared.frontmostApplication?.bundleIdentifier
}
