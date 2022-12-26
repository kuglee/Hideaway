import AppMenuBarSaveState
import ComposableArchitecture
import MenuBarState
import SwiftUI

public struct AppListItemReducer: ReducerProtocol {
  public init() {}

  public struct State: Equatable, Identifiable, Hashable {
    public var menuBarSaveState: AppMenuBarSaveState
    public let id: UUID

    public init(menuBarSaveState: AppMenuBarSaveState, id: UUID) {
      self.menuBarSaveState = menuBarSaveState
      self.id = id
    }
  }

  public enum Action: Equatable { case menuBarStateSelected(state: MenuBarState) }

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case let .menuBarStateSelected(menuBarState):
        state.menuBarSaveState.state = menuBarState

        return .none
      }
    }
  }
}

public struct AppListItemView: View {
  let store: StoreOf<AppListItemReducer>

  public init(store: StoreOf<AppListItemReducer>) { self.store = store }

  public var body: some View {
    WithViewStore(store) { viewStore in
      HStack {
        Image(nsImage: getAppIcon(bundleIdentifier: viewStore.menuBarSaveState.bundleIdentifier))
        Text("\(getAppName(bundleIdentifier: viewStore.menuBarSaveState.bundleIdentifier))")
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
    }
  }
}

func getAppName(bundleIdentifier: String) -> String {
  guard let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
  else { return "N/A" }

  return Bundle.init(url: bundleURL)!.displayName
}

extension Bundle {
  var displayName: String {
    let bundleName =
      (self.localizedInfoDictionary?["CFBundleDisplayName"]
        ?? self.localizedInfoDictionary?["CFBundleName"]
        ?? self.infoDictionary?["CFBundleDisplayName"] ?? self.infoDictionary?["CFBundleName"])
      as? String

    if let bundleName { return bundleName }

    let fileName = self.bundleURL.lastPathComponent

    return String(fileName.prefix(upTo: fileName.lastIndex { $0 == "." } ?? fileName.endIndex))
  }
}

func getAppIcon(bundleIdentifier: String) -> NSImage {
  guard let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
  else { return NSImage() }

  return NSWorkspace.shared.icon(forFile: bundleURL.relativePath)
}

public struct AppListItem_Previews: PreviewProvider {
  public static var previews: some View {
    AppListItemView(
      store: Store(
        initialState: AppListItemReducer.State(
          menuBarSaveState: .init(bundleIdentifier: "com.apple.Safari"),
          id: UUID()
        ),
        reducer: AppListItemReducer()
      )
    )
  }
}
