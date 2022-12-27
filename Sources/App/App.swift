import AppFeature
import ComposableArchitecture
import ComposableArchitectureExtra
import MenuBarSettingsManager
import MenuBarState
import Notifications
import SettingsFeature
import SwiftUI
import WelcomeFeature
import XCTestDynamicOverlay

public struct AppReducer: ReducerProtocol {
  @Dependency(\.appEnvironment) var environment
  @Dependency(\.menuBarSettingsManager.getAppMenuBarState) var getAppMenuBarState
  @Dependency(\.menuBarSettingsManager.setAppMenuBarState) var setAppMenuBarState
  @Dependency(\.menuBarSettingsManager.getAppMenuBarStates) var getAppMenuBarStates
  @Dependency(\.menuBarSettingsManager.getDidRunBefore) var getDidRunBefore
  @Dependency(\.menuBarSettingsManager.setDidRunBefore) var setDidRunBefore
  @Dependency(\.notifications.postFullScreenMenuBarVisibilityChanged)
  var postFullScreenMenuBarVisibilityChanged
  @Dependency(\.notifications.postMenuBarHidingChanged) var postMenuBarHidingChanged

  public init() {}

  public struct State: Equatable {
    public var appFeatureState: AppFeatureReducer.State
    public var settingsFeatureState: SettingsFeatureReducer.State
    public var didRunBefore: Bool

    public init(
      appFeatureState: AppFeatureReducer.State = .init(),
      settingsFeatureState: SettingsFeatureReducer.State = .init(),
      didRunBefore: Bool = false
    ) {
      self.appFeatureState = appFeatureState
      self.settingsFeatureState = settingsFeatureState
      self.didRunBefore = didRunBefore
    }
  }

  public enum Action: Equatable {
    case appFeatureAction(action: AppFeatureReducer.Action)
    case applicationTerminated
    case dismissWelcomeSheet
    case onAppear
    case openSettingsWindow
    case settingsFeatureAction(action: SettingsFeatureReducer.Action)
  }

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .appFeatureAction(_): return .none
      case .applicationTerminated:
        return .run { _ in
          if let appStates = await self.getAppMenuBarStates() {
            var didSetState = false

            await withThrowingTaskGroup(of: Void.self) { group in
              for bundleIdentifier in appStates.keys {
                if let savedState = appStates[bundleIdentifier],
                  savedState != MenuBarState.systemDefault.stringValue
                {
                  if !didSetState { didSetState = true }

                  group.addTask {
                    try await self.setAppMenuBarState(.systemDefault, bundleIdentifier)
                  }
                }
              }
            }

            if didSetState {
              await self.postFullScreenMenuBarVisibilityChanged()
              await self.postMenuBarHidingChanged()
            }
          }

          await self.environment.applicationShouldTerminate()
        }

      case .onAppear:
        guard !state.didRunBefore else { return .none }

        return .run { send in await send(.openSettingsWindow) }
      case .openSettingsWindow: return .run { _ in await self.environment.openSettings() }
      case .dismissWelcomeSheet:
        state.didRunBefore = true

        return .none
      case .settingsFeatureAction(_): return .none
      }
    }
    .onChange(of: \.didRunBefore) { didRunBefore, _, _ in
      return .run { send in await self.setDidRunBefore(didRunBefore) }
    }

    Scope(state: \.appFeatureState, action: /Action.appFeatureAction(action:)) {
      AppFeatureReducer()
    }
    Scope(state: \.settingsFeatureState, action: /Action.settingsFeatureAction(action:)) {
      SettingsFeatureReducer()
    }
  }
}

public enum NotificationsManagerKey: DependencyKey {
  public static let liveValue = Notifications.live
  public static let testValue = Notifications.unimplemented
}

extension DependencyValues {
  public var notifications: Notifications {
    get { self[NotificationsManagerKey.self] }
    set { self[NotificationsManagerKey.self] = newValue }
  }
}

public enum AppEnvironmentKey: DependencyKey {
  public static let liveValue = AppEnvironment.live
  public static let testValue = AppEnvironment.unimplemented
}

extension DependencyValues {
  public var appEnvironment: AppEnvironment {
    get { self[AppEnvironmentKey.self] }
    set { self[AppEnvironmentKey.self] = newValue }
  }
}

public struct AppEnvironment {
  public var applicationShouldTerminate: () async -> Void
  public var openSettings: () async -> Void
}

extension AppEnvironment {
  public static let live = Self(
    applicationShouldTerminate: {
      await NSApplication.shared.reply(toApplicationShouldTerminate: true)
    },
    openSettings: {
      await NSApplication.shared.setActivationPolicy(.regular)

      let success = await NSApplication.shared.sendAction(
        Selector(("showSettingsWindow:")),
        to: nil,
        from: nil
      )

      if success {
        await NSApplication.shared.activate(ignoringOtherApps: true)
      } else {
        await NSApplication.shared.setActivationPolicy(.accessory)
      }
    }
  )
}

extension AppEnvironment {
  public static let unimplemented = Self(
    applicationShouldTerminate: XCTUnimplemented("\(Self.self).applicationShouldTerminate"),
    openSettings: XCTUnimplemented("\(Self.self).openSettings")
  )
}

public struct App: SwiftUI.App, ApplicationDelegateProtocol {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  let store: StoreOf<AppReducer> = .init(
    initialState: AppReducer.State(didRunBefore: MenuBarSettingsManager.live.getDidRunBefore()),
    reducer: AppReducer()
  )

  public init() {
    appDelegate.delegate = self

    ViewStore(self.store).send(.onAppear)
  }

  func applicationShouldTerminate() -> NSApplication.TerminateReply {
    ViewStore(self.store).send(.applicationTerminated)

    return .terminateLater
  }

  public var body: some Scene {
    MenuBarExtra("Hideaway", systemImage: "menubar.rectangle") {
      WithViewStore(self.store.scope(state: \.didRunBefore)) { viewStore in
        AppFeatureView(
          store: self.store.scope(
            state: \.appFeatureState,
            action: AppReducer.Action.appFeatureAction
          )
        )
        .disabled(!viewStore.state)
      }
    }

    Settings {
      WithViewStore(self.store.scope(state: { !$0.didRunBefore })) { viewStore in
        SettingsFeatureView(
          store: self.store.scope(
            state: \.settingsFeatureState,
            action: AppReducer.Action.settingsFeatureAction
          )
        )
        .frame(minWidth: 550, maxWidth: 550, minHeight: 450, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: viewStore.binding(send: .dismissWelcomeSheet)) {
          WelcomeFeatureView()
            .background(VisualEffect(material: .windowBackground, blendingMode: .withinWindow))
        }
        .onAppear { NSWindow.allowsAutomaticWindowTabbing = false }
      }
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
