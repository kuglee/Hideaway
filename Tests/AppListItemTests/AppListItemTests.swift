import ComposableArchitecture
import MenuBarState
import XCTest

@testable import AppListItem

@MainActor final class AppListItemTests: XCTestCase {
  func testMenuBarStateReselectSameState() async {
    var didCallIsSettableWithoutFullDiskAccess = false

    let store = TestStore(
      initialState: AppListItemReducer.State(
        menuBarSaveState: .init(bundleIdentifier: "com.example.App1"),
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        appName: "App1"
      ),
      reducer: AppListItemReducer()
    )

    store.dependencies.menuBarSettingsManager.isSettableWithoutFullDiskAccess = { _ in
      didCallIsSettableWithoutFullDiskAccess = true

      return true
    }

    await store.send(.menuBarStateSelected(state: .never)) { $0.menuBarSaveState.state = .never }

    XCTAssertTrue(didCallIsSettableWithoutFullDiskAccess)
  }

  func testMenuBarStateNeedsFullDiskAccess() async {
    var didCallIsSettableWithoutFullDiskAccess = false

    let store = TestStore(
      initialState: AppListItemReducer.State(
        menuBarSaveState: .init(bundleIdentifier: "com.example.App1"),
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        appName: "App1"
      ),
      reducer: AppListItemReducer()
    )

    store.dependencies.menuBarSettingsManager.isSettableWithoutFullDiskAccess = { _ in
      didCallIsSettableWithoutFullDiskAccess = true

      return false
    }

    await store.send(.menuBarStateSelected(state: .never)) { $0.doesNeedFullDiskAccess = true }

    XCTAssertTrue(didCallIsSettableWithoutFullDiskAccess)
  }
}
