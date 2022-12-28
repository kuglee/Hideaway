import ComposableArchitecture
import MenuBarSettingsManager
import MenuBarState
import XCTest

@testable import AppFeature

@MainActor final class AppFeatureTests: XCTestCase {
  func testAppMenuBarStateReselect() async {
    let store = TestStore(
      initialState: AppFeatureReducer.State(appMenuBarState: .never),
      reducer: AppFeatureReducer()
    )

    await store.send(.appMenuBarStateSelected(state: .never))
  }

  func testAppMenuBarStateSelectedAppStatesDoesNotExist() async {
    let appStates = ActorIsolated([String: [String: String]]())
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostAppMenuBarStateChanged = ActorIsolated(false)

    let store = TestStore(
      initialState: AppFeatureReducer.State(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeatureReducer()
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
    store.dependencies.notifications.postAppMenuBarStateChanged = {
      await didPostAppMenuBarStateChanged.setValue(true)
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

    await store.send(.appMenuBarStateSelected(state: .never)) { $0.appMenuBarState = .never }

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
    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didPostAppMenuBarStateChanged.withValue { XCTAssertTrue($0) }
  }

  func testAppMenuBarStateSelectedAppStatesExist() async {
    let appStates = ActorIsolated([String: [String: String]]())
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostAppMenuBarStateChanged = ActorIsolated(false)

    let store = TestStore(
      initialState: AppFeatureReducer.State(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeatureReducer()
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
    store.dependencies.notifications.postAppMenuBarStateChanged = {
      await didPostAppMenuBarStateChanged.setValue(true)
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await appStates.setValue([
        "com.example.App1": [
          "bundlePath": "/Applications/App1.app/", "state": MenuBarState.always.stringValue,
        ]
      ])
      return nil
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarStates = { _ in
      var states = await appStates.value
      states["com.example.App2"] = [
        "bundlePath": "/Applications/App2.app/", "state": MenuBarState.never.stringValue,
      ]

      await appStates.setValue(states)
    }

    await store.send(.appMenuBarStateSelected(state: .never)) { $0.appMenuBarState = .never }

    await appStates.withValue {
      XCTAssertEqual(
        $0,
        [
          "com.example.App1": [
            "bundlePath": "/Applications/App1.app/", "state": MenuBarState.always.stringValue,
          ],
          "com.example.App2": [
            "bundlePath": "/Applications/App2.app/", "state": MenuBarState.never.stringValue,
          ],
        ]

      )
    }
    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didPostAppMenuBarStateChanged.withValue { XCTAssertTrue($0) }
  }

  func testAppMenuBarStateSelectedError() async {
    let didSetAppMenuBarState = ActorIsolated(false)
    let didLog = ActorIsolated(false)

    let store = TestStore(initialState: AppFeatureReducer.State(), reducer: AppFeatureReducer())

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      "com.example.App1"
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarState = { _, _ in
      await didSetAppMenuBarState.setValue(true)

      throw MenuBarSettingsManagerError.appError(message: "Test error")
    }
    store.dependencies.appFeatureEnvironment.log = { _ in await didLog.setValue(true) }

    let task = await store.send(.appMenuBarStateSelected(state: .never)) {
      $0.appMenuBarState = .never
    }

    await store.receive(.saveAppMenuBarStateFailed(oldState: .systemDefault)) {
      $0.appMenuBarState = .systemDefault
    }

    await task.finish()

    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didLog.withValue { XCTAssertTrue($0) }
  }

  func testAppMenuBarStateSelectedWithOnlyFullScreenMenuBarVisibilityChange() async {
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostAppMenuBarStateChanged = ActorIsolated(false)
    let didGetAppMenuBarStates = ActorIsolated(false)
    let didSetAppMenuBarStates = ActorIsolated(false)

    let store = TestStore(
      initialState: AppFeatureReducer.State(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeatureReducer()
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
    store.dependencies.notifications.postAppMenuBarStateChanged = {
      await didPostAppMenuBarStateChanged.setValue(true)
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await didGetAppMenuBarStates.setValue(true)
      return nil
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarStates = { _ in
      await didSetAppMenuBarStates.setValue(true)
    }

    await store.send(
      .appMenuBarStateSelected(
        state: .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: false)
      )
    ) { $0.appMenuBarState = .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: false) }

    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didPostAppMenuBarStateChanged.withValue { XCTAssertTrue($0) }
    await didGetAppMenuBarStates.withValue { XCTAssertTrue($0) }
    await didSetAppMenuBarStates.withValue { XCTAssertTrue($0) }
  }

  func testAppMenuBarStateSelectedWithOnlyMenuBarHidingChange() async {
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostMenuBarHidingChanged = ActorIsolated(false)
    let didPostAppMenuBarStateChanged = ActorIsolated(false)
    let didGetAppMenuBarStates = ActorIsolated(false)
    let didSetAppMenuBarStates = ActorIsolated(false)

    let store = TestStore(
      initialState: AppFeatureReducer.State(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeatureReducer()
    )

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      "com.example.App1"
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarState = { _, _ in
      await didSetAppMenuBarState.setValue(true)
    }
    store.dependencies.notifications.postMenuBarHidingChanged = {
      await didPostMenuBarHidingChanged.setValue(true)
    }
    store.dependencies.notifications.postAppMenuBarStateChanged = {
      await didPostAppMenuBarStateChanged.setValue(true)
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await didGetAppMenuBarStates.setValue(true)
      return nil
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarStates = { _ in
      await didSetAppMenuBarStates.setValue(true)
    }

    await store.send(
      .appMenuBarStateSelected(
        state: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: true)
      )
    ) { $0.appMenuBarState = .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: true) }

    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
    await didPostAppMenuBarStateChanged.withValue { XCTAssertTrue($0) }
    await didGetAppMenuBarStates.withValue { XCTAssertTrue($0) }
    await didSetAppMenuBarStates.withValue { XCTAssertTrue($0) }
  }

  func testAppMenuBarStateSelectedWithFullScreenMenuBarVisibilityAndMenuBarHidingChange() async {
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostMenuBarHidingChanged = ActorIsolated(false)
    let didPostAppMenuBarStateChanged = ActorIsolated(false)
    let didGetAppMenuBarStates = ActorIsolated(false)
    let didSetAppMenuBarStates = ActorIsolated(false)

    let store = TestStore(
      initialState: AppFeatureReducer.State(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeatureReducer()
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
    store.dependencies.notifications.postAppMenuBarStateChanged = {
      await didPostAppMenuBarStateChanged.setValue(true)
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await didGetAppMenuBarStates.setValue(true)
      return nil
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarStates = { _ in
      await didSetAppMenuBarStates.setValue(true)
    }

    await store.send(
      .appMenuBarStateSelected(
        state: .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: true)
      )
    ) { $0.appMenuBarState = .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: true) }

    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
    await didPostAppMenuBarStateChanged.withValue { XCTAssertTrue($0) }
    await didGetAppMenuBarStates.withValue { XCTAssertTrue($0) }
    await didSetAppMenuBarStates.withValue { XCTAssertTrue($0) }
  }

  func testSystemMenuBarStateReselect() async {
    let store = TestStore(
      initialState: AppFeatureReducer.State(systemMenuBarState: .never),
      reducer: AppFeatureReducer()
    )

    await store.send(.systemMenuBarStateSelected(state: .never))
  }

  func testSystemMenuBarStateSelectedWithOnlyFullScreenMenuBarVisibilityChange() async {
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didSetSystemMenuBarState = ActorIsolated(false)

    let store = TestStore(
      initialState: AppFeatureReducer.State(
        systemMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeatureReducer()
    )

    store.dependencies.menuBarSettingsManager.setSystemMenuBarState = { _ in
      await didSetSystemMenuBarState.setValue(true)
    }
    store.dependencies.notifications.postFullScreenMenuBarVisibilityChanged = {
      await didPostFullScreenMenuBarVisibilityChanged.setValue(true)
    }

    let task = await store.send(
      .systemMenuBarStateSelected(
        state: .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: false)
      )
    ) {
      $0.systemMenuBarState = .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: false)
    }

    await task.finish()

    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didSetSystemMenuBarState.withValue { XCTAssertTrue($0) }
  }

  func testSystemMenuBarStateSelectedWithOnlyMenuBarHidingChange() async {
    let didPostMenuBarHidingChanged = ActorIsolated(false)
    let didSetSystemMenuBarState = ActorIsolated(false)

    let store = TestStore(
      initialState: AppFeatureReducer.State(
        systemMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeatureReducer()
    )

    store.dependencies.menuBarSettingsManager.setSystemMenuBarState = { _ in
      await didSetSystemMenuBarState.setValue(true)
    }
    store.dependencies.notifications.postMenuBarHidingChanged = {
      await didPostMenuBarHidingChanged.setValue(true)
    }

    let task = await store.send(
      .systemMenuBarStateSelected(
        state: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: true)
      )
    ) {
      $0.systemMenuBarState = .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: true)
    }

    await task.finish()

    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
    await didSetSystemMenuBarState.withValue { XCTAssertTrue($0) }
  }

  func testSystemMenuBarStateSelectedWithFullScreenMenuBarVisibilityAndMenuBarHidingChange() async {
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostMenuBarHidingChanged = ActorIsolated(false)
    let didSetSystemMenuBarState = ActorIsolated(false)

    let store = TestStore(
      initialState: AppFeatureReducer.State(
        systemMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeatureReducer()
    )

    store.dependencies.menuBarSettingsManager.setSystemMenuBarState = { _ in
      await didSetSystemMenuBarState.setValue(true)
    }
    store.dependencies.notifications.postFullScreenMenuBarVisibilityChanged = {
      await didPostFullScreenMenuBarVisibilityChanged.setValue(true)
    }
    store.dependencies.notifications.postMenuBarHidingChanged = {
      await didPostMenuBarHidingChanged.setValue(true)
    }

    let task = await store.send(
      .systemMenuBarStateSelected(
        state: .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: true)
      )
    ) {
      $0.systemMenuBarState = .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: true)
    }

    await task.finish()

    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
    await didSetSystemMenuBarState.withValue { XCTAssertTrue($0) }
  }

  func testFullScreenMenuBarVisibilityChanged() async {
    let (fullScreenMenuBarVisibilityChanged, changeFullScreenMenuBarVisibility) = AsyncStream<Void>
      .streamWithContinuation()

    let store = TestStore(initialState: AppFeatureReducer.State(), reducer: AppFeatureReducer())

    store.dependencies.notifications.fullScreenMenuBarVisibilityChanged = {
      AsyncStream(fullScreenMenuBarVisibilityChanged.compactMap { nil })
    }
    store.dependencies.notifications.menuBarHidingChanged = { AsyncStream.never }
    store.dependencies.notifications.didActivateApplication = { AsyncStream.never }
    store.dependencies.notifications.didTerminateApplication = { AsyncStream.never }

    let task = await store.send(.task)

    changeFullScreenMenuBarVisibility.yield()

    await task.cancel()

    changeFullScreenMenuBarVisibility.yield()
  }

  func testFullScreenMenuBarVisibilityChangedFromOutside() async {
    let didGetBundleIdentifierOfCurrentApp = ActorIsolated(false)
    let (fullScreenMenuBarVisibilityChanged, changeFullScreenMenuBarVisibility) = AsyncStream<Void>
      .streamWithContinuation()

    let store = TestStore(initialState: AppFeatureReducer.State(), reducer: AppFeatureReducer())

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      await didGetBundleIdentifierOfCurrentApp.setValue(true)

      return "com.example.App1"
    }
    store.dependencies.notifications.fullScreenMenuBarVisibilityChanged = {
      AsyncStream(fullScreenMenuBarVisibilityChanged.map { _ in })
    }
    store.dependencies.notifications.menuBarHidingChanged = { AsyncStream.never }
    store.dependencies.notifications.didActivateApplication = { AsyncStream.never }
    store.dependencies.notifications.didTerminateApplication = { AsyncStream.never }
    store.dependencies.menuBarSettingsManager.getAppMenuBarState = { _ in .never }
    store.dependencies.menuBarSettingsManager.getSystemMenuBarState = { .never }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      ["com.example.App1": MenuBarState.never.stringValue]
    }

    let task = await store.send(.task)

    changeFullScreenMenuBarVisibility.yield()

    await store.receive(.fullScreenMenuBarVisibilityChangedNotification)
    await store.receive(.gotAppMenuBarState(.never)) { $0.appMenuBarState = .never }
    await store.receive(.gotSystemMenuBarState(.never)) { $0.systemMenuBarState = .never }

    await task.cancel()

    await didGetBundleIdentifierOfCurrentApp.withValue { XCTAssertTrue($0) }

    changeFullScreenMenuBarVisibility.yield()
  }

  func testMenuBarHidingChanged() async {
    let (menuBarHidingChanged, changeMenuBarHiding) = AsyncStream<Void>.streamWithContinuation()

    let store = TestStore(initialState: AppFeatureReducer.State(), reducer: AppFeatureReducer())

    store.dependencies.notifications.menuBarHidingChanged = {
      AsyncStream(menuBarHidingChanged.compactMap { nil })
    }
    store.dependencies.notifications.fullScreenMenuBarVisibilityChanged = { AsyncStream.never }
    store.dependencies.notifications.didActivateApplication = { AsyncStream.never }
    store.dependencies.notifications.didTerminateApplication = { AsyncStream.never }

    let task = await store.send(.task)

    changeMenuBarHiding.yield()

    await task.cancel()

    changeMenuBarHiding.yield()
  }

  func testMenuBarHidingChangedFromOutside() async {
    let didGetBundleIdentifierOfCurrentApp = ActorIsolated(false)

    let (menuBarHidingChanged, changeMenuBarHiding) = AsyncStream<Void>.streamWithContinuation()

    let store = TestStore(initialState: AppFeatureReducer.State(), reducer: AppFeatureReducer())

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      await didGetBundleIdentifierOfCurrentApp.setValue(true)

      return "com.example.App1"
    }
    store.dependencies.notifications.menuBarHidingChanged = {
      AsyncStream(menuBarHidingChanged.map { _ in })
    }
    store.dependencies.notifications.fullScreenMenuBarVisibilityChanged = { AsyncStream.never }
    store.dependencies.notifications.didActivateApplication = { AsyncStream.never }
    store.dependencies.notifications.didTerminateApplication = { AsyncStream.never }
    store.dependencies.menuBarSettingsManager.getAppMenuBarState = { _ in .never }
    store.dependencies.menuBarSettingsManager.getSystemMenuBarState = { .never }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      ["com.example.App1": MenuBarState.never.stringValue]
    }

    let task = await store.send(.task)

    changeMenuBarHiding.yield()

    await store.receive(.menuBarHidingChangedNotification)
    await store.receive(.gotAppMenuBarState(.never)) { $0.appMenuBarState = .never }
    await store.receive(.gotSystemMenuBarState(.never)) { $0.systemMenuBarState = .never }

    await task.cancel()

    await didGetBundleIdentifierOfCurrentApp.withValue { XCTAssertTrue($0) }

    changeMenuBarHiding.yield()
  }

  func testDidActivateApplicationStateDoesNotEqualSavedState() async {
    let didGetBundleIdentifierOfCurrentApp = ActorIsolated(false)
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostMenuBarHidingChanged = ActorIsolated(false)

    let (didActivateApplication, activateApplication) = AsyncStream<Void>.streamWithContinuation()

    let store = TestStore(initialState: AppFeatureReducer.State(), reducer: AppFeatureReducer())

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      await didGetBundleIdentifierOfCurrentApp.setValue(true)

      return "com.example.App1"
    }
    store.dependencies.notifications.didActivateApplication = {
      AsyncStream(didActivateApplication.map { _ in })
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarState = { _ in .systemDefault }
    store.dependencies.menuBarSettingsManager.setAppMenuBarState = { _, _ in
      await didSetAppMenuBarState.setValue(true)
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      ["com.example.App1": MenuBarState.never.stringValue]
    }
    store.dependencies.notifications.postFullScreenMenuBarVisibilityChanged = {
      await didPostFullScreenMenuBarVisibilityChanged.setValue(true)
    }
    store.dependencies.notifications.postMenuBarHidingChanged = {
      await didPostMenuBarHidingChanged.setValue(true)
    }
    store.dependencies.notifications.fullScreenMenuBarVisibilityChanged = { AsyncStream.never }
    store.dependencies.notifications.menuBarHidingChanged = { AsyncStream.never }
    store.dependencies.notifications.didTerminateApplication = { AsyncStream.never }

    let task = await store.send(.task)

    activateApplication.yield()

    await store.receive(.didActivateApplication)
    await store.receive(.gotAppMenuBarState(.never)) { $0.appMenuBarState = .never }

    await task.cancel()

    await didGetBundleIdentifierOfCurrentApp.withValue { XCTAssertTrue($0) }
    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }

    activateApplication.yield()
  }

  func testDidActivateApplicationStateEqualsSavedStateButDoesNotEqualAppMenuBarState() async {
    let didGetBundleIdentifierOfCurrentApp = ActorIsolated(false)

    let (didActivateApplication, activateApplication) = AsyncStream<Void>.streamWithContinuation()

    let store = TestStore(initialState: AppFeatureReducer.State(), reducer: AppFeatureReducer())

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      await didGetBundleIdentifierOfCurrentApp.setValue(true)

      return "com.example.App1"
    }
    store.dependencies.notifications.didActivateApplication = {
      AsyncStream(didActivateApplication.map { _ in })
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarState = { _ in .never }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      ["com.example.App1": MenuBarState.never.stringValue]
    }
    store.dependencies.notifications.fullScreenMenuBarVisibilityChanged = { AsyncStream.never }
    store.dependencies.notifications.menuBarHidingChanged = { AsyncStream.never }
    store.dependencies.notifications.didTerminateApplication = { AsyncStream.never }

    let task = await store.send(.task)

    activateApplication.yield()

    await store.receive(.didActivateApplication)
    await store.receive(.gotAppMenuBarState(.never)) { $0.appMenuBarState = .never }

    await task.cancel()

    await didGetBundleIdentifierOfCurrentApp.withValue { XCTAssertTrue($0) }

    activateApplication.yield()
  }

  func testDidActivateApplicationStateEqualsSavedStateAndAppMenuBarState() async {
    let didGetBundleIdentifierOfCurrentApp = ActorIsolated(false)

    let (didActivateApplication, activateApplication) = AsyncStream<Void>.streamWithContinuation()

    let store = TestStore(
      initialState: AppFeatureReducer.State(appMenuBarState: .never),
      reducer: AppFeatureReducer()
    )

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      await didGetBundleIdentifierOfCurrentApp.setValue(true)

      return "com.example.App1"
    }
    store.dependencies.notifications.didActivateApplication = {
      AsyncStream(didActivateApplication.map { _ in })
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarState = { _ in .never }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      ["com.example.App1": MenuBarState.never.stringValue]
    }
    store.dependencies.notifications.fullScreenMenuBarVisibilityChanged = { AsyncStream.never }
    store.dependencies.notifications.menuBarHidingChanged = { AsyncStream.never }
    store.dependencies.notifications.didTerminateApplication = { AsyncStream.never }

    let task = await store.send(.task)

    activateApplication.yield()

    await store.receive(.didActivateApplication)

    await task.cancel()

    await didGetBundleIdentifierOfCurrentApp.withValue { XCTAssertTrue($0) }

    activateApplication.yield()
  }

  func testDidActivateApplicationNoSavedStates() async {
    let didGetBundleIdentifierOfCurrentApp = ActorIsolated(false)

    let (didActivateApplication, activateApplication) = AsyncStream<Void>.streamWithContinuation()

    let store = TestStore(initialState: AppFeatureReducer.State(), reducer: AppFeatureReducer())

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      await didGetBundleIdentifierOfCurrentApp.setValue(true)

      return "com.example.App1"
    }
    store.dependencies.notifications.didActivateApplication = {
      AsyncStream(didActivateApplication.map { _ in })
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarState = { _ in .systemDefault }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = { [:] }
    store.dependencies.notifications.fullScreenMenuBarVisibilityChanged = { AsyncStream.never }
    store.dependencies.notifications.menuBarHidingChanged = { AsyncStream.never }
    store.dependencies.notifications.didTerminateApplication = { AsyncStream.never }

    let task = await store.send(.task)

    activateApplication.yield()

    await store.receive(.didActivateApplication)

    await task.cancel()

    await didGetBundleIdentifierOfCurrentApp.withValue { XCTAssertTrue($0) }

    activateApplication.yield()
  }

  func testViewAppearedAppStatesDoesNotExist() async {
    let didGetBundleIdentifierOfCurrentApp = ActorIsolated(false)
    let didGetAppMenuBarStates = ActorIsolated(false)
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostMenuBarHidingChanged = ActorIsolated(false)

    let store = TestStore(initialState: AppFeatureReducer.State(), reducer: AppFeatureReducer())

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      await didGetBundleIdentifierOfCurrentApp.setValue(true)

      return "com.example.App1"
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await didGetAppMenuBarStates.setValue(true)

      return [:]
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarState = { _ in .never }
    store.dependencies.menuBarSettingsManager.setAppMenuBarState = { _, _ in
      await didSetAppMenuBarState.setValue(true)
    }
    store.dependencies.menuBarSettingsManager.getSystemMenuBarState = { .never }
    store.dependencies.notifications.postFullScreenMenuBarVisibilityChanged = {
      await didPostFullScreenMenuBarVisibilityChanged.setValue(true)
    }
    store.dependencies.notifications.postMenuBarHidingChanged = {
      await didPostMenuBarHidingChanged.setValue(true)
    }

    let task = await store.send(.viewAppeared)

    await store.receive(.gotSystemMenuBarState(.never)) { $0.systemMenuBarState = .never }

    await task.finish()

    await didGetBundleIdentifierOfCurrentApp.withValue { XCTAssertTrue($0) }
    await didGetAppMenuBarStates.withValue { XCTAssertTrue($0) }
    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
  }

  func testViewAppearedAppStatesExistStateEqualsCurrentState() async {
    let didGetBundleIdentifierOfCurrentApp = ActorIsolated(false)
    let didGetAppMenuBarStates = ActorIsolated(false)

    let store = TestStore(initialState: AppFeatureReducer.State(), reducer: AppFeatureReducer())

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      await didGetBundleIdentifierOfCurrentApp.setValue(true)

      return "com.example.App1"
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await didGetAppMenuBarStates.setValue(true)

      return ["com.example.App1": MenuBarState.never.stringValue]
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarState = { _ in .never }
    store.dependencies.menuBarSettingsManager.getSystemMenuBarState = { .never }

    let task = await store.send(.viewAppeared)

    await store.receive(.gotSystemMenuBarState(.never)) { $0.systemMenuBarState = .never }
    await store.receive(.gotAppMenuBarState(.never)) { $0.appMenuBarState = .never }

    await task.finish()

    await didGetBundleIdentifierOfCurrentApp.withValue { XCTAssertTrue($0) }
    await didGetAppMenuBarStates.withValue { XCTAssertTrue($0) }
  }

  func testViewAppearedAppStatesExistStateDoesNotEqualCurrentState() async {
    let didGetBundleIdentifierOfCurrentApp = ActorIsolated(false)
    let didGetAppMenuBarStates = ActorIsolated(false)
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostMenuBarHidingChanged = ActorIsolated(false)

    let store = TestStore(initialState: AppFeatureReducer.State(), reducer: AppFeatureReducer())

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      await didGetBundleIdentifierOfCurrentApp.setValue(true)

      return "com.example.App1"
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await didGetAppMenuBarStates.setValue(true)

      return ["com.example.App1": MenuBarState.always.stringValue]
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
    store.dependencies.menuBarSettingsManager.getAppMenuBarState = { _ in .never }
    store.dependencies.menuBarSettingsManager.getSystemMenuBarState = { .never }

    let task = await store.send(.viewAppeared)

    await store.receive(.gotSystemMenuBarState(.never)) { $0.systemMenuBarState = .never }
    await store.receive(.gotAppMenuBarState(.always)) { $0.appMenuBarState = .always }

    await task.finish()

    await didGetBundleIdentifierOfCurrentApp.withValue { XCTAssertTrue($0) }
    await didGetAppMenuBarStates.withValue { XCTAssertTrue($0) }
    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
  }

  func testTask() async {
    let store = TestStore(initialState: AppFeatureReducer.State(), reducer: AppFeatureReducer())

    store.dependencies.notifications.fullScreenMenuBarVisibilityChanged = { AsyncStream.never }
    store.dependencies.notifications.menuBarHidingChanged = { AsyncStream.never }
    store.dependencies.notifications.didActivateApplication = { AsyncStream.never }
    store.dependencies.notifications.didTerminateApplication = { AsyncStream.never }

    let task = await store.send(.task)

    await task.cancel()
  }

  func testSettingsButtonPressed() async {
    let didOpenSettings = ActorIsolated(false)

    let store = TestStore(initialState: AppFeatureReducer.State(), reducer: AppFeatureReducer())

    store.dependencies.appFeatureEnvironment.openSettings = { await didOpenSettings.setValue(true) }

    await store.send(.settingsButtonPressed)

    await didOpenSettings.withValue { XCTAssertTrue($0) }
  }
}
