import AppFeature
import ComposableArchitecture
import MenuBarSettingsManager
import SettingsFeature
import SwiftUI

public struct App: SwiftUI.App {
  public init() {}

  public var body: some Scene {
    MenuBarExtra("Hideaway", systemImage: "menubar.rectangle") {
      AppFeatureView(store: Store(initialState: AppFeature.State(), reducer: AppFeature()))
    }

    Settings {
      SettingsFeatureView(
        store: Store(initialState: SettingsFeature.State(), reducer: SettingsFeature())
      )
      .frame(width: 500, height: 300, alignment: .top)
    }
    .windowResizability(.contentSize)
  }
}
