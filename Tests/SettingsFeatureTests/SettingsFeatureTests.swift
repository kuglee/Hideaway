import AppList
import AppListItem
import ComposableArchitecture
import MenuBarState
import XCTest

@testable import SettingsFeature

@MainActor final class SettingsFeatureTests: XCTestCase {
  func testChangeAppMenuBarState() async {
    let (appMenuBarStateChanged, changeAppMenuBarState) = AsyncStream<Void>.streamWithContinuation()
    let (settingsWindowWillCloseFinished, _) = AsyncStream<Void>.streamWithContinuation()
    let (settingsWindowDidBecomeMainFinished, _) = AsyncStream<Void>.streamWithContinuation()
    let didSetAccessoryActivationPolicy = ActorIsolated(false)
    var didGetUrlForApplication = false

    let store = TestStore(
      initialState: SettingsFeatureReducer.State(),
      reducer: SettingsFeatureReducer()
    )

    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      [
        "com.example.App1": MenuBarState.never.stringValue,
        "com.example.App2": MenuBarState.always.stringValue,
      ]
    }
    store.dependencies.notifications.appMenuBarStateChanged = {
      AsyncStream(appMenuBarStateChanged.compactMap { nil })
    }
    store.dependencies.notifications.settingsWindowWillClose = {
      AsyncStream(settingsWindowWillCloseFinished.map { _ in })
    }
    store.dependencies.settingsFeatureEnvironment.setAccessoryActivationPolicy = {
      await didSetAccessoryActivationPolicy.setValue(true)
    }
    store.dependencies.uuid = .incrementing
    store.dependencies.notifications.settingsWindowDidBecomeMain = {
      AsyncStream(settingsWindowDidBecomeMainFinished.map { _ in })
    }
    store.dependencies.menuBarSettingsManager.getUrlForApplication = {
      didGetUrlForApplication = true

      return URL.init(filePath: $0)
    }

    let task = await store.send(.task)

    changeAppMenuBarState.yield()

    await store.receive(.gotAppList(["com.example.App1": "never", "com.example.App2": "always"])) {
      var appListItems: IdentifiedArrayOf<AppListItemReducer.State> = .init(uniqueElements: [
        .init(
          menuBarSaveState: .init(bundleIdentifier: "com.example.App1", state: .never),
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        ),
        .init(
          menuBarSaveState: .init(bundleIdentifier: "com.example.App2", state: .always),
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        ),
      ])

      appListItems.sort()

      $0.appList = AppListReducer.State(appListItems: appListItems)
    }

    XCTAssertTrue(didGetUrlForApplication)

    await task.cancel()

    changeAppMenuBarState.yield()
  }

  func testSettingsWindowWillClose() async {
    let (appMenuBarStateChanged, _) = AsyncStream<Void>.streamWithContinuation()
    let (settingsWindowWillCloseFinished, settingsWindowWillClose) = AsyncStream<Void>
      .streamWithContinuation()
    let (settingsWindowDidBecomeMainFinished, _) = AsyncStream<Void>.streamWithContinuation()
    let didSetAccessoryActivationPolicy = ActorIsolated(false)

    let store = TestStore(
      initialState: SettingsFeatureReducer.State(),
      reducer: SettingsFeatureReducer()
    )

    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = { [:] }
    store.dependencies.notifications.appMenuBarStateChanged = {
      AsyncStream(appMenuBarStateChanged.compactMap { nil })
    }
    store.dependencies.notifications.settingsWindowWillClose = {
      AsyncStream(settingsWindowWillCloseFinished.map { _ in })
    }
    store.dependencies.settingsFeatureEnvironment.setAccessoryActivationPolicy = {
      await didSetAccessoryActivationPolicy.setValue(true)
    }
    store.dependencies.uuid = .incrementing
    store.dependencies.notifications.settingsWindowDidBecomeMain = {
      AsyncStream(settingsWindowDidBecomeMainFinished.map { _ in })
    }
    store.dependencies.menuBarSettingsManager.getUrlForApplication = { _ in
      return URL.init(filePath: "")
    }

    let task = await store.send(.task)

    await store.receive(.gotAppList([:]))

    settingsWindowWillClose.yield()

    await store.receive(.settingsWindowWillClose)
    await didSetAccessoryActivationPolicy.withValue { XCTAssertTrue($0) }

    await task.cancel()

    settingsWindowWillClose.yield()
  }

  func testSettingsWindowDidBecomeMain() async {
    let (appMenuBarStateChanged, _) = AsyncStream<Void>.streamWithContinuation()
    let (settingsWindowWillCloseFinished, _) = AsyncStream<Void>.streamWithContinuation()
    let (settingsWindowDidBecomeMainFinished, settingsWindowDidBecomeMain) = AsyncStream<Void>
      .streamWithContinuation()
    let didSetAccessoryActivationPolicy = ActorIsolated(false)
    var didGetUrlForApplication = false

    let store = TestStore(
      initialState: SettingsFeatureReducer.State(),
      reducer: SettingsFeatureReducer()
    )

    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      [
        "com.example.App1": MenuBarState.never.stringValue,
        "com.example.App2": MenuBarState.always.stringValue,
      ]
    }
    store.dependencies.notifications.appMenuBarStateChanged = {
      AsyncStream(appMenuBarStateChanged.compactMap { nil })
    }
    store.dependencies.notifications.settingsWindowWillClose = {
      AsyncStream(settingsWindowWillCloseFinished.map { _ in })
    }
    store.dependencies.settingsFeatureEnvironment.setAccessoryActivationPolicy = {
      await didSetAccessoryActivationPolicy.setValue(true)
    }
    store.dependencies.uuid = .incrementing
    store.dependencies.notifications.settingsWindowDidBecomeMain = {
      AsyncStream(settingsWindowDidBecomeMainFinished.map { _ in })
    }
    store.dependencies.menuBarSettingsManager.getUrlForApplication = {
      didGetUrlForApplication = true

      return URL.init(filePath: $0)
    }

    let task = await store.send(.task)

    settingsWindowDidBecomeMain.yield()

    await store.receive(.gotAppList(["com.example.App1": "never", "com.example.App2": "always"])) {
      var appListItems: IdentifiedArrayOf<AppListItemReducer.State> = .init(uniqueElements: [
        .init(
          menuBarSaveState: .init(bundleIdentifier: "com.example.App1", state: .never),
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        ),
        .init(
          menuBarSaveState: .init(bundleIdentifier: "com.example.App2", state: .always),
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        ),
      ])

      appListItems.sort()

      $0.appList = AppListReducer.State(appListItems: appListItems)
    }

    await store.receive(.gotAppList(["com.example.App1": "never", "com.example.App2": "always"]))

    XCTAssertTrue(didGetUrlForApplication)

    await task.cancel()

    settingsWindowDidBecomeMain.yield()
  }
}
