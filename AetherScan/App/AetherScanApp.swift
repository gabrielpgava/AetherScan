import SwiftUI

@main
struct AetherScanApp: App {
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 920, minHeight: 680)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L10n.text("about.menuItem")) {
                    openWindow(id: "about")
                }
            }
        }

        Window(L10n.text("about.title"), id: "about") {
            AboutView()
                .frame(width: 480, height: 400)
        }
        .windowResizability(.contentSize)
    }
}
