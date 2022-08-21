import AppFeature
import ComposableArchitecture
import DefaultDistributedNotificationCenter
import MenuBarSettingsManager
import SharedNSWorkspaceNotificationCenter
import SwiftUI

public struct App: SwiftUI.App {
  public init() {}

  public var body: some Scene {
    MenuBarExtra("Hideaway", systemImage: "menubar.rectangle") {
      AppView(
        store: Store(
          initialState: AppState(),
          reducer: appReducer,
          environment: .init(
            menuBarSettingsManager: MenuBarSettingsManager.live,
            distributedNotificationCenter: DefaultDistributedNotificationCenter.live,
            workspaceNotificationCenter: SharedNSWorkspaceNotificationCenter.live
          )
        )
      )
    }
  }
}
