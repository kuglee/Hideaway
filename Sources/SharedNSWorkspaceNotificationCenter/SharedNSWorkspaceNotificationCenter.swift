import AppKit

public struct SharedNSWorkspaceNotificationCenter {
  public var observe: (NSNotification.Name, @escaping @Sendable (Notification) -> Void) -> Void
}

extension SharedNSWorkspaceNotificationCenter {
  public static var live: Self {
    .init(observe: { name, callback in
      NSWorkspace.shared.notificationCenter.addObserver(
        forName: name,
        object: nil,
        queue: nil,
        using: callback
      )
    })
  }
}
