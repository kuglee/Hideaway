import AppList
import ComposableArchitecture
import MenuBarState
import XCTest

@testable import SettingsFeature

@MainActor final class SettingsFeatureTests: XCTestCase {
  func testTask() async {
    let (appMenuBarStateChanged, changeAppMenuBarState) = AsyncStream<Notification>
      .streamWithContinuation()

    let store = TestStore(
      initialState: SettingsFeatureReducer.State(),
      reducer: SettingsFeatureReducer()
    )

    store.dependencies.menuBarSettingsManager.getAppMenuBarStates = {
      [
        "com.example.App1": MenuBarState.never.stringValue,
        "com.example.App2": MenuBarState.always.stringValue,
      ]
    }
    store.dependencies.notifications.appMenuBarStateChanged = {
      AsyncStream(
        appMenuBarStateChanged.compactMap {
          ($0.object as? String) == Bundle.main.bundleIdentifier ? nil : ()
        }
      )
    }
    store.dependencies.uuid = .incrementing

    let notification = Notification(
      name: Notification.Name(""),
      object: Bundle.main.bundleIdentifier
    )

    let task = await store.send(.task)

    changeAppMenuBarState.yield(notification)

    await store.receive(.gotAppList(["com.example.App1": "never", "com.example.App2": "always"])) {
      $0.appList = AppListReducer.State(
        appListItems: .init(uniqueElements: [
          .init(
            menuBarSaveState: .init(bundleIdentifier: "com.example.App1", state: .never),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
          ),
          .init(
            menuBarSaveState: .init(bundleIdentifier: "com.example.App2", state: .always),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
          ),
        ])
      )
    }

    await task.cancel()

    changeAppMenuBarState.yield(notification)
  }
}