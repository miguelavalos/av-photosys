import SwiftUI

struct RootView: View {
    @EnvironmentObject private var accessController: AccessController
    @State private var authOptionsArePresented = false
    @State private var automaticGuestOnboardingIsPresented = false
    @State private var isShowingAccountOnboarding = false
    @State private var selectedTab: RootTab = .library

    var body: some View {
        Group {
            if shouldShowOnboarding {
                AuthOnboardingView(
                    authOptionsArePresented: $authOptionsArePresented,
                    accountIsAvailable: accessController.accountIsAvailable,
                    onContinueWithApple: startAppleSignIn,
                    onContinueWithGoogle: startGoogleSignIn,
                    onSkip: {
                        automaticGuestOnboardingIsPresented = false
                        isShowingAccountOnboarding = false
                        accessController.skipForNow()
                    }
                )
            } else {
                TabView(selection: $selectedTab) {
                    LibrarySelectionView()
                        .tag(RootTab.library)
                        .tabItem {
                            Label(L10n.string("tab.library"), systemImage: "photo.on.rectangle")
                        }

                    SyncQueueView()
                        .tag(RootTab.sync)
                        .tabItem {
                            Label(L10n.string("tab.sync"), systemImage: "arrow.triangle.2.circlepath")
                        }

                    HostedGalleryView()
                        .tag(RootTab.remote)
                        .tabItem {
                            Label(L10n.string("tab.remote"), systemImage: "photo.stack.fill")
                        }

                    ProfileScreen(startSignInFlow: startSignInFlow)
                        .tag(RootTab.profile)
                        .tabItem {
                            Label(L10n.string("tab.profile"), systemImage: "person.crop.circle")
                        }
                }
                .tint(AVPhotosysTheme.highlight)
                .background(AVPhotosysTheme.shellBackground.ignoresSafeArea())
            }
        }
        .task {
            await accessController.syncFromAccountProvider()
            presentAutomaticGuestOnboardingIfNeeded()
        }
        .onAppear {
            presentAutomaticGuestOnboardingIfNeeded()
        }
        .onChange(of: accessController.accessMode) { _, _ in
            authOptionsArePresented = false

            if accessController.accessMode != .guest {
                automaticGuestOnboardingIsPresented = false
                isShowingAccountOnboarding = false
            } else {
                presentAutomaticGuestOnboardingIfNeeded()
            }
        }
    }

    private var shouldShowOnboarding: Bool {
        isShowingAccountOnboarding || automaticGuestOnboardingIsPresented
    }

    private func startSignInFlow(_ showAuthOptions: Bool = false) {
        authOptionsArePresented = showAuthOptions
        isShowingAccountOnboarding = true
    }

    private func startAppleSignIn() async throws {
        try await accessController.signInWithApple()
        automaticGuestOnboardingIsPresented = false
        isShowingAccountOnboarding = false
        selectedTab = .sync
    }

    private func startGoogleSignIn() async throws {
        try await accessController.signInWithGoogle()
        automaticGuestOnboardingIsPresented = false
        isShowingAccountOnboarding = false
        selectedTab = .sync
    }

    private func presentAutomaticGuestOnboardingIfNeeded() {
        guard automaticGuestOnboardingIsPresented == false else { return }
        guard isShowingAccountOnboarding == false else { return }
        guard accessController.accessMode == .guest else { return }

        if accessController.hasEverSeenGuestOnboarding == false {
            accessController.markGuestOnboardingPromptShown()
            automaticGuestOnboardingIsPresented = true
            return
        }

        guard accessController.shouldAutoShowGuestOnboarding else { return }

        accessController.markGuestOnboardingPromptShown()
        automaticGuestOnboardingIsPresented = true
    }
}

private enum RootTab {
    case library
    case sync
    case remote
    case profile
}
