import SwiftUI

enum SettingsStrings {
  static let systemSettingsName = "System Settings"
  static let settingsURL =
    "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
}

public struct WelcomeFeatureView: View {
  @Environment(\.colorScheme) var colorScheme: ColorScheme
  @Environment(\.presentationMode) @Binding var presentationMode

  public init() {}

  public var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: .grid(9)) {
        Image(systemName: "menubar.rectangle").resizable().aspectRatio(contentMode: .fit)
          .frame(height: 72).foregroundColor(.accentColor)
        Text("Welcome to Hideaway").font(.largeTitle).multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
        VStack(alignment: .leading, spacing: .grid(5)) {
          EqualIconWidthDomain {
            WelcomeItemView(
              title: "Enabling Full Disk Access",
              subtitle:
                "For Hideaway to be able to change the menu bar settings of system applications Full Disk Access must be enabled in \(SettingsStrings.systemSettingsName).",
              image: Image(systemName: "gear")
            )
          }
        }
        .padding(.leading, .grid(15)).padding(.trailing, .grid(18))
      }
      VStack(spacing: .grid(3)) {
        Text(.init("[Open \(SettingsStrings.systemSettingsName)](\(SettingsStrings.settingsURL))"))
        Button(action: { self.presentationMode.dismiss() }) { Text("Continue").frame(minWidth: 84) }
          .controlSize(.large).keyboardShortcut(.defaultAction)
      }
      .padding(.top, .grid(14))
    }
    .padding(.top, .grid(18)).padding(.bottom, .grid(8)).frame(width: 510, alignment: .top)
  }
}

public struct WelcomeFeatureView_Previews: PreviewProvider {
  public static var previews: some View { WelcomeFeatureView() }
}

struct WelcomeItemView: View {
  let title: String
  let subtitle: String
  let image: Image

  init(title: String, subtitle: String, image: Image) {
    self.title = title
    self.subtitle = subtitle
    self.image = image
  }

  var body: some View {
    Label {
      VStack(alignment: .leading, spacing: .grid(1)) {
        Text("\(self.title)").bold().foregroundColor(.primary)
          .fixedSize(horizontal: false, vertical: true)
        Text(self.subtitle).fixedSize(horizontal: false, vertical: true)
      }
    } icon: {
      self.image.resizable().aspectRatio(contentMode: .fit).frame(width: 28)
        .foregroundColor(.accentColor).padding(.trailing)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    .multilineTextAlignment(.leading)
  }
}

extension CGFloat { public static func grid(_ n: Int) -> Self { Self(n) * 4 } }
