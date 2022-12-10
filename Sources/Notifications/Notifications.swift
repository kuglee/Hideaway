import AppKit
import ComposableArchitecture
import Foundation
import XCTestDynamicOverlay

public struct Notifications {
  public var postFullScreenMenuBarVisibilityChanged: () async -> Void
  public var postMenuBarHidingChanged: () async -> Void
  public var postAppMenuBarStateChanged: () async -> Void
  public var fullScreenMenuBarVisibilityChanged: @Sendable () async -> AsyncStream<Void>
  public var menuBarHidingChanged: @Sendable () async -> AsyncStream<Void>
  public var appMenuBarStateChanged: @Sendable () async -> AsyncStream<Void>
  public var didActivateApplication: @Sendable () async -> AsyncStream<Void>
  public var didTerminateApplication: @Sendable () async -> AsyncStream<String?>
  public var settingsWindowWillClose: @Sendable () async -> AsyncStream<Void>
  public var applicationShouldTerminateLater: @Sendable () async -> AsyncStream<Void>
}

extension Notifications {
  public static let live = Self(
    postFullScreenMenuBarVisibilityChanged: {
      DistributedNotificationCenter.default.post(
        name: .AppleInterfaceFullScreenMenuBarVisibilityChangedNotification,
        object: Bundle.main.bundleIdentifier
      )
    },
    postMenuBarHidingChanged: {
      DistributedNotificationCenter.default.post(
        name: .AppleInterfaceMenuBarHidingChangedNotification,
        object: Bundle.main.bundleIdentifier
      )
    },
    postAppMenuBarStateChanged: {
      NotificationCenter.default.post(
        name: .AppleInterfaceFullScreenMenuBarVisibilityOrMenuBarHidingHidingChangedNotification,
        object: Bundle.main.bundleIdentifier
      )
    },
    fullScreenMenuBarVisibilityChanged: { @MainActor in
      AsyncStream(
        DistributedNotificationCenter.default()
          .notifications(named: .AppleInterfaceFullScreenMenuBarVisibilityChangedNotification)
          .compactMap { ($0.object as? String) == Bundle.main.bundleIdentifier ? nil : () }
      )
    },
    menuBarHidingChanged: { @MainActor in
      AsyncStream(
        DistributedNotificationCenter.default()
          .notifications(named: .AppleInterfaceMenuBarHidingChangedNotification)
          .compactMap { ($0.object as? String) == Bundle.main.bundleIdentifier ? nil : () }
      )
    },
    appMenuBarStateChanged: { @MainActor in
      AsyncStream(
        NotificationCenter.default
          .notifications(
            named:
              .AppleInterfaceFullScreenMenuBarVisibilityOrMenuBarHidingHidingChangedNotification
          )
          .map { _ in }
      )
    },
    didActivateApplication: { @MainActor in
      AsyncStream(
        NSWorkspace.shared.notificationCenter
          .notifications(named: NSWorkspace.didActivateApplicationNotification).map { _ in }
      )
    },
    didTerminateApplication: { @MainActor in
      AsyncStream(
        NSWorkspace.shared.notificationCenter
          .notifications(named: NSWorkspace.didTerminateApplicationNotification)
          .map {
            let app = $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication

            return app?.bundleIdentifier
          }
      )
    },
    settingsWindowWillClose: { @MainActor in
      AsyncStream(
        NotificationCenter.default.notifications(named: NSWindow.willCloseNotification)
          .compactMap {
            guard let window = $0.object as? NSWindow, await !window.title.isEmpty else {
              return nil
            }

            return ()
          }
      )
    },
    applicationShouldTerminateLater: { @MainActor in
      AsyncStream(
        NotificationCenter.default
          .notifications(named: NSApplication.applicationShouldTerminateLater).map { _ in }
      )
    }
  )
}

extension Notifications {
  public static let unimplemented = Self(
    postFullScreenMenuBarVisibilityChanged: XCTUnimplemented(
      "\(Self.self).postFullScreenMenuBarVisibilityChanged"
    ),
    postMenuBarHidingChanged: XCTUnimplemented("\(Self.self).postMenuBarHidingChanged"),
    postAppMenuBarStateChanged: XCTUnimplemented("\(Self.self).postAppMenuBarStateChanged"),
    fullScreenMenuBarVisibilityChanged: XCTUnimplemented(
      "\(Self.self).fullScreenMenuBarVisibilityChanged",
      placeholder: AsyncStream.never
    ),
    menuBarHidingChanged: XCTUnimplemented(
      "\(Self.self).menuBarHidingChanged",
      placeholder: AsyncStream.never
    ),
    appMenuBarStateChanged: XCTUnimplemented(
      "\(Self.self).appMenuBarStateChanged",
      placeholder: AsyncStream.never
    ),
    didActivateApplication: XCTUnimplemented(
      "\(Self.self).didActivateApplication",
      placeholder: AsyncStream.never
    ),
    didTerminateApplication: XCTUnimplemented(
      "\(Self.self).didTerminateApplication",
      placeholder: AsyncStream.never
    ),
    settingsWindowWillClose: XCTUnimplemented(
      "\(Self.self).settingsWindowWillClose",
      placeholder: AsyncStream.never
    ),
    applicationShouldTerminateLater: XCTUnimplemented(
      "\(Self.self).applicationShouldTerminateLater",
      placeholder: AsyncStream.never
    )

  )
}

extension Notification: @unchecked Sendable {}
extension NotificationCenter.Notifications: @unchecked Sendable {}

extension Notification.Name {
  public static var AppleInterfaceFullScreenMenuBarVisibilityChangedNotification: Notification.Name
  { Self.init("AppleInterfaceFullScreenMenuBarVisibilityChangedNotification") }

  public static var AppleInterfaceMenuBarHidingChangedNotification: Notification.Name {
    Self.init("AppleInterfaceMenuBarHidingChangedNotification")
  }

  public static
    var AppleInterfaceFullScreenMenuBarVisibilityOrMenuBarHidingHidingChangedNotification:
    Notification.Name
  { Self.init("AppleInterfaceFullScreenMenuBarVisibilityOrMenuBarHidingHidingChangedNotification") }
}

extension NSApplication {
  public static var applicationShouldTerminateLater: Notification.Name {
    Notification.Name("applicationShouldTerminateLater")
  }
}
