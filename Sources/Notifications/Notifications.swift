import AppKit
import ComposableArchitecture
import Foundation
import XCTestDynamicOverlay

public struct Notifications {
  public var postFullScreenMenuBarVisibilityChanged: () async -> Void
  public var postMenuBarHidingChanged: () async -> Void
  public var fullScreenMenuBarVisibilityChanged: @Sendable () async -> AsyncStream<Void>
  public var menuBarHidingChanged: @Sendable () async -> AsyncStream<Void>
  public var didActivateApplication: @Sendable () async -> AsyncStream<Void>
  public var didTerminateApplication: @Sendable () async -> AsyncStream<String?>
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
    }
  )
}

extension Notifications {
  public static let unimplemented = Self(
    postFullScreenMenuBarVisibilityChanged: XCTUnimplemented(
      "\(Self.self).postFullScreenMenuBarVisibilityChanged"
    ),
    postMenuBarHidingChanged: XCTUnimplemented("\(Self.self).postMenuBarHidingChanged"),
    fullScreenMenuBarVisibilityChanged: XCTUnimplemented(
      "\(Self.self).fullScreenMenuBarVisibilityChanged",
      placeholder: AsyncStream.never
    ),
    menuBarHidingChanged: XCTUnimplemented(
      "\(Self.self).menuBarHidingChanged",
      placeholder: AsyncStream.never
    ),
    didActivateApplication: XCTUnimplemented(
      "\(Self.self).didActivateApplication",
      placeholder: AsyncStream.never
    ),
    didTerminateApplication: XCTUnimplemented(
      "\(Self.self).didTerminateApplication",
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
}
