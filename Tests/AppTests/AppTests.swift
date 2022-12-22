import ComposableArchitecture
import MenuBarState
import XCTest
import XCTestDynamicOverlay

@testable import App

@MainActor final class AppTests: XCTestCase {
  func testOnAppearDidRunBefore() async {
    let store = TestStore(initialState: AppReducer.State(didRunBefore: true), reducer: AppReducer())

    await store.send(.onAppear)
  }

  func testOnAppearDidNotRunBefore() async {
    let didOpenSettings = ActorIsolated(false)
    var didSetDidRunBefore = false

    let store = TestStore(initialState: AppReducer.State(), reducer: AppReducer())

    store.dependencies.appEnvironment.openSettings = { await didOpenSettings.setValue(true) }
    store.dependencies.menuBarSettingsManager.setDidRunBefore = { _ in didSetDidRunBefore = true }

    let task = await store.send(.onAppear)

    await store.receive(.openSettingsWindow)

    await store.send(.dismissWelcomeSheet) { $0.didRunBefore = true }

    await task.finish()

    await didOpenSettings.withValue { XCTAssertTrue($0) }
    XCTAssertTrue(didSetDidRunBefore)
  }

  func testQuitButtonPressedNoStates() async {
    let didGetAppMenuBarStates = ActorIsolated(false)
    let didTerminate = ActorIsolated(false)

    let store = TestStore(initialState: AppReducer.State(), reducer: AppReducer())

    store.dependencies.appEnvironment.applicationShouldTerminate = {
      await didTerminate.setValue(true)
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await didGetAppMenuBarStates.setValue(true)

      return [:]
    }
    store.dependencies.notifications.fullScreenMenuBarVisibilityChanged = { AsyncStream.never }
    store.dependencies.notifications.menuBarHidingChanged = { AsyncStream.never }
    store.dependencies.notifications.didActivateApplication = { AsyncStream.never }
    store.dependencies.notifications.didTerminateApplication = { AsyncStream.never }

    await store.send(.applicationTerminated)

    await didGetAppMenuBarStates.withValue { XCTAssertTrue($0) }
    await didTerminate.withValue { XCTAssertTrue($0) }
  }

  func testQuitButtonPressedStateEqualsSystemDefault() async {
    let didGetAppMenuBarStates = ActorIsolated(false)
    let didTerminate = ActorIsolated(false)

    let store = TestStore(initialState: AppReducer.State(), reducer: AppReducer())

    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await didGetAppMenuBarStates.setValue(true)

      return ["com.example.App1": MenuBarState.systemDefault.stringValue]
    }
    store.dependencies.appEnvironment.applicationShouldTerminate = {
      await didTerminate.setValue(true)
    }

    await store.send(.applicationTerminated)

    await didGetAppMenuBarStates.withValue { XCTAssertTrue($0) }
    await didTerminate.withValue { XCTAssertTrue($0) }
  }

  func testQuitButtonPressedStateDoesNotEqualSystemDefault() async {
    let didGetAppMenuBarStates = ActorIsolated(false)
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostMenuBarHidingChanged = ActorIsolated(false)
    let didTerminate = ActorIsolated(false)

    let store = TestStore(initialState: AppReducer.State(), reducer: AppReducer())

    store.dependencies.notifications.postFullScreenMenuBarVisibilityChanged = {
      await didPostFullScreenMenuBarVisibilityChanged.setValue(true)
    }
    store.dependencies.notifications.postMenuBarHidingChanged = {
      await didPostMenuBarHidingChanged.setValue(true)
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarState = { _, _ in
      await didSetAppMenuBarState.setValue(true)
    }

    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await didGetAppMenuBarStates.setValue(true)

      return ["com.example.App1": MenuBarState.never.stringValue]
    }
    store.dependencies.appEnvironment.applicationShouldTerminate = {
      await didTerminate.setValue(true)
    }

    await store.send(.applicationTerminated)

    await didGetAppMenuBarStates.withValue { XCTAssertTrue($0) }
    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
    await didTerminate.withValue { XCTAssertTrue($0) }
  }
}
