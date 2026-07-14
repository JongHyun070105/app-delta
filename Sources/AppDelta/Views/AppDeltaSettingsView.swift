import SwiftUI

struct AppDeltaSettingsView: View {
  @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system.rawValue

  var body: some View {
    Form {
      Picker(L10n.text("App language"), selection: $language) {
        ForEach(AppLanguage.allCases) { option in
          Text(option.displayName).tag(option.rawValue)
        }
      }
      .pickerStyle(.radioGroup)
    }
    .padding(20)
    .frame(width: 390, height: 190)
  }
}
