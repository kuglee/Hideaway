import AppListItem
import AppMenuBarSaveState
import ComposableArchitecture
import MenuBarSettingsManager
import MenuBarState
import SwiftUI
import XCTestDynamicOverlay

public struct AppList: ReducerProtocol {
  @Dependency(\.menuBarSettingsManager) var menuBarSettingsManager
  @Dependency(\.uuid) var uuid

  public init() {}

  public struct State: Equatable {
    public var appListItems: IdentifiedArrayOf<AppListItem.State>
    @BindableState public var selectedItemIDs: Set<UUID>
    @BindableState public var isFileImporterPresented: Bool

    public init(
      appListItems: IdentifiedArrayOf<AppListItem.State> = [],
      selectedItemIDs: Set<UUID> = [],
      isFileImporterPresented: Bool = false
    ) {
      self.appListItems = appListItems
      self.selectedItemIDs = selectedItemIDs
      self.isFileImporterPresented = isFileImporterPresented
    }

    var sortedAppListItems: IdentifiedArrayOf<AppListItem.State> {
      IdentifiedArray(uniqueElements: self.appListItems.sorted(by: appListItemSorter))
    }
  }

  public enum Action: Equatable, BindableAction {
    case addButtonPressed
    case appImported(appInfo: AppInfo)
    case binding(BindingAction<State>)
    case appListItem(id: AppListItem.State.ID, action: AppListItem.Action)
    case didRemoveAppMenuBarStates(ids: Set<UUID>)
    case didSaveAppMenuBarState(AppMenuBarSaveState)
    case removeButtonPressed
  }

  public var body: some ReducerProtocol<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .addButtonPressed:
        state.isFileImporterPresented = true

        return .none
      case let .appImported(appInfo):
        guard
          !(state.appListItems.map { $0.menuBarSaveState.bundleIdentifier }
            .contains(appInfo.bundleIdentifier))
        else { return .none }

        return .run { send in
          let menuBarState = try await self.menuBarSettingsManager.getAppMenuBarState(
            appInfo.bundleIdentifier
          )

          var appStates: [String: [String: String]] =
            await self.menuBarSettingsManager.getAppMenuBarStates() ?? .init()

          appStates[appInfo.bundleIdentifier] = [
            "bundlePath": appInfo.bundleURL.path(percentEncoded: true),
            "state": menuBarState.stringValue,
          ]

          await self.menuBarSettingsManager.setAppMenuBarStates(appStates)

          let appMenuBarSaveState = AppMenuBarSaveState(
            bundleIdentifier: appInfo.bundleIdentifier,
            bundleURL: appInfo.bundleURL,
            state: menuBarState
          )

          await send(.didSaveAppMenuBarState(appMenuBarSaveState))
        }
      case .appListItem(id: _, action: _): return .none
      case .binding(_): return .none
      case let .didRemoveAppMenuBarStates(ids):
        for id in ids { state.appListItems.remove(id: id) }

        state.selectedItemIDs = []

        return .none
      case let .didSaveAppMenuBarState(appMenuBarSaveState):
        state.appListItems.append(
          AppListItem.State(menuBarSaveState: appMenuBarSaveState, id: self.uuid())
        )
        state.appListItems.sort(by: appListItemSorter)

        return .none
      case .removeButtonPressed:
        return .run { [state] send in guard !state.selectedItemIDs.isEmpty else { return }

          var appStates: [String: [String: String]] =
            await self.menuBarSettingsManager.getAppMenuBarStates() ?? .init()

          for selectedItemID in state.selectedItemIDs {
            let selectedItem = state.appListItems[id: selectedItemID]!
            appStates.removeValue(forKey: selectedItem.menuBarSaveState.bundleIdentifier)
          }

          await self.menuBarSettingsManager.setAppMenuBarStates(appStates)
          await send(.didRemoveAppMenuBarStates(ids: state.selectedItemIDs))
        }
      }
    }
    .forEach(\State.appListItems, action: /Action.appListItem(id:action:)) { AppListItem() }
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

public struct AppListView: View {
  let store: StoreOf<AppList>

  private let separatorOpacity = 0.5
  private let listRowInsets = EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
  @State private var listItemHeight = 0.0

  public init(store: StoreOf<AppList>) { self.store = store }

  public var body: some View {
    WithViewStore(store) { viewStore in
      VStack(spacing: 0) {
        Text("Change the menu bar hiding behavior of the applications below.")
          .foregroundColor(Color.secondary).padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
        Divider().opacity(self.separatorOpacity)
        // pinned footer in List (workaround for LazyVStack not supporting selection)
        ZStack {
          List(selection: viewStore.binding(\.$selectedItemIDs)) {
            ForEachStore(
              self.store.scope(
                state: \.sortedAppListItems,
                action: { .appListItem(id: $0, action: $1) }
              )
            ) {
              AppListItemView(store: $0).listRowSeparator(.visible)
                .listRowInsets(self.listRowInsets)
                .listRowSeparatorTint(
                  Color.init(nsColor: .separatorColor).opacity(self.separatorOpacity)
                )
                .background {
                  GeometryReader { geometry in
                    Rectangle().foregroundColor(Color.clear)
                      .onAppear {
                        guard self.listItemHeight == 0.0 else { return }

                        self.listItemHeight = geometry.frame(in: .global).size.height
                      }
                  }
                }
            }
          }
          .onDeleteCommand { viewStore.send(.removeButtonPressed) }.scrollDisabled(true)
          .listStyle(.plain).scrollContentBackground(.hidden)
          LazyVStack(spacing: 0, pinnedViews: .sectionFooters) {
            Section(footer: footerView) {
              if !viewStore.appListItems.isEmpty {
                ForEach(0..<viewStore.appListItems.count, id: \.self) { _ in
                  Rectangle().hidden().frame(height: self.getListRowHeight())
                }
              } else {
                Text("No Items").foregroundColor(Color.secondary).padding(4)
              }
            }
          }
        }
      }
      .background(Color.init(nsColor: .windowBackgroundColor).opacity(0.4))
      .overlay(
        RoundedRectangle(cornerRadius: 4, style: .circular).stroke(Color(nsColor: .separatorColor))
      )
    }
  }

  var footerView: some View {
    WithViewStore(store) { viewStore in
      VStack(spacing: 0) {
        Divider().opacity(self.separatorOpacity)
        HStack(spacing: 0) {
          Button(action: { viewStore.send(.addButtonPressed) }) { Image(systemName: "plus") }
            .fileImporter(
              isPresented: viewStore.binding(\.$isFileImporterPresented),
              allowedContentTypes: [.application]
            ) {
              if case let .success(bundleURL) = $0,
                let bundleIdentifier = Bundle(url: bundleURL).flatMap({ $0.bundleIdentifier })
              {
                viewStore.send(
                  .appImported(
                    appInfo: .init(bundleIdentifier: bundleIdentifier, bundleURL: bundleURL)
                  )
                )
              }
            }
            .buttonStyle(PrimaryButtonStyle())
          Divider().padding(.vertical, 4)
          Button(action: { viewStore.send(.removeButtonPressed) }) { Image(systemName: "minus") }
            .disabled(viewStore.selectedItemIDs.isEmpty).buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .background(.ultraThickMaterial).hitTestable()
    }
  }

  func getListRowHeight() -> Double {
    self.listItemHeight + self.listRowInsets.top + self.listRowInsets.bottom
  }
}

func appListItemSorter(lhs: AppListItem.State, rhs: AppListItem.State) -> Bool {
  lhs.menuBarSaveState.bundleURL.lastPathComponent.lowercased()
    < rhs.menuBarSaveState.bundleURL.lastPathComponent.lowercased()
}

struct PrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label.padding(6).font(.system(size: 11, weight: .bold))
      .foregroundColor(configuration.isPressed ? Color.primary : Color.secondary)
      .contentShape(Rectangle())
  }
}

extension View { func hitTestable() -> some View { self.modifier(HitTestableView()) } }

struct HitTestableView: ViewModifier {
  func body(content: Content) -> some View {
    content.background(RoundedRectangle(cornerRadius: 0.00001).opacity(0.00001))
  }
}

public struct AppList_Previews: PreviewProvider {
  public static var previews: some View {
    ScrollView {
      AppListView(
        store: Store(
          initialState: AppList.State(
            appListItems: .init(uniqueElements: [
              .init(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.Safari",
                  bundleURL: URL(
                    string: "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"
                  )!
                ),
                id: UUID()
              ),
              .init(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
              .init(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
              .init(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
              .init(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
              .init(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
              .init(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
              .init(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
              .init(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
              .init(
                menuBarSaveState: .init(
                  bundleIdentifier: "com.apple.mail",
                  bundleURL: URL(string: "/System/Applications/Mail.app")!
                ),
                id: UUID()
              ),
            ])
          ),
          reducer: AppList()
        )
      )
      .padding([.top, .horizontal]).frame(width: 500)
    }
  }
}

public struct AppList_Empty: PreviewProvider {
  public static var previews: some View {
    ScrollView {
      AppListView(store: Store(initialState: AppList.State(appListItems: []), reducer: AppList()))
        .padding([.top, .horizontal]).frame(width: 500)
    }
  }
}
