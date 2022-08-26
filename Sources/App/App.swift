import AppFeature
import ComposableArchitecture
import MenuBarSettingsManager
import SwiftUI

public struct App: SwiftUI.App {
  public init() {}

  public var body: some Scene {
    MenuBarExtra("Hideaway", systemImage: "menubar.rectangle") {
      AppView(
        store: Store(
          initialState: AppState(),
          reducer: appReducer,
          environment: .live
        )
      )
    }
  }
}
