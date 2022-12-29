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
  public var didActivateApplication: @Sendable () async -> AsyncStream<String?>
  public var didTerminateApplication: @Sendable () async -> AsyncStream<String?>
  public var settingsWindowWillClose: @Sendable () async -> AsyncStream<Void>
  public var settingsWindowDidBecomeMain: @Sendable () async -> AsyncStream<Void>
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
    fullScreenMenuBarVisibilityChanged: {
      AsyncStream {
        DistributedNotificationCenter.default()
          .notifications(named: .AppleInterfaceFullScreenMenuBarVisibilityChangedNotification)
          .compactMap { ($0.object as? String) == Bundle.main.bundleIdentifier ? nil : () }
      }
    },
    menuBarHidingChanged: {
      AsyncStream {
        DistributedNotificationCenter.default()
          .notifications(named: .AppleInterfaceMenuBarHidingChangedNotification)
          .compactMap { ($0.object as? String) == Bundle.main.bundleIdentifier ? nil : () }
      }
    },
    appMenuBarStateChanged: {
      AsyncStream {
        NotificationCenter.default
          .notifications(
            named:
              .AppleInterfaceFullScreenMenuBarVisibilityOrMenuBarHidingHidingChangedNotification
          )
          .map { _ in }
      }
    },
    didActivateApplication: {
      AsyncStream {
        NSWorkspace.shared.notificationCenter
          .notifications(named: NSWorkspace.didActivateApplicationNotification)
          .map {
            let app = $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication

            return app?.bundleIdentifier
          }
      }
    },
    didTerminateApplication: {
      AsyncStream {
        NSWorkspace.shared.notificationCenter
          .notifications(named: NSWorkspace.didTerminateApplicationNotification)
          .map {
            let app = $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication

            return app?.bundleIdentifier
          }
      }
    },
    settingsWindowWillClose: {
      AsyncStream {
        await NotificationCenter.default.notifications(named: NSWindow.willCloseNotification)
          .compactMap {
            guard let window = $0.object as? NSWindow,
              await window.identifier?.rawValue == "com_apple_SwiftUI_Settings_window"
            else { return nil }

            return ()
          }
      }
    },
    settingsWindowDidBecomeMain: {
      AsyncStream {
        await NotificationCenter.default.notifications(named: NSWindow.didBecomeMainNotification)
          .compactMap {
            guard let window = $0.object as? NSWindow,
              await window.identifier?.rawValue == "com_apple_SwiftUI_Settings_window"
            else { return nil }

            return ()
          }
      }
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
    settingsWindowDidBecomeMain: XCTUnimplemented(
      "\(Self.self).settingsWindowDidBecomeMain",
      placeholder: AsyncStream.never
    )
  )
}

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

// Conformance of 'Notification' to 'Sendable' is unavailable
// (from https://github.com/pointfreeco/swift-composable-architecture/discussions/1727)
extension AsyncStream {
  public init<S: AsyncSequence>(
    bufferingPolicy limit: Continuation.BufferingPolicy = .unbounded,
    @_implicitSelfCapture @_inheritActorContext _ makeUnderlyingSequence: @escaping @Sendable ()
      async -> S
  ) where S.Element == Element {
    self.init(bufferingPolicy: limit) { (continuation: Continuation) in
      let task = Task {
        do {
          for try await element in await makeUnderlyingSequence() { continuation.yield(element) }
        } catch {}
        continuation.finish()
      }
      continuation.onTermination =
        { _ in task.cancel() }
        // NB: This explicit cast is needed to work around a compiler bug in Swift 5.5.2
        as @Sendable (Continuation.Termination) -> Void
    }
  }
}
