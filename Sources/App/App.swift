import AppFeature
import ComposableArchitecture
import MenuBarSettingsManager
import Notifications
import SettingsFeature
import SwiftUI

public struct App: SwiftUI.App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  public init() {}

  public var body: some Scene {
    MenuBarExtra("Hideaway", systemImage: "menubar.rectangle") {
      AppFeatureView(
        store: Store(initialState: AppFeatureReducer.State(), reducer: AppFeatureReducer())
      )
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

class AppDelegate: NSObject, NSApplicationDelegate {
  @MainActor func applicationShouldTerminate(_ sender: NSApplication)
    -> NSApplication.TerminateReply
  {
    NotificationCenter.default.post(
      name: NSApplication.applicationShouldTerminateLater,
      object: nil
    )

    return .terminateLater
  }
}
