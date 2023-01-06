import ComposableArchitecture
import MenuBarState
import XCTest

@testable import AppList

@MainActor final class AppListTests: XCTestCase {
  func testAddButtonPressed() async {
    let store = TestStore(initialState: AppListReducer.State(), reducer: AppListReducer())

    await store.send(.addButtonPressed) { $0.isFileImporterPresented = true }
  }

  func testAppImportEmpty() async {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    var didGetUrlForApplication = false
    var didGetBundleDisplayName = false
    var didGetBundleIcon = false

    let store = TestStore(
      initialState: AppListReducer.State(appListItems: []),
      reducer: AppListReducer()
    )

    store.dependencies.uuid = UUIDGenerator { id }
    store.dependencies.menuBarSettingsManager.getUrlForApplication = {
      didGetUrlForApplication = true

      return URL.init(filePath: $0)
    }
    store.dependencies.menuBarSettingsManager.getBundleDisplayName = {
      didGetBundleDisplayName = true

      return $0.lastPathComponent
    }
    store.dependencies.menuBarSettingsManager.getBundleIcon = { _ in didGetBundleIcon = true
      return nil
    }

    let task = await store.send(.addButtonPressed) { $0.isFileImporterPresented = true }

    await store.send(.appImported(bundleIdentifier: "com.example.App1")) {
      $0.appListItems = .init(uniqueElements: [
        .init(
          menuBarSaveState: .init(bundleIdentifier: "com.example.App1"),
          id: id,
          appName: "com.example.App1"
        )
      ])
    }

    await task.finish()

    XCTAssertTrue(didGetUrlForApplication)
    XCTAssertTrue(didGetBundleDisplayName)
    XCTAssertTrue(didGetBundleIcon)
  }

  func testAppImportNotAlreadyImported() async {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    var didGetUrlForApplication = false
    var didGetBundleDisplayName = false
    var didGetBundleIcon = false

    let store = TestStore(
      initialState: AppListReducer.State(
        appListItems: .init(uniqueElements: [
          .init(
            menuBarSaveState: .init(bundleIdentifier: "com.example.App1"),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            appName: "com.example.App1"
          )
        ])
      ),
      reducer: AppListReducer()
    )

    store.dependencies.uuid = UUIDGenerator { id }
    store.dependencies.menuBarSettingsManager.getUrlForApplication = {
      didGetUrlForApplication = true

      return URL.init(filePath: $0)
    }
    store.dependencies.menuBarSettingsManager.getBundleDisplayName = {
      didGetBundleDisplayName = true

      return $0.lastPathComponent
    }
    store.dependencies.menuBarSettingsManager.getBundleIcon = { _ in didGetBundleIcon = true
      return nil
    }

    let task = await store.send(.addButtonPressed) { $0.isFileImporterPresented = true }

    await store.send(.appImported(bundleIdentifier: "com.example.App2")) {
      $0.appListItems = .init(uniqueElements: [
        .init(
          menuBarSaveState: .init(bundleIdentifier: "com.example.App1"),
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          appName: "com.example.App1"
        ),
        .init(
          menuBarSaveState: .init(bundleIdentifier: "com.example.App2"),
          id: id,
          appName: "com.example.App2"
        ),
      ])
    }

    await task.finish()

    XCTAssertTrue(didGetUrlForApplication)
    XCTAssertTrue(didGetBundleDisplayName)
    XCTAssertTrue(didGetBundleIcon)
  }

  func testAppImportAlreadyImported() async {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    let store = TestStore(
      initialState: AppListReducer.State(
        appListItems: .init(uniqueElements: [
          .init(
            menuBarSaveState: .init(bundleIdentifier: "com.example.App1"),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            appName: "App1"
          ),
          .init(
            menuBarSaveState: .init(bundleIdentifier: "com.example.App2"),
            id: id,
            appName: "App2"
          ),
        ])
      ),
      reducer: AppListReducer()
    )

    store.dependencies.uuid = UUIDGenerator { id }

    let task = await store.send(.addButtonPressed) { $0.isFileImporterPresented = true }

    await store.send(.appImported(bundleIdentifier: "com.example.App2"))

    await task.finish()
  }

  func testRemoveButtonPressedWithNoElementsSelected() async {
    let store = TestStore(
      initialState: AppListReducer.State(
        appListItems: .init(uniqueElements: [
          .init(
            menuBarSaveState: .init(bundleIdentifier: "com.example.App1"),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            appName: "App1"
          )
        ]),
        selectedItemIDs: []
      ),
      reducer: AppListReducer()
    )

    let task = await store.send(.removeButtonPressed)

    await task.finish()
  }

  func testRemoveButtonPressedWithMultipleElementsSelectedNotSystemDefault() async {
    let id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let id3 = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    let didSetAppMenuBarState = ActorIsolated(false)
    let didPostFullScreenMenuBarVisibilityChanged = ActorIsolated(false)
    let didPostMenuBarHidingChanged = ActorIsolated(false)

    let store = TestStore(
      initialState: AppListReducer.State(
        appListItems: .init(uniqueElements: [
          .init(
            menuBarSaveState: .init(bundleIdentifier: "com.example.App1", state: .never),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            appName: "App1"
          ),
          .init(
            menuBarSaveState: .init(bundleIdentifier: "com.example.App2", state: .always),
            id: id2,
            appName: "App2"
          ),
          .init(
            menuBarSaveState: .init(bundleIdentifier: "com.example.App3", state: .inFullScreenOnly),
            id: id3,
            appName: "App3"
          ),
        ]),
        selectedItemIDs: [id2, id3]
      ),
      reducer: AppListReducer()
    )

    store.dependencies.menuBarSettingsManager.setAppMenuBarState = { _, _ in
      await didSetAppMenuBarState.setValue(true)
    }
    store.dependencies.notifications.postFullScreenMenuBarVisibilityChanged = {
      await didPostFullScreenMenuBarVisibilityChanged.setValue(true)
    }
    store.dependencies.notifications.postMenuBarHidingChanged = {
      await didPostMenuBarHidingChanged.setValue(true)
    }

    let task = await store.send(.removeButtonPressed) { $0.removeInProgress = true }

    await store.receive(.didRemoveAppMenuBarStates(ids: [id2, id3])) {
      $0.removeInProgress = false
      $0.appListItems = .init(uniqueElements: [
        .init(
          menuBarSaveState: .init(bundleIdentifier: "com.example.App1", state: .never),
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          appName: "App1"
        )
      ])

      $0.selectedItemIDs = []
    }

    await task.finish()

    await didSetAppMenuBarState.withValue { XCTAssertTrue($0) }
    await didPostFullScreenMenuBarVisibilityChanged.withValue { XCTAssertTrue($0) }
    await didPostMenuBarHidingChanged.withValue { XCTAssertTrue($0) }
  }

  func testRemoveButtonPressedWithMultipleElementsSelectedSystemDefault() async {
    let id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let id3 = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    let store = TestStore(
      initialState: AppListReducer.State(
        appListItems: .init(uniqueElements: [
          .init(
            menuBarSaveState: .init(bundleIdentifier: "com.example.App1"),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            appName: "App1"
          ),
          .init(
            menuBarSaveState: .init(bundleIdentifier: "com.example.App2"),
            id: id2,
            appName: "App2"
          ),
          .init(
            menuBarSaveState: .init(bundleIdentifier: "com.example.App3"),
            id: id3,
            appName: "App3"
          ),
        ]),
        selectedItemIDs: [id2, id3]
      ),
      reducer: AppListReducer()
    )

    let task = await store.send(.removeButtonPressed) { $0.removeInProgress = true }

    await store.receive(.didRemoveAppMenuBarStates(ids: [id2, id3])) {
      $0.removeInProgress = false
      $0.appListItems = .init(uniqueElements: [
        .init(
          menuBarSaveState: .init(bundleIdentifier: "com.example.App1"),
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          appName: "App1"
        )
      ])

      $0.selectedItemIDs = []
    }

    await task.finish()
  }

  func testSelectedItemsBinding() async {
    let store = TestStore(initialState: AppListReducer.State(), reducer: AppListReducer())

    await store.send(
      .set(\.$selectedItemIDs, [UUID(uuidString: "00000000-0000-0000-0000-000000000001")!])
    ) { $0.selectedItemIDs = [UUID(uuidString: "00000000-0000-0000-0000-000000000001")!] }
  }

  func testIsFileImporterPresentedBinding() async {
    let store = TestStore(initialState: AppListReducer.State(), reducer: AppListReducer())

    await store.send(.set(\.$isFileImporterPresented, true)) { $0.isFileImporterPresented = true }
  }
}
