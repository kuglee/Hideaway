import AppMenuBarSaveState
import ComposableArchitecture
import MenuBarSettingsManager
import MenuBarState
import XCTest

@testable import AppFeature

@MainActor final class AppFeatureTests: XCTestCase {
  func testGotAppMenuBarStateSuccess() async {
    let store = TestStore(
      initialState: AppFeature.State(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeature()
    )

    let task = await store.send(
      .gotAppMenuBarState(
        .success(.init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false))
      )
    )

    await task.finish()
  }

  func testGotAppMenuBarStateError() async {
    let error = MenuBarSettingsManagerError.setError(message: "Set error")
    let didLog = ActorIsolated(false)

    let store = TestStore(
      initialState: AppFeature.State(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeature()
    )

    store.dependencies.appEnvironment.log = { _ in await didLog.setValue(true) }

    let task = await store.send(.gotAppMenuBarState(.failure(error)))

    await task.finish()

    await didLog.withValue { XCTAssertTrue($0) }
  }

  func testAppMenuBarStateSelectedAppStatesDoesNotExist() async {
    let appStates = ActorIsolated([String: [String: Bool]]())
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)

    let store = TestStore(
      initialState: AppFeature.State(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeature()
    )

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = { "test" }
    store.dependencies.menuBarSettingsManager.setAppMenuBarState = { _, _ in
      await didSetAppMenuBarState.setValue(true)
    }
    store.dependencies.notifications.postFullScreenMenuBarVisibilityChanged = {
      await didPostFullScreenMenuBarVisibilityChanged.setValue(true)
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await appStates.setValue([:])
      return nil
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarStates = { _ in
      var states = await appStates.value
      states["test"] = MenuBarState.never.dictValue
      await appStates.setValue(states)
    }

    let task = await store.send(.appMenuBarStateSelected(state: .never))

    await store.receive(
      .didSaveAppMenuBarState(
        .success(AppMenuBarSaveState(bundleIdentifier: "test", state: .never))
      )
    ) { $0.appMenuBarState = .never }

    await task.finish()

    await appStates.withValue { XCTAssertEqual($0, ["test": MenuBarState.never.dictValue]) }
    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
  }

  func testAppMenuBarStateSelectedAppStatesExist() async {
    let appStates = ActorIsolated([String: [String: Bool]]())
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)

    let store = TestStore(
      initialState: AppFeature.State(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeature()
    )

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = { "test" }
    store.dependencies.menuBarSettingsManager.setAppMenuBarState = { _, _ in
      await didSetAppMenuBarState.setValue(true)
    }
    store.dependencies.notifications.postFullScreenMenuBarVisibilityChanged = {
      await didPostFullScreenMenuBarVisibilityChanged.setValue(true)
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await appStates.setValue(["app1": MenuBarState.always.dictValue])
      return nil
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarStates = { _ in
      var states = await appStates.value
      states["test"] = MenuBarState.never.dictValue
      await appStates.setValue(states)
    }

    let task = await store.send(.appMenuBarStateSelected(state: .never))

    await store.receive(
      .didSaveAppMenuBarState(
        .success(AppMenuBarSaveState(bundleIdentifier: "test", state: .never))
      )
    ) { $0.appMenuBarState = .never }

    await task.finish()

    await appStates.withValue {
      XCTAssertEqual(
        $0,
        ["app1": MenuBarState.always.dictValue, "test": MenuBarState.never.dictValue]
      )
    }
    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
  }

  func testDidSetAppMenuBarStateError() async {
    let error = MenuBarSettingsManagerError.setError(message: "Set error")
    let didLog = ActorIsolated(false)

    let store = TestStore(
      initialState: AppFeature.State(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeature()
    )

    store.dependencies.appEnvironment.log = { _ in await didLog.setValue(true) }

    let task = await store.send(.didSaveAppMenuBarState(.failure(error)))

    await task.finish()

    await didLog.withValue { XCTAssertTrue($0) }
  }

  func testAppMenuBarStateSelectedWithOnlyFullScreenMenuBarVisibilityChange() async {
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didGetAppMenuBarStates = ActorIsolated(false)
    let didSetAppMenuBarStates = ActorIsolated(false)

    let store = TestStore(
      initialState: AppFeature.State(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeature()
    )

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = { "test" }
    store.dependencies.menuBarSettingsManager.setAppMenuBarState = { _, _ in
      await didSetAppMenuBarState.setValue(true)
    }
    store.dependencies.notifications.postFullScreenMenuBarVisibilityChanged = {
      await didPostFullScreenMenuBarVisibilityChanged.setValue(true)
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await didGetAppMenuBarStates.setValue(true)
      return nil
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarStates = { _ in
      await didSetAppMenuBarStates.setValue(true)
    }

    let task = await store.send(
      .appMenuBarStateSelected(
        state: .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: false)
      )
    )

    await store.receive(
      .didSaveAppMenuBarState(
        .success(
          AppMenuBarSaveState(
            bundleIdentifier: "test",
            state: .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: false)
          )
        )
      )
    ) { $0.appMenuBarState = .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: false) }

    await task.finish()

    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didGetAppMenuBarStates.withValue { XCTAssertTrue($0) }
    await didSetAppMenuBarStates.withValue { XCTAssertTrue($0) }
  }

  func testAppMenuBarStateSelectedWithOnlyMenuBarHidingChange() async {
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostMenuBarHidingChanged = ActorIsolated(false)
    let didGetAppMenuBarStates = ActorIsolated(false)
    let didSetAppMenuBarStates = ActorIsolated(false)

    let store = TestStore(
      initialState: AppFeature.State(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeature()
    )

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = { "test" }
    store.dependencies.menuBarSettingsManager.setAppMenuBarState = { _, _ in
      await didSetAppMenuBarState.setValue(true)
    }
    store.dependencies.notifications.postMenuBarHidingChanged = {
      await didPostMenuBarHidingChanged.setValue(true)
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await didGetAppMenuBarStates.setValue(true)
      return nil
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarStates = { _ in
      await didSetAppMenuBarStates.setValue(true)
    }

    let task = await store.send(
      .appMenuBarStateSelected(
        state: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: true)
      )
    )
    await store.receive(
      .didSaveAppMenuBarState(
        .success(
          AppMenuBarSaveState(
            bundleIdentifier: "test",
            state: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: true)
          )
        )
      )
    ) { $0.appMenuBarState = .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: true) }

    await task.finish()

    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
    await didGetAppMenuBarStates.withValue { XCTAssertTrue($0) }
    await didSetAppMenuBarStates.withValue { XCTAssertTrue($0) }
  }

  func testAppMenuBarStateSelectedWithFullScreenMenuBarVisibilityAndMenuBarHidingChange() async {
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostMenuBarHidingChanged = ActorIsolated(false)
    let didGetAppMenuBarStates = ActorIsolated(false)
    let didSetAppMenuBarStates = ActorIsolated(false)

    let store = TestStore(
      initialState: AppFeature.State(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeature()
    )

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = { "test" }
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
      await didGetAppMenuBarStates.setValue(true)
      return nil
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarStates = { _ in
      await didSetAppMenuBarStates.setValue(true)
    }

    let task = await store.send(
      .appMenuBarStateSelected(
        state: .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: true)
      )
    )

    await store.receive(
      .didSaveAppMenuBarState(
        .success(
          AppMenuBarSaveState(
            bundleIdentifier: "test",
            state: .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: true)
          )
        )
      )
    ) { $0.appMenuBarState = .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: true) }

    await task.finish()

    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
    await didGetAppMenuBarStates.withValue { XCTAssertTrue($0) }
    await didSetAppMenuBarStates.withValue { XCTAssertTrue($0) }
  }

  func testSystemMenuBarStateSelectedWithOnlyFullScreenMenuBarVisibilityChange() async {
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didSetSystemMenuBarState = ActorIsolated(false)

    let store = TestStore(
      initialState: AppFeature.State(
        systemMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeature()
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
      initialState: AppFeature.State(
        systemMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeature()
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
      initialState: AppFeature.State(
        systemMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: AppFeature()
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
    let (fullScreenMenuBarVisibilityChanged, changeFullScreenMenuBarVisibility) = AsyncStream<
      Notification
    >
    .streamWithContinuation()

    let store = TestStore(initialState: AppFeature.State(), reducer: AppFeature())

    store.dependencies.notifications.fullScreenMenuBarVisibilityChanged = {
      AsyncStream(
        fullScreenMenuBarVisibilityChanged.compactMap {
          ($0.object as? String) == Bundle.main.bundleIdentifier ? nil : ()
        }
      )
    }
    store.dependencies.notifications.menuBarHidingChanged = { AsyncStream.never }
    store.dependencies.notifications.didActivateApplication = { AsyncStream.never }

    let notification = Notification(
      name: Notification.Name(""),
      object: Bundle.main.bundleIdentifier
    )

    let task = await store.send(.task)

    changeFullScreenMenuBarVisibility.yield(notification)

    await task.cancel()

    changeFullScreenMenuBarVisibility.yield(notification)
  }

  func testFullScreenMenuBarVisibilityChangedFromOutside() async {
    let didGetBundleIdentifierOfCurrentApp = ActorIsolated(false)
    let (fullScreenMenuBarVisibilityChanged, changeFullScreenMenuBarVisibility) = AsyncStream<
      Notification
    >
    .streamWithContinuation()

    let store = TestStore(initialState: AppFeature.State(), reducer: AppFeature())

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      await didGetBundleIdentifierOfCurrentApp.setValue(true)
      return "test"
    }
    store.dependencies.notifications.fullScreenMenuBarVisibilityChanged = {
      AsyncStream(
        fullScreenMenuBarVisibilityChanged.compactMap {
          ($0.object as? String) == Bundle.main.bundleIdentifier ? nil : ()
        }
      )
    }
    store.dependencies.notifications.menuBarHidingChanged = { AsyncStream.never }
    store.dependencies.notifications.didActivateApplication = { AsyncStream.never }
    store.dependencies.menuBarSettingsManager.getAppMenuBarState = { _ in .never }
    store.dependencies.menuBarSettingsManager.getSystemMenuBarState = { .never }

    let notification = Notification(name: .init(""))

    let task = await store.send(.task)

    changeFullScreenMenuBarVisibility.yield(notification)

    await store.receive(.fullScreenMenuBarVisibilityChangedNotification)
    await store.receive(.gotAppMenuBarState(.success(.never))) { $0.appMenuBarState = .never }
    await store.receive(.gotSystemMenuBarState(.never)) { $0.systemMenuBarState = .never }

    await task.cancel()

    await didGetBundleIdentifierOfCurrentApp.withValue { XCTAssertTrue($0) }

    changeFullScreenMenuBarVisibility.yield(notification)
  }

  func testMenuBarHidingChanged() async {
    let (menuBarHidingChanged, changeMenuBarHiding) = AsyncStream<Notification>
      .streamWithContinuation()

    let store = TestStore(initialState: AppFeature.State(), reducer: AppFeature())

    store.dependencies.notifications.menuBarHidingChanged = {
      AsyncStream(
        menuBarHidingChanged.compactMap {
          ($0.object as? String) == Bundle.main.bundleIdentifier ? nil : ()
        }
      )
    }
    store.dependencies.notifications.fullScreenMenuBarVisibilityChanged = { AsyncStream.never }
    store.dependencies.notifications.didActivateApplication = { AsyncStream.never }

    let notification = Notification(
      name: Notification.Name(""),
      object: Bundle.main.bundleIdentifier
    )

    let task = await store.send(.task)

    changeMenuBarHiding.yield(notification)

    await task.cancel()

    changeMenuBarHiding.yield(notification)
  }

  func testMenuBarHidingChangedFromOutside() async {
    let didGetBundleIdentifierOfCurrentApp = ActorIsolated(false)

    let (menuBarHidingChanged, changeMenuBarHiding) = AsyncStream<Notification>
      .streamWithContinuation()

    let store = TestStore(initialState: AppFeature.State(), reducer: AppFeature())

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      await didGetBundleIdentifierOfCurrentApp.setValue(true)
      return "test"
    }
    store.dependencies.notifications.menuBarHidingChanged = {
      AsyncStream(
        menuBarHidingChanged.compactMap {
          ($0.object as? String) == Bundle.main.bundleIdentifier ? nil : ()
        }
      )
    }
    store.dependencies.notifications.fullScreenMenuBarVisibilityChanged = { AsyncStream.never }
    store.dependencies.notifications.didActivateApplication = { AsyncStream.never }
    store.dependencies.menuBarSettingsManager.getAppMenuBarState = { _ in .never }
    store.dependencies.menuBarSettingsManager.getSystemMenuBarState = { .never }

    let notification = Notification(name: .init(""))

    let task = await store.send(.task)

    changeMenuBarHiding.yield(notification)

    await store.receive(.menuBarHidingChangedNotification)
    await store.receive(.gotAppMenuBarState(.success(.never))) { $0.appMenuBarState = .never }
    await store.receive(.gotSystemMenuBarState(.never)) { $0.systemMenuBarState = .never }

    await task.cancel()

    await didGetBundleIdentifierOfCurrentApp.withValue { XCTAssertTrue($0) }

    changeMenuBarHiding.yield(notification)
  }

  func testDidActivateApplication() async {
    let didGetBundleIdentifierOfCurrentApp = ActorIsolated(false)

    let (didActivateApplication, activateApplication) = AsyncStream<Notification>
      .streamWithContinuation()

    let store = TestStore(initialState: AppFeature.State(), reducer: AppFeature())

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      await didGetBundleIdentifierOfCurrentApp.setValue(true)
      return "test"
    }
    store.dependencies.notifications.didActivateApplication = {
      AsyncStream(didActivateApplication.map { _ in })
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarState = { _ in .never }
    store.dependencies.notifications.fullScreenMenuBarVisibilityChanged = { AsyncStream.never }
    store.dependencies.notifications.menuBarHidingChanged = { AsyncStream.never }

    let notification = Notification(
      name: Notification.Name(""),
      object: Bundle.main.bundleIdentifier
    )

    let task = await store.send(.task)

    activateApplication.yield(notification)

    await store.receive(.didActivateApplication)
    await store.receive(.gotAppMenuBarState(.success(.never))) { $0.appMenuBarState = .never }

    await task.cancel()

    await didGetBundleIdentifierOfCurrentApp.withValue { XCTAssertTrue($0) }

    activateApplication.yield(notification)
  }

  func testQuitButtonPressed() async {
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostMenuBarHidingChanged = ActorIsolated(false)
    let didTerminate = ActorIsolated(false)

    let store = TestStore(initialState: AppFeature.State(), reducer: AppFeature())

    store.dependencies.notifications.postFullScreenMenuBarVisibilityChanged = {
      await didPostFullScreenMenuBarVisibilityChanged.setValue(true)
    }
    store.dependencies.notifications.postMenuBarHidingChanged = {
      await didPostMenuBarHidingChanged.setValue(true)
    }
    store.dependencies.appEnvironment.terminate = { await didTerminate.setValue(true) }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = { [:] }

    let task = await store.send(.quitButtonPressed)

    await task.finish()

    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
    await didTerminate.withValue { XCTAssertTrue($0) }
  }

  func testViewAppeared() async {
    let didGetBundleIdentifierOfCurrentApp = ActorIsolated(false)
    let didGetAppMenuBarStates = ActorIsolated(false)
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostMenuBarHidingChanged = ActorIsolated(false)

    let store = TestStore(initialState: AppFeature.State(), reducer: AppFeature())

    store.dependencies.menuBarSettingsManager.getBundleIdentifierOfCurrentApp = {
      await didGetBundleIdentifierOfCurrentApp.setValue(true)
      return "test"
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await didGetAppMenuBarStates.setValue(true)
      return [:]
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

    await store.receive(.gotAppMenuBarState(.success(.never))) { $0.appMenuBarState = .never }
    await store.receive(.gotSystemMenuBarState(.never)) { $0.systemMenuBarState = .never }

    await task.finish()

    await didGetBundleIdentifierOfCurrentApp.withValue { XCTAssertTrue($0) }
    await didGetAppMenuBarStates.withValue { XCTAssertTrue($0) }
    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
  }

  func testTask() async {
    let store = TestStore(initialState: AppFeature.State(), reducer: AppFeature())

    store.dependencies.notifications.fullScreenMenuBarVisibilityChanged = { AsyncStream.never }
    store.dependencies.notifications.menuBarHidingChanged = { AsyncStream.never }
    store.dependencies.notifications.didActivateApplication = { AsyncStream.never }

    let task = await store.send(.task)

    await task.cancel()
  }
}
