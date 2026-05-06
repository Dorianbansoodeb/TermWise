import SwiftUI

struct AppOverflowMenu: View {
    @EnvironmentObject private var appState: AppState

    @State private var showSettings = false
    @State private var showConverter = false

    var body: some View {
        Menu {
            Button("Settings") {
                showSettings = true
            }
            Button("Currency converter") {
                showConverter = true
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .sheet(isPresented: $showSettings) {
            AppSettingsView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showConverter) {
            CurrencyConverterView()
                .environmentObject(appState)
        }
    }
}

#Preview {
    AppOverflowMenu()
        .environmentObject(AppState())
}
