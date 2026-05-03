import SwiftUI

@main
struct AVPhotosysApp: App {
    init() {
        AppConfig.configureAVAccountIfPossible()
    }

    @StateObject private var permissionController = PhotoPermissionController()
    @StateObject private var hostedSyncController = HostedSyncController()
    @StateObject private var localLibraryController = LocalLibraryController()
    @StateObject private var syncQueueController = SyncQueueController()
    @StateObject private var selfHostedConfigController = SelfHostedConfigController()
    @StateObject private var accessController = AccessController()
    @StateObject private var languageController = AppLanguageController()
    @StateObject private var themeController = AppThemeController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(permissionController)
                .environmentObject(hostedSyncController)
                .environmentObject(localLibraryController)
                .environmentObject(syncQueueController)
                .environmentObject(selfHostedConfigController)
                .environmentObject(accessController)
                .environmentObject(languageController)
                .environment(\.locale, languageController.locale)
                .environmentObject(themeController)
                .preferredColorScheme(themeController.currentTheme.preferredColorScheme)
        }
    }
}
