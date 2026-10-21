import SwiftUI

@main
struct AetherScanApp: App {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var updateController = AppUpdateController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 920, minHeight: 680)
                .environmentObject(updateController)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L10n.text("about.menuItem")) {
                    openWindow(id: "about")
                }
                Divider()
                Button(L10n.text("update.menuItem")) {
                    updateController.checkForUpdates()
                    openWindow(id: "about")
                }
                .disabled(updateController.isBusy || updateController.hasReadyUpdate)
            }
        }

        Window(L10n.text("about.title"), id: "about") {
            AboutView()
                .environmentObject(updateController)
                .frame(width: 500, height: 500)
        }
        .windowResizability(.contentSize)
    }
}
