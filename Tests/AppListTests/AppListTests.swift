import ComposableArchitecture
import MenuBarSettingsManager
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
    let didGetAppMenuBarStates = ActorIsolated(false)
    let didSetAppMenuBarStates = ActorIsolated(false)

    let store = TestStore(
      initialState: AppListReducer.State(appListItems: []),
      reducer: AppListReducer()
    )

    store.dependencies.uuid = UUIDGenerator { id }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await didGetAppMenuBarStates.setValue(true)

      return nil
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarStates = { _ in
      await didSetAppMenuBarStates.setValue(true)
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarState = { _ in .systemDefault }

    let task = await store.send(.addButtonPressed) { $0.isFileImporterPresented = true }

    await store.send(
      .appImported(
        appInfo: .init(
          bundleIdentifier: "com.example.App1",
          bundleURL: URL(string: "/Applications/App1.app/")!
        )
      )
    )

    await store.receive(
      .didSaveAppMenuBarState(
        .init(
          bundleIdentifier: "com.example.App1",
          bundleURL: URL(string: "/Applications/App1.app/")!
        )
      )
    ) {
      $0.appListItems = .init(uniqueElements: [
        .init(
          menuBarSaveState: .init(
            bundleIdentifier: "com.example.App1",
            bundleURL: URL(string: "/Applications/App1.app/")!
          ),
          id: id
        )
      ])
    }

    await task.finish()

    await didGetAppMenuBarStates.withValue { XCTAssertTrue($0) }
    await didSetAppMenuBarStates.withValue { XCTAssertTrue($0) }
  }

  func testAppImportNotAlreadyImported() async {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    let didGetAppMenuBarStates = ActorIsolated(false)
    let didSetAppMenuBarStates = ActorIsolated(false)

    let store = TestStore(
      initialState: AppListReducer.State(
        appListItems: .init(uniqueElements: [
          .init(
            menuBarSaveState: .init(
              bundleIdentifier: "com.example.App1",
              bundleURL: URL(string: "/Applications/App1.app/")!
            ),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
          ),
          .init(
            menuBarSaveState: .init(
              bundleIdentifier: "com.example.App3",
              bundleURL: URL(string: "/Applications/App3.app/")!
            ),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
          ),
        ])
      ),
      reducer: AppListReducer()
    )

    store.dependencies.uuid = UUIDGenerator { id }
    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await didGetAppMenuBarStates.setValue(true)

      return nil
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarStates = { _ in
      await didSetAppMenuBarStates.setValue(true)
    }
    store.dependencies.menuBarSettingsManager.getAppMenuBarState = { _ in .systemDefault }

    let task = await store.send(.addButtonPressed) { $0.isFileImporterPresented = true }

    await store.send(
      .appImported(
        appInfo: .init(
          bundleIdentifier: "com.example.App2",
          bundleURL: URL(string: "/Applications/App2.app/")!
        )
      )
    )

    await store.receive(
      .didSaveAppMenuBarState(
        .init(
          bundleIdentifier: "com.example.App2",
          bundleURL: URL(string: "/Applications/App2.app/")!
        )
      )
    ) {
      $0.appListItems = .init(uniqueElements: [
        .init(
          menuBarSaveState: .init(
            bundleIdentifier: "com.example.App1",
            bundleURL: URL(string: "/Applications/App1.app/")!
          ),
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        ),
        .init(
          menuBarSaveState: .init(
            bundleIdentifier: "com.example.App2",
            bundleURL: URL(string: "/Applications/App2.app/")!
          ),
          id: id
        ),
        .init(
          menuBarSaveState: .init(
            bundleIdentifier: "com.example.App3",
            bundleURL: URL(string: "/Applications/App3.app/")!
          ),
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        ),
      ])
    }

    await task.finish()

    await didGetAppMenuBarStates.withValue { XCTAssertTrue($0) }
    await didSetAppMenuBarStates.withValue { XCTAssertTrue($0) }
  }

  func testAppImportAlreadyImported() async {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    let store = TestStore(
      initialState: AppListReducer.State(
        appListItems: .init(uniqueElements: [
          .init(
            menuBarSaveState: .init(
              bundleIdentifier: "com.example.App1",
              bundleURL: URL(string: "/Applications/App1.app/")!
            ),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
          ),
          .init(
            menuBarSaveState: .init(
              bundleIdentifier: "com.example.App2",
              bundleURL: URL(string: "/Applications/App2.app/")!
            ),
            id: id
          ),
          .init(
            menuBarSaveState: .init(
              bundleIdentifier: "com.example.App3",
              bundleURL: URL(string: "/Applications/App3.app/")!
            ),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
          ),
        ])
      ),
      reducer: AppListReducer()
    )

    store.dependencies.uuid = UUIDGenerator { id }

    let task = await store.send(.addButtonPressed) { $0.isFileImporterPresented = true }

    await store.send(
      .appImported(
        appInfo: .init(
          bundleIdentifier: "com.example.App2",
          bundleURL: URL(string: "/Applications/App2.app/")!
        )
      )
    )

    await task.finish()
  }

  func testRemoveButtonPressedWithNoElementsSelected() async {
    let store = TestStore(
      initialState: AppListReducer.State(
        appListItems: .init(uniqueElements: [
          .init(
            menuBarSaveState: .init(
              bundleIdentifier: "com.example.App1",
              bundleURL: URL(string: "/Applications/App1.app/")!
            ),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
          )
        ]),
        selectedItemIDs: []
      ),
      reducer: AppListReducer()
    )

    let task = await store.send(.removeButtonPressed)

    await task.finish()
  }

  func testRemoveButtonPressedWithMultipleElementsSelected() async {
    let id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let id3 = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    let didGetAppMenuBarStates = ActorIsolated(false)
    let didSetAppMenuBarStates = ActorIsolated(false)

    let store = TestStore(
      initialState: AppListReducer.State(
        appListItems: .init(uniqueElements: [
          .init(
            menuBarSaveState: .init(
              bundleIdentifier: "com.example.App1",
              bundleURL: URL(string: "/Applications/App1.app/")!
            ),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
          ),
          .init(
            menuBarSaveState: .init(
              bundleIdentifier: "com.example.App2",
              bundleURL: URL(string: "/Applications/App2.app/")!
            ),
            id: id2
          ),
          .init(
            menuBarSaveState: .init(
              bundleIdentifier: "com.example.App2",
              bundleURL: URL(string: "/Applications/App2.app/")!
            ),
            id: id3
          ),
        ]),
        selectedItemIDs: [id2, id3]
      ),
      reducer: AppListReducer()
    )

    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      await didGetAppMenuBarStates.setValue(true)

      return nil
    }
    store.dependencies.menuBarSettingsManager.setAppMenuBarStates = { _ in
      await didSetAppMenuBarStates.setValue(true)
    }

    let task = await store.send(.removeButtonPressed)

    await store.receive(.didRemoveAppMenuBarStates(ids: [id2, id3])) {
      $0.appListItems = .init(uniqueElements: [
        .init(
          menuBarSaveState: .init(
            bundleIdentifier: "com.example.App1",
            bundleURL: URL(string: "/Applications/App1.app/")!
          ),
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
      ])

      $0.selectedItemIDs = []
    }

    await task.finish()

    await didGetAppMenuBarStates.withValue { XCTAssertTrue($0) }
    await didSetAppMenuBarStates.withValue { XCTAssertTrue($0) }
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
