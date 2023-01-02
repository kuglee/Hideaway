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
  @Dependency(\.workspace.openFullDiskAccessSettings) var openFullDiskAccessSettings

  public init() {}

  public struct State: Equatable {
    public var appFeatureState: AppFeatureReducer.State
    public var settingsFeatureState: SettingsFeatureReducer.State
    public var didRunBefore: Bool
    public var shouldShowFullDiskAccessDialog: Bool

    public init(
      appFeatureState: AppFeatureReducer.State = .init(),
      settingsFeatureState: SettingsFeatureReducer.State = .init(),
      didRunBefore: Bool = false,
      shouldShowFullDiskAccessDialog: Bool = false
    ) {
      self.appFeatureState = appFeatureState
      self.settingsFeatureState = settingsFeatureState
      self.didRunBefore = didRunBefore
      self.shouldShowFullDiskAccessDialog = shouldShowFullDiskAccessDialog
    }
  }

  public enum Action: Equatable {
    case appFeatureAction(action: AppFeatureReducer.Action)
    case applicationTerminated
    case dismissWelcomeSheet
    case dismissFullDiskAccessDialog
    case doesAppListItemNeedFullDiskAccessChanged(newValue: Bool)
    case doesCurrentAppNeedFullDiskAccessChanged(newValue: Bool)
    case onAppear
    case openSettingsWindow
    case openSystemSettings
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
      case .dismissFullDiskAccessDialog:
        state.shouldShowFullDiskAccessDialog = false

        for id in state.settingsFeatureState.appList.appListItems.ids {
          state.settingsFeatureState.appList.appListItems[id: id]?.doesNeedFullDiskAccess = false
        }

        return .none
      case let .doesAppListItemNeedFullDiskAccessChanged(newValue):
        guard newValue else { return .none }

        state.shouldShowFullDiskAccessDialog = true

        return .none
      case let .doesCurrentAppNeedFullDiskAccessChanged(newValue):
        guard newValue else { return .none }

        state.shouldShowFullDiskAccessDialog = true

        return .run { send in await send(.openSettingsWindow) }
      case .openSettingsWindow: return .run { _ in await self.environment.openSettings() }
      case .openSystemSettings: return .run { _ in await self.openFullDiskAccessSettings() }
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
    .onChange(of: \.appFeatureState.doesCurrentAppNeedFullDiskAccess) {
      doesCurrentAppNeedFullDiskAccess,
      _,
      _ in
      .run { send in
        await send(
          .doesCurrentAppNeedFullDiskAccessChanged(newValue: doesCurrentAppNeedFullDiskAccess)
        )
      }
    }

    Scope(state: \.settingsFeatureState, action: /Action.settingsFeatureAction(action:)) {
      SettingsFeatureReducer()
    }
    .onChange(of: \.settingsFeatureState.appList.appListItems) { appListItems, _, action in
      switch action {
      case .settingsFeatureAction(action: .appList(action: .appListItem(_, .menuBarStateSelected))):
        let doesAppListItemNeedFullDiskAccess =
          appListItems.allSatisfy({ appListItem in appListItem.doesNeedFullDiskAccess == false })
          != true

        return .run { send in
          await send(
            .doesAppListItemNeedFullDiskAccessChanged(newValue: doesAppListItemNeedFullDiskAccess)
          )
        }
      default: return .none
      }
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
      WithViewStore(self.store, observe: { !$0.didRunBefore || $0.shouldShowFullDiskAccessDialog })
      { viewStore in
        AppFeatureView(
          store: self.store.scope(
            state: \.appFeatureState,
            action: AppReducer.Action.appFeatureAction
          )
        )
        .disabled(viewStore.state)
      }
    }

    Settings {
      VStack(spacing: 0) {
        WithViewStore(self.store, observe: { !$0.didRunBefore }) { viewStore in
          SettingsFeatureView(
            store: self.store.scope(
              state: \.settingsFeatureState,
              action: AppReducer.Action.settingsFeatureAction
            )
          )
          .frame(
            minWidth: 550,
            maxWidth: 550,
            minHeight: 450,
            maxHeight: .infinity,
            alignment: .top
          )
          .sheet(isPresented: viewStore.binding(send: .dismissWelcomeSheet)) {
            WelcomeFeatureView()
              .background(VisualEffect(material: .windowBackground, blendingMode: .withinWindow))
          }
        }
        WithViewStore(self.store, observe: \.shouldShowFullDiskAccessDialog) { viewStore in
          RenderedEmptyView()
            .confirmationDialog(
              "Hideaway need Full Disk Access to modify the menu bar settings of the selected application.",
              isPresented: viewStore.binding(send: .dismissFullDiskAccessDialog)
            ) {
              Button("Open Settings") { viewStore.send(.openSystemSettings) }
              Button("Cancel", role: .cancel) {}
            }
        }
      }
      .onAppear { NSWindow.allowsAutomaticWindowTabbing = false }
    }
    .windowResizability(.contentSize)
    .commands {
      // disable the settings keyboard shortcut
      CommandGroup(replacing: CommandGroupPlacement.appSettings) {}
    }
  }
}

struct RenderedEmptyView: View { var body: some View { Spacer().frame(height: 0).hidden() } }

class AppDelegate: NSObject, NSApplicationDelegate {
  var delegate: App!

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    return self.delegate.applicationShouldTerminate()
  }
}

protocol ApplicationDelegateProtocol {
  func applicationShouldTerminate() -> NSApplication.TerminateReply
}

public enum WorkspaceKeys: DependencyKey {
  public static let liveValue = Workspace.live
  public static let testValue = Workspace.unimplemented
}

extension DependencyValues {
  public var workspace: Workspace {
    get { self[WorkspaceKeys.self] }
    set { self[WorkspaceKeys.self] = newValue }
  }
}

public struct Workspace { public var openFullDiskAccessSettings: () async -> Void }

extension Workspace {
  public static let live = Self(openFullDiskAccessSettings: {
    NSWorkspace.shared.open(
      URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
    )
  })
}

extension Workspace {
  public static let unimplemented = Self(
    openFullDiskAccessSettings: XCTUnimplemented("\(Self.self).openFullDiskAccessSettings")
  )
}
