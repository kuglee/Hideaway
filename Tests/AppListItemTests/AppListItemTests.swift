import AppMenuBarSaveState
import ComposableArchitecture
import MenuBarSettingsManager
import MenuBarState
import Notifications
import XCTest

@testable import AppListItem

@MainActor final class AppListItemTests: XCTestCase {
  func testMenuBarStateReselectSameState() async {
    let store = TestStore(
      initialState: AppListItemReducer.State(
        menuBarSaveState: .init(bundleIdentifier: "com.example.App1", state: .never),
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
      ),
      reducer: AppListItemReducer()
    )

    await store.send(.menuBarStateSelected(state: .never))
  }

  func testMenuBarStateSelectedStateDoesNotEqualSavedState() async {
    let appStates = ActorIsolated([String: [String: String]]())
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostMenuBarHidingChanged = ActorIsolated(false)
    let didGetRunningApps = ActorIsolated(false)

    let store = TestStore(
      initialState: AppListItemReducer.State(
        menuBarSaveState: .init(bundleIdentifier: "com.example.App1"),
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
      ),
      reducer: AppListItemReducer()
    )

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      "com.example.App1"
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

    await store.send(.menuBarStateSelected(state: .never)) {
      $0.menuBarSaveState = .init(bundleIdentifier: "com.example.App1", state: .never)
    }

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

  func testSetAppMenuBarStateError() async {
    let appStates = ActorIsolated([String: [String: String]]())
    let didSetAppMenuBarState = ActorIsolated(false)
    let didGetRunningApps = ActorIsolated(false)
    let didLog = ActorIsolated(false)

    let store = TestStore(
      initialState: AppListItemReducer.State(
        menuBarSaveState: .init(bundleIdentifier: "com.example.App1"),
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
      ),
      reducer: AppListItemReducer()
    )

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      "com.example.App1"
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

    let task = await store.send(.menuBarStateSelected(state: .never)) {
      $0.menuBarSaveState = .init(bundleIdentifier: "com.example.App1", state: .never)
    }

    await store.receive(.saveMenuBarStateFailed(oldState: .systemDefault)) {
      $0.menuBarSaveState = .init(bundleIdentifier: "com.example.App1", state: .systemDefault)
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
    await didGetRunningApps.withValue { XCTAssertTrue($0) }
    await didLog.withValue { XCTAssertTrue($0) }
  }
}
