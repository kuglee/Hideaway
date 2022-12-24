import ComposableArchitecture
import MenuBarState
import XCTest

@testable import AppListItem

@MainActor final class AppListItemTests: XCTestCase {
  func testMenuBarStateReselectSameState() async {
    let store = TestStore(
      initialState: AppListItemReducer.State(
        menuBarSaveState: .init(bundleIdentifier: "com.example.App1"),
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
      ),
      reducer: AppListItemReducer()
    )

    await store.send(.menuBarStateSelected(state: .never)) { $0.menuBarSaveState.state = .never }
  }
}
