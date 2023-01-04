import AppMenuBarSaveState
import ComposableArchitecture
import MenuBarSettingsManager
import MenuBarState
import SwiftUI

public struct AppListItemReducer: ReducerProtocol {
  @Dependency(\.menuBarSettingsManager.getBundleDisplayName) var getBundleDisplayName
  @Dependency(\.menuBarSettingsManager.getBundleIcon) var getBundleIcon
  @Dependency(\.menuBarSettingsManager.getUrlForApplication) var getUrlForApplication
  @Dependency(\.menuBarSettingsManager.isSettableWithoutFullDiskAccess)

  var isSettableWithoutFullDiskAccess

  public init() {}

  public struct State: Equatable, Identifiable, Hashable, Comparable {
    public var menuBarSaveState: AppMenuBarSaveState
    public let id: UUID
    public var appName: String
    public var appIcon: NSImage?
    public var doesNeedFullDiskAccess: Bool

    public init(
      menuBarSaveState: AppMenuBarSaveState,
      id: UUID,
      appName: String,
      appIcon: NSImage? = nil,
      doesNeedFullDiskAccess: Bool = false
    ) {
      self.menuBarSaveState = menuBarSaveState
      self.id = id
      self.appIcon = appIcon
      self.appName = appName
      self.doesNeedFullDiskAccess = doesNeedFullDiskAccess
    }

    public static func < (lhs: AppListItemReducer.State, rhs: AppListItemReducer.State) -> Bool {
      lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
    }
  }

  public enum Action: Equatable {
    case menuBarStateSelected(state: MenuBarState)
    case onAppear
  }

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case let .menuBarStateSelected(menuBarState):
        if !self.isSettableWithoutFullDiskAccess(state.menuBarSaveState.bundleIdentifier) {
          state.doesNeedFullDiskAccess = true

          return .none
        }

        state.menuBarSaveState.state = menuBarState

        return .none
      case .onAppear:
        if let appBundleURL = self.getUrlForApplication(state.menuBarSaveState.bundleIdentifier) {
          if state.appIcon == nil, let appIcon = self.getBundleIcon(appBundleURL) {
            state.appIcon = appIcon
          }
        }

        return .none
      }
    }
  }
}

enum MenuBarSettingsManagerKey: DependencyKey {
  static let liveValue = MenuBarSettingsManager.live
  static let testValue = MenuBarSettingsManager.unimplemented
}

extension DependencyValues {
  var menuBarSettingsManager: MenuBarSettingsManager {
    get { self[MenuBarSettingsManagerKey.self] }
    set { self[MenuBarSettingsManagerKey.self] = newValue }
  }
}

public struct AppListItemView: View {
  let store: StoreOf<AppListItemReducer>

  public init(store: StoreOf<AppListItemReducer>) { self.store = store }

  public var body: some View {
    WithViewStore(store) { viewStore in
      HStack {
        (viewStore.appIcon != nil
          ? Image(nsImage: viewStore.appIcon!) : Image(systemName: "questionmark.app"))
          .resizable().frame(width: 32, height: 32)
        Text(viewStore.appName)
        Spacer()
        Picker(
          selection: viewStore.binding(
            get: \.menuBarSaveState.state,
            send: { .menuBarStateSelected(state: $0) }
          ),
          label: EmptyView()
        ) { ForEach(MenuBarState.allCases, id: \.self) { Text($0.label) } }
        .labelsHidden().fixedSize().padding(.trailing, 1)  // bug: List cuts off the trailing edge
      }
      .onAppear { viewStore.send(.onAppear) }
    }
  }
}

public struct AppListItem_Previews: PreviewProvider {
  public static var previews: some View {
    AppListItemView(
      store: Store(
        initialState: AppListItemReducer.State(
          menuBarSaveState: .init(bundleIdentifier: "com.apple.Safari"),
          id: UUID(),
          appName: "Safari"
        ),
        reducer: AppListItemReducer()
      )
    )
  }
}
