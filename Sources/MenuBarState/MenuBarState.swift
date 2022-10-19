public enum MenuBarState: CaseIterable {
  case always
  case onDesktopOnly
  case inFullScreenOnly
  case never
  case systemDefault

  public var label: String {
    switch self {
    case .always: return "Always"
    case .onDesktopOnly: return "On desktop only"
    case .inFullScreenOnly: return "In full screen only"
    case .never: return "Never"
    case .systemDefault: return "System Default"
    }
  }
}

extension MenuBarState: RawRepresentable {
  public init(rawValue: (menuBarVisibleInFullScreen: Bool?, hideMenuBarOnDesktop: Bool?)) {
    guard rawValue.menuBarVisibleInFullScreen != nil || rawValue.hideMenuBarOnDesktop != nil else {
      self = .systemDefault
      return
    }

    switch (rawValue.menuBarVisibleInFullScreen ?? false, rawValue.hideMenuBarOnDesktop ?? false) {
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
    case .systemDefault: return (menuBarVisibleInFullScreen: nil, hideMenuBarOnDesktop: nil)
    }
  }
}

extension MenuBarState {
  public init(string: String) {
    switch string {
    case "inFullScreenOnly": self = .inFullScreenOnly
    case "always": self = .always
    case "never": self = .never
    case "onDesktopOnly": self = .onDesktopOnly
    case "systemDefault": self = .systemDefault
    default: self = .systemDefault
    }
  }

  public var stringValue: String {
    switch self {
    case .inFullScreenOnly: return "inFullScreenOnly"
    case .always: return "always"
    case .never: return "never"
    case .onDesktopOnly: return "onDesktopOnly"
    case .systemDefault: return "systemDefault"
    }
  }
}

public enum SystemMenuBarState: CaseIterable {
  case always
  case onDesktopOnly
  case inFullScreenOnly
  case never

  public var label: String {
    switch self {
    case .always: return "Always"
    case .onDesktopOnly: return "On desktop only"
    case .inFullScreenOnly: return "In full screen only"
    case .never: return "Never"
    }
  }
}

extension SystemMenuBarState: RawRepresentable {
  public init(rawValue: (menuBarVisibleInFullScreen: Bool, hideMenuBarOnDesktop: Bool)) {
    switch (rawValue.menuBarVisibleInFullScreen, rawValue.hideMenuBarOnDesktop) {
    case (false, false): self = .inFullScreenOnly
    case (false, true): self = .always
    case (true, false): self = .never
    case (true, true): self = .onDesktopOnly
    }
  }

  public init(menuBarVisibleInFullScreen: Bool, hideMenuBarOnDesktop: Bool) {
    self.init(
      rawValue: (
        menuBarVisibleInFullScreen: menuBarVisibleInFullScreen,
        hideMenuBarOnDesktop: hideMenuBarOnDesktop
      )
    )
  }

  public var rawValue: (menuBarVisibleInFullScreen: Bool, hideMenuBarOnDesktop: Bool) {
    switch self {
    case .inFullScreenOnly: return (menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
    case .always: return (menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: true)
    case .never: return (menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: false)
    case .onDesktopOnly: return (menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: true)
    }
  }
}
