import AppFeature
import ComposableArchitecture
import SettingsFeature
import SwiftUI
import XCTestDynamicOverlay

public struct AppReducer: ReducerProtocol {
  public init() {}

  public struct State: Equatable {
    public var appFeatureState: AppFeatureReducer.State
    public var settingsFeatureState: SettingsFeatureReducer.State

    public init(
      appFeatureState: AppFeatureReducer.State = .init(),
      settingsFeatureState: SettingsFeatureReducer.State = .init()
    ) {
      self.appFeatureState = appFeatureState
      self.settingsFeatureState = settingsFeatureState
    }
  }

  public enum Action: Equatable {
    case appFeatureAction(action: AppFeatureReducer.Action)
    case settingsFeatureAction(action: SettingsFeatureReducer.Action)
  }

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .appFeatureAction(_): return .none
      case .settingsFeatureAction(_): return .none
      }
    }

    Scope(state: \.appFeatureState, action: /Action.appFeatureAction(action:)) {
      AppFeatureReducer()
    }
    Scope(state: \.settingsFeatureState, action: /Action.settingsFeatureAction(action:)) {
      SettingsFeatureReducer()
    }
  }
}

public struct App: SwiftUI.App, ApplicationDelegateProtocol {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  let store: StoreOf<AppReducer> = .init(initialState: AppReducer.State(), reducer: AppReducer())

  public init() { appDelegate.delegate = self }

  func applicationShouldTerminate() -> NSApplication.TerminateReply {
    ViewStore(self.store).send(.appFeatureAction(action: .applicationTerminated))

    return .terminateLater
  }

  public var body: some Scene {
    MenuBarExtra("Hideaway", systemImage: "menubar.rectangle") {
      AppFeatureView(
        store: self.store.scope(
          state: \.appFeatureState,
          action: AppReducer.Action.appFeatureAction
        )
      )
    }

    Settings {
      SettingsFeatureView(
        store: self.store.scope(
          state: \.settingsFeatureState,
          action: AppReducer.Action.settingsFeatureAction
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
  var delegate: App!

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    return self.delegate.applicationShouldTerminate()
  }
}

protocol ApplicationDelegateProtocol {
  func applicationShouldTerminate() -> NSApplication.TerminateReply
}
