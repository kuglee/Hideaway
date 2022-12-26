import AppListItem
import AppMenuBarSaveState
import ComposableArchitecture
import MenuBarSettingsManager
import MenuBarState
import SwiftUI
import XCTestDynamicOverlay

public struct AppListReducer: ReducerProtocol {
  @Dependency(\.menuBarSettingsManager) var menuBarSettingsManager
  @Dependency(\.uuid) var uuid

  public init() {}

  public struct State: Equatable {
    public var appListItems: IdentifiedArrayOf<AppListItemReducer.State>
    @BindableState public var selectedItemIDs: Set<UUID>
    @BindableState public var isFileImporterPresented: Bool

    public init(
      appListItems: IdentifiedArrayOf<AppListItemReducer.State> = [],
      selectedItemIDs: Set<UUID> = [],
      isFileImporterPresented: Bool = false
    ) {
      self.appListItems = appListItems
      self.selectedItemIDs = selectedItemIDs
      self.isFileImporterPresented = isFileImporterPresented
    }
  }

  public enum Action: Equatable, BindableAction {
    case addButtonPressed
    case appImported(bundleIdentifier: String)
    case binding(BindingAction<State>)
    case appListItem(id: AppListItemReducer.State.ID, action: AppListItemReducer.Action)
    case removeButtonPressed
  }

  public var body: some ReducerProtocol<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .addButtonPressed:
        state.isFileImporterPresented = true

        return .none
      case let .appImported(bundleIdentifier):
        if !(state.appListItems.map { $0.menuBarSaveState.bundleIdentifier }
          .contains(bundleIdentifier))
        {
          let appMenuBarSaveState = AppMenuBarSaveState(bundleIdentifier: bundleIdentifier)

          state.appListItems.append(
            AppListItemReducer.State(menuBarSaveState: appMenuBarSaveState, id: self.uuid())
          )
        }

        return .none
      case .appListItem(id: _, action: _): return .none
      case .binding(_): return .none
      case .removeButtonPressed:
        if !state.selectedItemIDs.isEmpty {
          for id in state.selectedItemIDs { state.appListItems.remove(id: id) }
        }

        state.selectedItemIDs = []

        return .none
      }
    }
    .forEach(\State.appListItems, action: /Action.appListItem(id:action:)) { AppListItemReducer() }
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
  let store: StoreOf<AppListReducer>

  private let separatorOpacity = 0.5
  private let listRowInsets = EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
  @State private var listItemHeight = 0.0

  public init(store: StoreOf<AppListReducer>) { self.store = store }

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
              self.store.scope(state: \.appListItems, action: { .appListItem(id: $0, action: $1) })
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
                viewStore.send(.appImported(bundleIdentifier: bundleIdentifier))
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
          initialState: AppListReducer.State(
            appListItems: .init(uniqueElements: [
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.Safari"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
              .init(menuBarSaveState: .init(bundleIdentifier: "com.apple.mail"), id: UUID()),
            ])
          ),
          reducer: AppListReducer()
        )
      )
      .padding([.top, .horizontal]).frame(width: 500)
    }
  }
}

public struct AppList_Empty: PreviewProvider {
  public static var previews: some View {
    ScrollView {
      AppListView(
        store: Store(
          initialState: AppListReducer.State(appListItems: []),
          reducer: AppListReducer()
        )
      )
      .padding([.top, .horizontal]).frame(width: 500)
    }
  }
}
