import AppKit
import Defaults
import MenuBarState

public enum MenuBarSettingsManagerError: Error, LocalizedError {
  case getError(message: String)
  case setError(message: String)
  case appError(message: String)

  public var errorDescription: String? {
    switch self {
    case let .getError(message): return message
    case let .setError(message): return message
    case let .appError(message): return message
    }
  }
}

extension Defaults.Keys {
  public static let menuBarVisibleInFullScreenKey: Self = .init("AppleMenuBarVisibleInFullscreen")
  public static let hideMenuBarOnDesktopKey: Self = .init("_HIHideMenuBar")
}

public let appStatesKey = "AppStates"

public struct MenuBarSettingsManager {
  public var getAppMenuBarState: (String?) async throws -> MenuBarState?
  public var setAppMenuBarState: (MenuBarState?, String?) async throws -> Void
  public var getSystemMenuBarState: () async -> MenuBarState
  public var setSystemMenuBarState: (MenuBarState) async -> Void
  public var getBundleIdentifierOfCurrentApp: () async -> String?
  public var getAppMenuBarStates: () async -> [String: [String: Bool]]?
  public var setAppMenuBarStates: ([String: [String: Bool]]) async -> Void
}

extension MenuBarSettingsManager {
  public static var live: Self {
    return .init(
      getAppMenuBarState: { bundleIdentifier in guard let bundleIdentifier else { return nil }

        do {
          let menuBarVisibleInFullScreen = try Defaults.get(
            key: .menuBarVisibleInFullScreenKey,
            bundleIdentifier: bundleIdentifier
          )
          let hideMenuBarOnDesktop = try Defaults.get(
            key: .hideMenuBarOnDesktopKey,
            bundleIdentifier: bundleIdentifier
          )

          guard menuBarVisibleInFullScreen != nil || hideMenuBarOnDesktop != nil else { return nil }

          return .init(
            menuBarVisibleInFullScreen: menuBarVisibleInFullScreen ?? false,
            hideMenuBarOnDesktop: hideMenuBarOnDesktop ?? false
          )
        } catch {
          throw MenuBarSettingsManagerError.getError(
            message: "Unable to get menu bar state of \"\(bundleIdentifier)\""
          )
        }
      },
      setAppMenuBarState: { state, bundleIdentifier in
        guard let bundleIdentifier = bundleIdentifier else {
          throw MenuBarSettingsManagerError.appError(
            message: "Unable to get the bundle identifier of current app"
          )
        }

        do {
          try Defaults.set(
            key: .menuBarVisibleInFullScreenKey,
            value: state?.rawValue.menuBarVisibleInFullScreen ?? nil,
            bundleIdentifier: bundleIdentifier
          )
          try Defaults.set(
            key: .hideMenuBarOnDesktopKey,
            value: state?.rawValue.hideMenuBarOnDesktop ?? nil,
            bundleIdentifier: bundleIdentifier
          )
        } catch {
          throw MenuBarSettingsManagerError.setError(
            message:
              "Unable to set menu bar state \"\(state?.label ?? "System default")\" of \"\(bundleIdentifier)\""
          )
        }
      },
      getSystemMenuBarState: {
        let menuBarVisibleInFullScreen = Defaults.get(key: .menuBarVisibleInFullScreenKey)
        let hideMenuBarOnDesktop = Defaults.get(key: .hideMenuBarOnDesktopKey)

        return .init(
          menuBarVisibleInFullScreen: menuBarVisibleInFullScreen,
          hideMenuBarOnDesktop: hideMenuBarOnDesktop
        )
      },
      setSystemMenuBarState: { state in
        Defaults.set(
          key: .menuBarVisibleInFullScreenKey,
          value: state.rawValue.menuBarVisibleInFullScreen
        )
        Defaults.set(key: .hideMenuBarOnDesktopKey, value: state.rawValue.hideMenuBarOnDesktop)
      },
      getBundleIdentifierOfCurrentApp: {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
      },
      getAppMenuBarStates: {
        UserDefaults.standard.dictionary(forKey: appStatesKey) as? [String: [String: Bool]]
      },
      setAppMenuBarStates: { appStates in
        UserDefaults.standard.setValue(appStates, forKey: appStatesKey)
      }
    )
  }
}

#if DEBUG
  import XCTestDynamicOverlay

  extension MenuBarSettingsManager {
    public static let unimplemented = Self(
      getAppMenuBarState: XCTUnimplemented("\(Self.self).getAppMenuBarState", placeholder: nil),
      setAppMenuBarState: XCTUnimplemented("\(Self.self).setAppMenuBarState"),
      getSystemMenuBarState: XCTUnimplemented(
        "\(Self.self).getSystemMenuBarState",
        placeholder: .inFullScreenOnly
      ),
      setSystemMenuBarState: XCTUnimplemented("\(Self.self).setSystemMenuBarState"),
      getBundleIdentifierOfCurrentApp: XCTUnimplemented(
        "\(Self.self).getBundleIdentifierOfCurrentApp"
      ),
      getAppMenuBarStates: XCTUnimplemented("\(Self.self).getAppMenuBarStates", placeholder: nil),
      setAppMenuBarStates: XCTUnimplemented("\(Self.self).setAppMenuBarStates")
    )
  }
#endif
