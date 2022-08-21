import AppKit
import Defaults
import MenuBarState

extension Defaults.Keys {
  public static let menuBarVisibleInFullScreenKey: Self = .init("AppleMenuBarVisibleInFullscreen")
  public static let hideMenuBarOnDesktopKey: Self = .init("_HIHideMenuBar")
}

public struct MenuBarSettingsManager {
  public var getAppMenuBarState: () -> MenuBarState
  public var setAppMenuBarState: (MenuBarState) -> Void
  public var getSystemMenuBarState: () -> MenuBarState
  public var setSystemMenuBarState: (MenuBarState) -> Void
}

extension MenuBarSettingsManager {
  public static var live: Self {
    let systemBundleIdentifier = "-g"

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
      Defaults[.menuBarVisibleInFullScreenKey, bundleIdentifier] =
        rawState.menuBarVisibleInFullScreen
      Defaults[.hideMenuBarOnDesktopKey, bundleIdentifier] = rawState.hideMenuBarOnDesktop
    }

    return .init(
      getAppMenuBarState: {
        guard let bundleIdentifier = getBundleIdentifierOfCurrentApp() else { return .default }

        return getMenuBarState(for: bundleIdentifier)
      },
      setAppMenuBarState: { state in
        guard let bundleIdentifier = getBundleIdentifierOfCurrentApp() else { return }

        setMenuBarState(state: state, for: bundleIdentifier)
      },
      getSystemMenuBarState: { getMenuBarState(for: systemBundleIdentifier) },
      setSystemMenuBarState: { state in setMenuBarState(state: state, for: systemBundleIdentifier) }
    )
  }
}

extension MenuBarSettingsManager {
  public static var mock: Self {
    .init(
      getAppMenuBarState: {
        .always

      },
      setAppMenuBarState: { _ in },
      getSystemMenuBarState: {
        .onDesktopOnly
      },
      setSystemMenuBarState: { _ in }
    )
  }
}
