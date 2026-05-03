import SwiftUI

struct ProfileScreen: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var accessController: AccessController
    @EnvironmentObject private var languageController: AppLanguageController
    @EnvironmentObject private var themeController: AppThemeController
    @EnvironmentObject private var localLibraryController: LocalLibraryController
    @EnvironmentObject private var syncQueueController: SyncQueueController
    @EnvironmentObject private var selfHostedConfigController: SelfHostedConfigController
    @EnvironmentObject private var hostedSyncController: HostedSyncController

    let startSignInFlow: (Bool) -> Void
    @State private var isShowingSelfHostedSetup = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                shellBrandHeader

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("profile.title"))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AVPhotosysTheme.textPrimary)

                    Text(L10n.string("profile.subtitle"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AVPhotosysTheme.textSecondary)
                }

                accountManagementCard
                profileSummaryCard
                appPreferencesCard
                backendCard
                localDataCard
                helpAndLegalCard

                if accessController.accessMode != .guest {
                    accountSafetyCard
                }
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .background(AVPhotosysTheme.shellBackground.ignoresSafeArea())
        .sheet(isPresented: $isShowingSelfHostedSetup) {
            SelfHostedSetupSheet(onContinue: nil)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var shellBrandHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AVPhotosysTheme.highlight)

            Text(L10n.string("profile.statusTitle.account"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AVPhotosysTheme.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(AVPhotosysTheme.cardSurface)
                .overlay {
                    Capsule()
                        .stroke(AVPhotosysTheme.borderSubtle, lineWidth: 1)
                }
        )
    }

    private var profileSummaryCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                ProfileAvatar(initials: accessController.accountUser?.initials ?? "AV")

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AVPhotosysTheme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AVPhotosysTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
                .overlay(AVPhotosysTheme.borderSubtle)

            VStack(alignment: .leading, spacing: 12) {
                ShellRow(
                    systemImage: "person.crop.circle",
                    title: L10n.string("profile.summary.account.title"),
                    detail: accountSummaryDetail
                )
                ShellRow(
                    systemImage: "sparkles.rectangle.stack",
                    title: L10n.string("profile.summary.plan.title"),
                    detail: planSummaryDetail
                )
            }
        }
        .padding(22)
        .background(profileCardBackground)
    }

    private var accountManagementCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: L10n.string("profile.account.title"),
                subtitle: accountCardSubtitle
            )

            VStack(alignment: .leading, spacing: 12) {
                ShellRow(
                    systemImage: "person.badge.key",
                    title: L10n.string("profile.account.status.title"),
                    detail: accountStatusDetail
                )

                if let emailAddress = accessController.accountUser?.emailAddress {
                    ShellRow(
                        systemImage: "envelope",
                        title: L10n.string("profile.account.email.title"),
                        detail: emailAddress
                    )
                }
            }

            if accessController.accessMode == .guest {
                ProfilePrimaryButton(
                    title: accessController.accountIsAvailable
                        ? L10n.string("profile.account.connect")
                        : L10n.string("profile.account.connectUnavailable"),
                    action: { startSignInFlow(true) }
                )
                .disabled(!accessController.accountIsAvailable)
            } else {
                if let accountManagementURL = AppConfig.accountManagementURL {
                    ProfilePrimaryButton(
                        title: L10n.string("profile.account.manage"),
                        action: { open(accountManagementURL) }
                    )
                }

                ProfileSecondaryButton(
                    title: L10n.string("profile.actions.signOut"),
                    action: {
                        Task { await accessController.signOut() }
                    }
                )
            }
        }
        .padding(22)
        .background(profileCardBackground)
    }

    private var appPreferencesCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: L10n.string("profile.preferences.title"),
                subtitle: L10n.string("profile.preferences.subtitle")
            )

            ShellRow(
                systemImage: "globe",
                title: L10n.string("profile.preferences.language.title"),
                detail: L10n.string("profile.preferences.language.detail")
            )

            languageSelector

            if accessController.accessMode == .guest {
                ShellRow(
                    systemImage: "sparkles",
                    title: L10n.string("profile.preferences.accountPerk.title"),
                    detail: L10n.string("profile.preferences.accountPerk.detail")
                )
            }

            ShellRow(
                systemImage: "circle.lefthalf.filled",
                title: L10n.string("profile.preferences.theme.title"),
                detail: L10n.string("profile.preferences.theme.detail")
            )

            themeSelector
        }
        .padding(22)
        .background(profileCardBackground)
    }

    private var localDataCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: L10n.string("profile.local.title"),
                subtitle: L10n.string("profile.local.subtitle")
            )

            VStack(alignment: .leading, spacing: 12) {
                ShellRow(
                    systemImage: "photo.on.rectangle",
                    title: L10n.string("profile.local.selected.title"),
                    detail: "\(localLibraryController.selectedAssets.count)"
                )
                ShellRow(
                    systemImage: "arrow.triangle.2.circlepath",
                    title: L10n.string("profile.local.queue.title"),
                    detail: "\(syncQueueController.items.count)"
                )
                ShellRow(
                    systemImage: "externaldrive.badge.icloud",
                    title: L10n.string("profile.local.remote.title"),
                    detail: remoteSummary
                )
            }
        }
        .padding(22)
        .background(profileCardBackground)
    }

    private var backendCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: L10n.string("profile.backend.title"),
                subtitle: L10n.string("profile.backend.subtitle")
            )

            ShellRow(
                systemImage: "server.rack",
                title: L10n.string("profile.backend.mode.title"),
                detail: selfHostedConfigController.isConfigured
                    ? L10n.string("profile.backend.mode.selfHosted")
                    : L10n.string("profile.backend.mode.default")
            )

            ShellRow(
                systemImage: "link",
                title: L10n.string("profile.backend.baseURL.title"),
                detail: selfHostedConfigController.resolvedBaseURLString.isEmpty
                    ? L10n.string("profile.backend.baseURL.empty")
                    : selfHostedConfigController.resolvedBaseURLString
            )

            ProfilePrimaryButton(
                title: selfHostedConfigController.isConfigured
                    ? L10n.string("profile.backend.edit")
                    : L10n.string("profile.backend.configure"),
                action: { isShowingSelfHostedSetup = true }
            )
        }
        .padding(22)
        .background(profileCardBackground)
    }

    private var helpAndLegalCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: L10n.string("profile.help.title"),
                subtitle: L10n.string("profile.help.subtitle")
            )

            VStack(spacing: 12) {
                ShellRow(
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    title: L10n.string("profile.help.opensource.title"),
                    detail: L10n.string("profile.help.opensource.detail")
                )

                if let openSourceURL = AppConfig.openSourceURL {
                    ProfileActionRow(
                        systemImage: "book.pages",
                        title: L10n.string("profile.help.sourceCode.title"),
                        detail: L10n.string("profile.help.sourceCode.detail"),
                        action: { open(openSourceURL) }
                    )
                }

                if let supportURL = AppConfig.supportURL {
                    ProfileActionRow(
                        systemImage: "questionmark.bubble",
                        title: L10n.string("profile.help.support.title"),
                        detail: L10n.string("profile.help.support.detail"),
                        action: { open(supportURL) }
                    )
                }

                if let termsURL = AppConfig.termsURL {
                    ProfileActionRow(
                        systemImage: "doc.text",
                        title: L10n.string("profile.help.terms.title"),
                        detail: L10n.string("profile.help.terms.detail"),
                        action: { open(termsURL) }
                    )
                }

                if let privacyURL = AppConfig.privacyURL {
                    ProfileActionRow(
                        systemImage: "hand.raised",
                        title: L10n.string("profile.help.privacy.title"),
                        detail: L10n.string("profile.help.privacy.detail"),
                        action: { open(privacyURL) }
                    )
                }
            }
        }
        .padding(22)
        .background(profileCardBackground)
    }

    private var accountSafetyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: L10n.string("profile.safety.title"),
                subtitle: L10n.string("profile.safety.subtitle")
            )

            if let accountManagementURL = AppConfig.accountManagementURL {
                ProfileActionRow(
                    systemImage: "exclamationmark.shield",
                    title: L10n.string("profile.safety.delete.title"),
                    detail: L10n.string("profile.safety.delete.detail"),
                    action: { open(accountManagementURL) }
                )
            }
        }
        .padding(22)
        .background(profileCardBackground)
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AVPhotosysTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AVPhotosysTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var profileCardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(AVPhotosysTheme.cardSurface)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AVPhotosysTheme.borderSubtle, lineWidth: 1)
            }
    }

    private var displayName: String {
        accessController.accountUser?.displayName ?? L10n.string("profile.displayName.local")
    }

    private var subtitle: String {
        switch accessController.accessMode {
        case .guest:
            L10n.string("profile.subtitle.guest")
        case .signedInFree, .signedInPro:
            accessController.accountUser?.emailAddress
                ?? accessController.accountUser?.id
                ?? L10n.string("profile.subtitle.accountFallback")
        }
    }

    private var accountSummaryDetail: String {
        switch accessController.accessMode {
        case .guest:
            L10n.string("profile.summary.account.detail.guest")
        case .signedInFree, .signedInPro:
            L10n.string("profile.summary.account.detail.signedIn", displayName)
        }
    }

    private var planSummaryDetail: String {
        switch accessController.accessMode {
        case .guest:
            L10n.string("profile.summary.plan.detail.guest")
        case .signedInFree:
            L10n.string("profile.summary.plan.detail.free")
        case .signedInPro:
            L10n.string("profile.summary.plan.detail.pro")
        }
    }

    private var accountCardSubtitle: String {
        switch accessController.accessMode {
        case .guest:
            L10n.string("profile.account.subtitle.guest")
        case .signedInFree, .signedInPro:
            L10n.string("profile.account.subtitle.signedIn")
        }
    }

    private var accountStatusDetail: String {
        switch accessController.accessMode {
        case .guest:
            L10n.string("profile.account.status.guest")
        case .signedInFree, .signedInPro:
            L10n.string("profile.account.status.signedIn")
        }
    }

    private var languageSelection: Binding<AppLanguage> {
        Binding(
            get: { languageController.currentLanguage },
            set: { languageController.select($0) }
        )
    }

    private var themeSelection: Binding<AppTheme> {
        Binding(
            get: { themeController.currentTheme },
            set: { themeController.select($0) }
        )
    }

    private var languageSelector: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    languageSelection.wrappedValue = language
                } label: {
                    if languageController.currentLanguage == language {
                        Label {
                            Text("\(language.displayName) (\(language.autonym))")
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Text("\(language.displayName) (\(language.autonym))")
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(languageController.currentLanguage.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AVPhotosysTheme.textPrimary)

                    Text(languageController.currentLanguage.autonym)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AVPhotosysTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AVPhotosysTheme.highlight)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AVPhotosysTheme.mutedSurface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AVPhotosysTheme.borderSubtle, lineWidth: 1)
            }
        }
    }

    private var themeSelector: some View {
        HStack(spacing: 10) {
            ForEach(AppTheme.allCases) { theme in
                ThemeOptionButton(
                    title: themeLabel(for: theme),
                    systemImage: themeSymbol(for: theme),
                    isSelected: themeController.currentTheme == theme,
                    action: { themeSelection.wrappedValue = theme }
                )
            }
        }
    }

    private func themeLabel(for theme: AppTheme) -> String {
        switch theme {
        case .system:
            L10n.string("profile.preferences.theme.system")
        case .light:
            L10n.string("profile.preferences.theme.light")
        case .dark:
            L10n.string("profile.preferences.theme.dark")
        }
    }

    private func themeSymbol(for theme: AppTheme) -> String {
        switch theme {
        case .system:
            "circle.lefthalf.filled"
        case .light:
            "sun.max.fill"
        case .dark:
            "moon.fill"
        }
    }

    private var remoteSummary: String {
        switch hostedSyncController.hostedState {
        case .notConfigured:
            L10n.string("profile.remote.notConfigured")
        case .checking:
            L10n.string("profile.remote.checking")
        case .authRequired:
            L10n.string("profile.remote.authRequired")
        case .forbidden:
            L10n.string("profile.remote.forbidden")
        case .ready(let count):
            L10n.string("profile.remote.ready", count)
        case .failed:
            L10n.string("profile.remote.failed")
        }
    }

    private func open(_ url: URL) {
        openURL(url)
    }
}

private struct ProfileAvatar: View {
    let initials: String

    var body: some View {
        ZStack {
            Circle()
                .fill(AVPhotosysTheme.highlight.opacity(0.16))
                .frame(width: 64, height: 64)

            Text(initials)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AVPhotosysTheme.highlight)
        }
    }
}

private struct ShellRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AVPhotosysTheme.highlight)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AVPhotosysTheme.textPrimary)

                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AVPhotosysTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct ProfileActionRow: View {
    let systemImage: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AVPhotosysTheme.highlight)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AVPhotosysTheme.textPrimary)

                    Text(detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AVPhotosysTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AVPhotosysTheme.textSecondary)
            }
        }
    }
}

private struct ProfilePrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AVPhotosysTheme.brandBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AVPhotosysTheme.highlight, in: Capsule())
        }
    }
}

private struct ProfileSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AVPhotosysTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    Capsule()
                        .fill(AVPhotosysTheme.mutedSurface)
                        .overlay {
                            Capsule()
                                .stroke(AVPhotosysTheme.borderSubtle, lineWidth: 1)
                        }
                )
        }
    }
}

private struct ThemeOptionButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(isSelected ? AVPhotosysTheme.brandBlack : AVPhotosysTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? AVPhotosysTheme.highlight : AVPhotosysTheme.mutedSurface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? AVPhotosysTheme.highlight : AVPhotosysTheme.borderSubtle, lineWidth: 1)
            }
        }
    }
}
