import AppMenuBarSaveState
import ComposableArchitecture
import MenuBarSettingsManager
import MenuBarState
import Notifications
import XCTest

@testable import AppListItem

@MainActor final class AppListItemTests: XCTestCase {
  func testMenuBarStateSelectedStateDoesNotEqualSavedState() async {
    let appStates = ActorIsolated([String: [String: String]]())
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostMenuBarHidingChanged = ActorIsolated(false)
    let didGetRunningApps = ActorIsolated(false)

    let store = TestStore(
      initialState: AppListItem.State(
        menuBarSaveState: .init(
          bundleIdentifier: "com.example.App1",
          bundleURL: URL(string: "/Applications/App1.app/")!
        ),
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
      ),
      reducer: AppListItem()
    )

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      AppInfo(
        bundleIdentifier: "com.example.App1",
        bundleURL: URL(string: "/Applications/App1.app/")!
      )
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarState = { _, _ in
      await didSetAppMenuBarState.setValue(true)
    }
    store.dependencies.notifications.postFullScreenMenuBarVisibilityChanged = {
      await didPostFullScreenMenuBarVisibilityChanged.setValue(true)
    }
    store.dependencies.notifications.postMenuBarHidingChanged = {
      await didPostMenuBarHidingChanged.setValue(true)
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await appStates.setValue([:])
      return nil
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarStates = { _ in
      var states = await appStates.value
      states["com.example.App1"] = [
        "bundlePath": "/Applications/App1.app/", "state": MenuBarState.always.stringValue,
      ]
      await appStates.setValue(states)
    }
    store.dependencies.appListItemEnvironment.getRunningApps = {
      await didGetRunningApps.setValue(true)
      return ["com.example.App1"]
    }

    let task = await store.send(.menuBarStateSelected(state: .never))

    await store.receive(.didSaveMenuBarState(.success(.never))) {
      $0.menuBarSaveState = .init(
        bundleIdentifier: "com.example.App1",
        bundleURL: URL(string: "/Applications/App1.app/")!,
        state: .never
      )
    }

    await task.finish()

    await appStates.withValue {
      XCTAssertEqual(
        $0,
        [
          "com.example.App1": [
            "bundlePath": "/Applications/App1.app/", "state": MenuBarState.always.stringValue,
          ]
        ]
      )
    }
    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
    await didGetRunningApps.withValue { XCTAssertTrue($0) }
  }

  func testMenuBarStateSelectedStateEqualsSavedState() async {
    let appStates = ActorIsolated([String: [String: String]]())
    let didSetAppMenuBarState = ActorIsolated(false)
    let didGetRunningApps = ActorIsolated(false)

    let store = TestStore(
      initialState: AppListItem.State(
        menuBarSaveState: .init(
          bundleIdentifier: "com.example.App1",
          bundleURL: URL(string: "/Applications/App1.app/")!,
          state: .never
        ),
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
      ),
      reducer: AppListItem()
    )

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      AppInfo(
        bundleIdentifier: "com.example.App1",
        bundleURL: URL(string: "/Applications/App1.app/")!
      )
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarState = { _, _ in
      await didSetAppMenuBarState.setValue(true)
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await appStates.setValue([:])
      return nil
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarStates = { _ in
      var states = await appStates.value
      states["com.example.App1"] = [
        "bundlePath": "/Applications/App1.app/", "state": MenuBarState.never.stringValue,
      ]
      await appStates.setValue(states)
    }
    store.dependencies.appListItemEnvironment.getRunningApps = {
      await didGetRunningApps.setValue(true)
      return ["com.example.App1"]
    }

    let task = await store.send(.menuBarStateSelected(state: .never))

    await store.receive(.didSaveMenuBarState(.success(.never)))

    await task.finish()

    await appStates.withValue {
      XCTAssertEqual(
        $0,
        [
          "com.example.App1": [
            "bundlePath": "/Applications/App1.app/", "state": MenuBarState.never.stringValue,
          ]
        ]
      )
    }
    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didGetRunningApps.withValue { XCTAssertTrue($0) }
  }

  func testMenuBarStateSelectedSaveStateDoesNotExist() async {
    let appStates = ActorIsolated([String: [String: String]]())
    let didGetRunningApps = ActorIsolated(false)

    let store = TestStore(
      initialState: AppListItem.State(
        menuBarSaveState: .init(
          bundleIdentifier: "com.example.App1",
          bundleURL: URL(string: "/Applications/App1.app/")!,
          state: .never
        ),
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
      ),
      reducer: AppListItem()
    )

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      AppInfo(
        bundleIdentifier: "com.example.App1",
        bundleURL: URL(string: "/Applications/App1.app/")!
      )
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await appStates.setValue([:])
      return nil
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarStates = { _ in
      var states = await appStates.value
      states["com.example.App1"] = [
        "bundlePath": "/Applications/App1.app/", "state": MenuBarState.never.stringValue,
      ]
      await appStates.setValue(states)
    }
    store.dependencies.appListItemEnvironment.getRunningApps = {
      await didGetRunningApps.setValue(true)
      return []
    }

    let task = await store.send(.menuBarStateSelected(state: .never))

    await store.receive(.didSaveMenuBarState(.success(.never)))

    await task.finish()

    await appStates.withValue {
      XCTAssertEqual(
        $0,
        [
          "com.example.App1": [
            "bundlePath": "/Applications/App1.app/", "state": MenuBarState.never.stringValue,
          ]
        ]
      )
    }
    await didGetRunningApps.withValue { XCTAssertTrue($0) }
  }

  func testSetAppMenuBarStateError() async {
    let appStates = ActorIsolated([String: [String: String]]())
    let didSetAppMenuBarState = ActorIsolated(false)
    let didGetRunningApps = ActorIsolated(false)
    let didLog = ActorIsolated(false)

    let store = TestStore(
      initialState: AppListItem.State(
        menuBarSaveState: .init(
          bundleIdentifier: "com.example.App1",
          bundleURL: URL(string: "/Applications/App1.app/")!
        ),
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
      ),
      reducer: AppListItem()
    )

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      AppInfo(
        bundleIdentifier: "com.example.App1",
        bundleURL: URL(string: "/Applications/App1.app/")!
      )
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarState = { _, _ in
      await didSetAppMenuBarState.setValue(true)

      throw MenuBarSettingsManagerError.appError(message: "Test error")
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await appStates.setValue([:])
      return nil
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarStates = { _ in
      var states = await appStates.value
      states["com.example.App1"] = [
        "bundlePath": "/Applications/App1.app/", "state": MenuBarState.always.stringValue,
      ]
      await appStates.setValue(states)
    }
    store.dependencies.appListItemEnvironment.getRunningApps = {
      await didGetRunningApps.setValue(true)
      return ["com.example.App1"]
    }
    store.dependencies.appListItemEnvironment.log = { _ in await didLog.setValue(true) }

    let task = await store.send(.menuBarStateSelected(state: .never))

    await store.receive(.didSaveMenuBarState(.success(.never))) {
      $0.menuBarSaveState = .init(
        bundleIdentifier: "com.example.App1",
        bundleURL: URL(string: "/Applications/App1.app/")!,
        state: .never
      )
    }
    await store.receive(
      .didSaveMenuBarState(
        TaskResult.failure(MenuBarSettingsManagerError.appError(message: "Test error"))
      )
    )

    await task.finish()

    await appStates.withValue {
      XCTAssertEqual(
        $0,
        [
          "com.example.App1": [
            "bundlePath": "/Applications/App1.app/", "state": MenuBarState.always.stringValue,
          ]
        ]
      )
    }
    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didGetRunningApps.withValue { XCTAssertTrue($0) }
    await didLog.withValue { XCTAssertTrue($0) }
  }
}
