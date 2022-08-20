public enum MenuBarState: CaseIterable {
  case always
  case onDesktopOnly
  case inFullScreenOnly
  case never
  case `default`

  public var label: String {
    switch self {
    case .always: return "Always"
    case .onDesktopOnly: return "On desktop only"
    case .inFullScreenOnly: return "In full screen only"
    case .never: return "Never"
    case .default: return "System default"
    }
  }
}

extension MenuBarState: RawRepresentable {
  public init(rawValue: (menuBarVisibleInFullScreen: Bool?, hideMenuBarOnDesktop: Bool?)) {
    guard let menuBarVisibleInFullScreen = rawValue.menuBarVisibleInFullScreen,
      let hideMenuBarOnDesktop = rawValue.hideMenuBarOnDesktop
    else {
      self = .default
      return
    }

    switch (menuBarVisibleInFullScreen, hideMenuBarOnDesktop) {
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
    case .default: return (menuBarVisibleInFullScreen: nil, hideMenuBarOnDesktop: nil)
    }
  }
}
