import ComposableArchitecture
import MenuBarSettingsManager
import MenuBarState
import XCTest

@testable import AppFeature

@MainActor final class AppFeatureTests: XCTestCase {
  func testGotAppMenuBarStateSuccess() async {
    let store = TestStore(
      initialState: AppState(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: appReducer,
      environment: .unimplemented
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
      initialState: AppState(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.log = { _ in await didLog.setValue(true) }

    let task = await store.send(.gotAppMenuBarState(.failure(error)))

    await task.finish()

    await didLog.withValue { XCTAssertTrue($0) }
  }

  func testDidSetAppMenuBarStateSuccess() async {
    let store = TestStore(
      initialState: AppState(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: appReducer,
      environment: .unimplemented
    )

    let task = await store.send(.didSetAppMenuBarState(.success(unit)))

    await task.finish()
  }

  func testDidSetAppMenuBarStateError() async {
    let error = MenuBarSettingsManagerError.setError(message: "Set error")
    let didLog = ActorIsolated(false)

    let store = TestStore(
      initialState: AppState(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.log = { _ in await didLog.setValue(true) }

    let task = await store.send(.didSetAppMenuBarState(.failure(error)))

    await task.finish()

    await didLog.withValue { XCTAssertTrue($0) }
  }

  func testGotSystemMenuBarStateSuccess() async {
    let store = TestStore(
      initialState: AppState(
        systemMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: appReducer,
      environment: .unimplemented
    )

    let task = await store.send(
      .gotSystemMenuBarState(
        .success(.init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false))
      )
    )

    await task.finish()
  }

  func testGotSystemMenuBarStateError() async {
    let error = MenuBarSettingsManagerError.setError(message: "Set error")
    let didLog = ActorIsolated(false)

    let store = TestStore(
      initialState: AppState(
        systemMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.log = { _ in await didLog.setValue(true) }

    let task = await store.send(.gotSystemMenuBarState(.failure(error)))

    await task.finish()

    await didLog.withValue { XCTAssertTrue($0) }
  }

  func testDidSetSystemMenuBarStateSuccess() async {
    let store = TestStore(
      initialState: AppState(
        systemMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: appReducer,
      environment: .unimplemented
    )

    let task = await store.send(.didSetSystemMenuBarState(.success(unit)))

    await task.finish()
  }

  func testDidSetSystemMenuBarStateError() async {
    let error = MenuBarSettingsManagerError.setError(message: "Set error")
    let didLog = ActorIsolated(false)

    let store = TestStore(
      initialState: AppState(
        systemMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.log = { _ in await didLog.setValue(true) }

    let task = await store.send(.didSetSystemMenuBarState(.failure(error)))

    await task.finish()

    await didLog.withValue { XCTAssertTrue($0) }
  }

  func testAppMenuBarStateSelectedWithOnlyFullScreenMenuBarVisibilityChange() async {
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)

    let store = TestStore(
      initialState: AppState(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.menuBarSettingsManager.setAppMenuBarState = { _ in unit }
    store.environment.postFullScreenMenuBarVisibilityChanged = {
      await didPostFullScreenMenuBarVisibilityChanged.setValue(true)
    }

    let task = await store.send(
      .appMenuBarStateSelected(
        state: .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: false)
      )
    ) { $0.appMenuBarState = .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: false) }

    await store.receive(.didSetAppMenuBarState(.success(unit)))

    await task.finish()

    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
  }

  func testAppMenuBarStateSelectedWithOnlyMenuBarHidingChange() async {
    let didPostMenuBarHidingChanged = ActorIsolated(false)

    let store = TestStore(
      initialState: AppState(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.menuBarSettingsManager.setAppMenuBarState = { _ in unit }
    store.environment.postMenuBarHidingChanged = {
      await didPostMenuBarHidingChanged.setValue(true)
    }

    let task = await store.send(
      .appMenuBarStateSelected(
        state: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: true)
      )
    ) { $0.appMenuBarState = .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: true) }

    await store.receive(.didSetAppMenuBarState(.success(unit)))

    await task.finish()

    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
  }

  func testAppMenuBarStateSelectedWithFullScreenMenuBarVisibilityAndMenuBarHidingChange() async {
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostMenuBarHidingChanged = ActorIsolated(false)

    let store = TestStore(
      initialState: AppState(
        appMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.menuBarSettingsManager.setAppMenuBarState = { _ in unit }
    store.environment.postFullScreenMenuBarVisibilityChanged = {
      await didPostFullScreenMenuBarVisibilityChanged.setValue(true)
    }
    store.environment.postMenuBarHidingChanged = {
      await didPostMenuBarHidingChanged.setValue(true)
    }

    let task = await store.send(
      .appMenuBarStateSelected(
        state: .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: true)
      )
    ) { $0.appMenuBarState = .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: true) }

    await store.receive(.didSetAppMenuBarState(.success(unit)))

    await task.finish()

    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
  }

  func testSystemMenuBarStateSelectedWithOnlyFullScreenMenuBarVisibilityChange() async {
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)

    let store = TestStore(
      initialState: AppState(
        systemMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.menuBarSettingsManager.setSystemMenuBarState = { _ in unit }
    store.environment.postFullScreenMenuBarVisibilityChanged = {
      await didPostFullScreenMenuBarVisibilityChanged.setValue(true)
    }

    let task = await store.send(
      .systemMenuBarStateSelected(
        state: .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: false)
      )
    ) {
      $0.systemMenuBarState = .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: false)
    }

    await store.receive(.didSetSystemMenuBarState(.success(unit)))

    await task.finish()

    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
  }

  func testSystemMenuBarStateSelectedWithOnlyMenuBarHidingChange() async {
    let didPostMenuBarHidingChanged = ActorIsolated(false)

    let store = TestStore(
      initialState: AppState(
        systemMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.menuBarSettingsManager.setSystemMenuBarState = { _ in unit }
    store.environment.postMenuBarHidingChanged = {
      await didPostMenuBarHidingChanged.setValue(true)
    }

    let task = await store.send(
      .systemMenuBarStateSelected(
        state: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: true)
      )
    ) {
      $0.systemMenuBarState = .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: true)
    }

    await store.receive(.didSetSystemMenuBarState(.success(unit)))

    await task.finish()

    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
  }

  func testSystemMenuBarStateSelectedWithFullScreenMenuBarVisibilityAndMenuBarHidingChange() async {
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostMenuBarHidingChanged = ActorIsolated(false)

    let store = TestStore(
      initialState: AppState(
        systemMenuBarState: .init(menuBarVisibleInFullScreen: false, hideMenuBarOnDesktop: false)
      ),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.menuBarSettingsManager.setSystemMenuBarState = { _ in unit }
    store.environment.postFullScreenMenuBarVisibilityChanged = {
      await didPostFullScreenMenuBarVisibilityChanged.setValue(true)
    }
    store.environment.postMenuBarHidingChanged = {
      await didPostMenuBarHidingChanged.setValue(true)
    }

    let task = await store.send(
      .systemMenuBarStateSelected(
        state: .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: true)
      )
    ) {
      $0.systemMenuBarState = .init(menuBarVisibleInFullScreen: true, hideMenuBarOnDesktop: true)
    }

    await store.receive(.didSetSystemMenuBarState(.success(unit)))

    await task.finish()

    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
  }

  func testFullScreenMenuBarVisibilityChanged() async {
    let (fullScreenMenuBarVisibilityChanged, changeFullScreenMenuBarVisibility) = AsyncStream<
      Notification
    >
    .streamWithContinuation()

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.fullScreenMenuBarVisibilityChanged = {
      AsyncStream(
        fullScreenMenuBarVisibilityChanged.compactMap {
          ($0.object as? String) == Bundle.main.bundleIdentifier ? nil : ()
        }
      )
    }
    store.environment.menuBarHidingChanged = { AsyncStream.never }
    store.environment.didActivateApplication = { AsyncStream.never }

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
    let (fullScreenMenuBarVisibilityChanged, changeFullScreenMenuBarVisibility) = AsyncStream<
      Notification
    >
    .streamWithContinuation()

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.fullScreenMenuBarVisibilityChanged = {
      AsyncStream(
        fullScreenMenuBarVisibilityChanged.compactMap {
          ($0.object as? String) == Bundle.main.bundleIdentifier ? nil : ()
        }
      )
    }
    store.environment.menuBarHidingChanged = { AsyncStream.never }
    store.environment.didActivateApplication = { AsyncStream.never }
    store.environment.menuBarSettingsManager.getAppMenuBarState = { .never }
    store.environment.menuBarSettingsManager.getSystemMenuBarState = { .never }

    let notification = Notification(name: .init(""))

    let task = await store.send(.task)

    changeFullScreenMenuBarVisibility.yield(notification)

    await store.receive(.fullScreenMenuBarVisibilityChangedNotification)
    await store.receive(.gotAppMenuBarState(.success(.never))) { $0.appMenuBarState = .never }
    await store.receive(.gotSystemMenuBarState(.success(.never))) { $0.systemMenuBarState = .never }

    await task.cancel()

    changeFullScreenMenuBarVisibility.yield(notification)
  }

  func testMenuBarHidingChanged() async {
    let (menuBarHidingChanged, changeMenuBarHiding) = AsyncStream<Notification>
      .streamWithContinuation()

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.menuBarHidingChanged = {
      AsyncStream(
        menuBarHidingChanged.compactMap {
          ($0.object as? String) == Bundle.main.bundleIdentifier ? nil : ()
        }
      )
    }
    store.environment.fullScreenMenuBarVisibilityChanged = { AsyncStream.never }
    store.environment.didActivateApplication = { AsyncStream.never }

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
    let (menuBarHidingChanged, changeMenuBarHiding) = AsyncStream<Notification>
      .streamWithContinuation()

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.menuBarHidingChanged = {
      AsyncStream(
        menuBarHidingChanged.compactMap {
          ($0.object as? String) == Bundle.main.bundleIdentifier ? nil : ()
        }
      )
    }
    store.environment.fullScreenMenuBarVisibilityChanged = { AsyncStream.never }
    store.environment.didActivateApplication = { AsyncStream.never }
    store.environment.menuBarSettingsManager.getAppMenuBarState = { .never }
    store.environment.menuBarSettingsManager.getSystemMenuBarState = { .never }

    let notification = Notification(name: .init(""))

    let task = await store.send(.task)

    changeMenuBarHiding.yield(notification)

    await store.receive(.menuBarHidingChangedNotification)
    await store.receive(.gotAppMenuBarState(.success(.never))) { $0.appMenuBarState = .never }
    await store.receive(.gotSystemMenuBarState(.success(.never))) { $0.systemMenuBarState = .never }

    await task.cancel()

    changeMenuBarHiding.yield(notification)
  }

  func testDidActivateApplication() async {
    let (didActivateApplication, activateApplication) = AsyncStream<Notification>
      .streamWithContinuation()

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.didActivateApplication = { AsyncStream(didActivateApplication.map { _ in }) }
    store.environment.menuBarSettingsManager.getAppMenuBarState = { .never }
    store.environment.fullScreenMenuBarVisibilityChanged = { AsyncStream.never }
    store.environment.menuBarHidingChanged = { AsyncStream.never }

    let notification = Notification(
      name: Notification.Name(""),
      object: Bundle.main.bundleIdentifier
    )

    let task = await store.send(.task)

    activateApplication.yield(notification)

    await store.receive(.didActivateApplication)
    await store.receive(.gotAppMenuBarState(.success(.never))) { $0.appMenuBarState = .never }

    await task.cancel()

    activateApplication.yield(notification)
  }

  func testQuitButtonPressed() async {
    let didTerminate = ActorIsolated(false)
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.terminate = { await didTerminate.setValue(true) }

    let task = await store.send(.quitButtonPressed)

    await task.finish()

    await didTerminate.withValue { XCTAssertTrue($0) }
  }

  func testViewAppeared() async {
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.menuBarSettingsManager.getAppMenuBarState = { .never }
    store.environment.menuBarSettingsManager.getSystemMenuBarState = { .never }

    let task = await store.send(.viewAppeared)

    await store.receive(.gotAppMenuBarState(.success(.never))) { $0.appMenuBarState = .never }
    await store.receive(.gotSystemMenuBarState(.success(.never))) { $0.systemMenuBarState = .never }

    await task.finish()
  }

  func testTask() async {
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: .unimplemented
    )

    store.environment.fullScreenMenuBarVisibilityChanged = { AsyncStream.never }
    store.environment.menuBarHidingChanged = { AsyncStream.never }
    store.environment.didActivateApplication = { AsyncStream.never }

    let task = await store.send(.task)

    await task.cancel()
  }
}
