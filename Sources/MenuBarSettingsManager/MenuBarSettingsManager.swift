import AppKit
import Defaults
import MenuBarState
import XCTestDynamicOverlay

public enum MenuBarSettingsManagerError: Error, LocalizedError, Equatable {
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
  public var getAppMenuBarState: (String?) async throws -> MenuBarState
  public var setAppMenuBarState: (MenuBarState, String?) async throws -> Void
  public var getSystemMenuBarState: () async -> SystemMenuBarState
  public var setSystemMenuBarState: (SystemMenuBarState) async -> Void
  public var getBundleIdentifierOfCurrentApp: () async -> String?
  public var getAppMenuBarStates: () async -> [String: String]?
  public var setAppMenuBarStates: ([String: String]) async -> Void
}

extension MenuBarSettingsManager {
  public static var live: Self {
    .init(
      getAppMenuBarState: { bundleIdentifier in
        guard let bundleIdentifier else { return .systemDefault }

        do {
          let menuBarVisibleInFullScreen = try Defaults.get(
            key: .menuBarVisibleInFullScreenKey,
            bundleIdentifier: bundleIdentifier
          )
          let hideMenuBarOnDesktop = try Defaults.get(
            key: .hideMenuBarOnDesktopKey,
            bundleIdentifier: bundleIdentifier
          )

          guard menuBarVisibleInFullScreen != nil || hideMenuBarOnDesktop != nil else {
            return .systemDefault
          }

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
            value: state.rawValue.menuBarVisibleInFullScreen,
            bundleIdentifier: bundleIdentifier
          )
          try Defaults.set(
            key: .hideMenuBarOnDesktopKey,
            value: state.rawValue.hideMenuBarOnDesktop,
            bundleIdentifier: bundleIdentifier
          )
        } catch {
          throw MenuBarSettingsManagerError.setError(
            message: "Unable to set menu bar state \"\(state.label)\" of \"\(bundleIdentifier)\""
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
        UserDefaults.standard.dictionary(forKey: appStatesKey) as? [String: String]
      },
      setAppMenuBarStates: { appStates in
        UserDefaults.standard.setValue(appStates, forKey: appStatesKey)
      }
    )
  }
}

extension MenuBarSettingsManager {
  public static let unimplemented = Self(
    getAppMenuBarState: XCTUnimplemented(
      "\(Self.self).getAppMenuBarState",
      placeholder: .systemDefault
    ),
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
