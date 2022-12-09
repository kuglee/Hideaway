import AppFeature
import ComposableArchitecture
import MenuBarSettingsManager
import SettingsFeature
import SwiftUI

public struct App: SwiftUI.App {
  public init() {}

  public var body: some Scene {
    MenuBarExtra("Hideaway", systemImage: "menubar.rectangle") {
      AppFeatureView(
        store: Store(initialState: AppFeatureReducer.State(), reducer: AppFeatureReducer())
      )
    }
    .commands {
      // disable the quit keyboard shortcut
      CommandGroup(replacing: CommandGroupPlacement.appTermination) {}
    }

    Settings {
      SettingsFeatureView(
        store: Store(
          initialState: SettingsFeatureReducer.State(),
          reducer: SettingsFeatureReducer()
        )
      )
      .frame(minWidth: 550, maxWidth: 550, minHeight: 450, maxHeight: .infinity, alignment: .top)
      .onAppear { NSWindow.allowsAutomaticWindowTabbing = false }
    }
    .windowResizability(.contentSize)
    .commands {
      // disable the settings keyboard shortcut
      CommandGroup(replacing: CommandGroupPlacement.appSettings) {}
    }
  }
}
