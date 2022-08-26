import AppKit
import Defaults
import MenuBarState

public struct Unit: Equatable {}
public let unit = Unit()

public enum MenuBarSettingsManagerError: Error, LocalizedError, Equatable {
  case getError(message: String)
  case setError(message: String)
  case appError(message: String)

  var localizedDescription: String {
    switch self {
    case let .getError(error): return error
    case let .setError(error): return error
    case let .appError(error): return error
    }
  }
}

extension Defaults.Keys {
  public static let menuBarVisibleInFullScreenKey: Self = .init("AppleMenuBarVisibleInFullscreen")
  public static let hideMenuBarOnDesktopKey: Self = .init("_HIHideMenuBar")
}

public struct MenuBarSettingsManager {
  public var getAppMenuBarState: () async throws -> MenuBarState
  public var setAppMenuBarState: (MenuBarState) async throws -> Unit
  public var getSystemMenuBarState: () async throws -> MenuBarState
  public var setSystemMenuBarState: (MenuBarState) async throws -> Unit
}

extension MenuBarSettingsManager {
  public static var live: Self {
    let systemBundleIdentifier = "-g"

    func getBundleIdentifierOfCurrentApp() -> String? {
      NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func getMenuBarState(for bundleIdentifier: String) throws -> MenuBarState {
      do {
        let menuBarVisibleInFullScreen = try Defaults.get(
          key: .menuBarVisibleInFullScreenKey,
          bundleIdentifier: bundleIdentifier
        )
        let hideMenuBarOnDesktop = try Defaults.get(
          key: .hideMenuBarOnDesktopKey,
          bundleIdentifier: bundleIdentifier
        )

        return .init(
          menuBarVisibleInFullScreen: menuBarVisibleInFullScreen,
          hideMenuBarOnDesktop: hideMenuBarOnDesktop
        )
      } catch {
        throw MenuBarSettingsManagerError.getError(
          message: "Unable to get menu bar state of \"\(bundleIdentifier)\""
        )
      }
    }

    func setMenuBarState(state: MenuBarState, for bundleIdentifier: String) throws {
      do {
        let rawState = state.rawValue
        try Defaults.set(
          key: .menuBarVisibleInFullScreenKey,
          value: rawState.menuBarVisibleInFullScreen,
          bundleIdentifier: bundleIdentifier
        )
        try Defaults.set(
          key: .hideMenuBarOnDesktopKey,
          value: rawState.hideMenuBarOnDesktop,
          bundleIdentifier: bundleIdentifier
        )
      } catch {
        throw MenuBarSettingsManagerError.setError(
          message: "Unable to set menu bar state \"\(state.label)\" of \"\(bundleIdentifier)\""
        )
      }
    }

    return .init(
      getAppMenuBarState: {
        guard let bundleIdentifier = getBundleIdentifierOfCurrentApp() else { return .default }

        do { return try getMenuBarState(for: bundleIdentifier) } catch { throw error }
      },
      setAppMenuBarState: { state in
        guard let bundleIdentifier = getBundleIdentifierOfCurrentApp() else {
          throw MenuBarSettingsManagerError.appError(
            message: "Unable to get the bundle identifier of current app"
          )
        }

        do { try setMenuBarState(state: state, for: bundleIdentifier) } catch { throw error }

        return unit
      },
      getSystemMenuBarState: {
        do { return try getMenuBarState(for: systemBundleIdentifier) } catch { throw error }
      },
      setSystemMenuBarState: { state in
        do { try setMenuBarState(state: state, for: systemBundleIdentifier) } catch { throw error }

        return unit
      }
    )
  }
}

#if DEBUG
  import XCTestDynamicOverlay

  extension MenuBarSettingsManager {
    public static let unimplemented = Self(
      getAppMenuBarState: XCTUnimplemented(
        "\(Self.self).getAppMenuBarState",
        placeholder: .default
      ),
      setAppMenuBarState: XCTUnimplemented("\(Self.self).setAppMenuBarState"),
      getSystemMenuBarState: XCTUnimplemented(
        "\(Self.self).getSystemMenuBarState",
        placeholder: .default
      ),
      setSystemMenuBarState: XCTUnimplemented("\(Self.self).setSystemMenuBarState")
    )
  }
#endif
