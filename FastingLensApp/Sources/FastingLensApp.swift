import AppFeatures
import SwiftUI

@main
struct FastingLensApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(appState)
                .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
        }
    }
}
