import AppFeature
import ComposableArchitecture
import MenuBarSettingsManager
import SettingsFeature
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
}
