import SwiftUI

struct SelfHostedSetupSheet: View {
    private enum ConnectionState: Equatable {
        case idle
        case testing
        case success(String)
        case failure(String)
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var selfHostedConfigController: SelfHostedConfigController
    @EnvironmentObject private var hostedSyncController: HostedSyncController

    let onContinue: (() -> Void)?
    @State private var connectionState: ConnectionState = .idle
    @State private var isTokenVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("auth.selfHosted.title"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AVPhotosysTheme.textPrimary)

                    Text(L10n.string("auth.selfHosted.subtitle"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AVPhotosysTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                setupStep(
                    number: "1",
                    title: L10n.string("auth.selfHosted.step1.title"),
                    detail: L10n.string("auth.selfHosted.step1.detail")
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("auth.selfHosted.step2.title"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AVPhotosysTheme.textPrimary)

                    TextField("https://photos.example.com", text: $selfHostedConfigController.baseURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(AVPhotosysTheme.cardSurface)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(AVPhotosysTheme.borderSubtle, lineWidth: 1)
                                }
                        )

                    if !selfHostedConfigController.baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       !selfHostedConfigController.hasValidBaseURL {
                        Text(L10n.string("auth.selfHosted.validation.baseURL"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AVPhotosysTheme.warning)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("auth.selfHosted.step3.title"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AVPhotosysTheme.textPrimary)

                    HStack(spacing: 10) {
                        Group {
                            if isTokenVisible {
                                TextField("Bearer token (optional)", text: $selfHostedConfigController.authToken)
                            } else {
                                SecureField("Bearer token (optional)", text: $selfHostedConfigController.authToken)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        Button(isTokenVisible ? L10n.string("auth.selfHosted.token.hide") : L10n.string("auth.selfHosted.token.show")) {
                            isTokenVisible.toggle()
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AVPhotosysTheme.highlight)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AVPhotosysTheme.cardSurface)
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(AVPhotosysTheme.borderSubtle, lineWidth: 1)
                            }
                    )
                }

                Text(L10n.string("auth.selfHosted.footer"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AVPhotosysTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if connectionState != .idle {
                    connectionStatusCard
                }

                VStack(spacing: 12) {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack(spacing: 8) {
                            if connectionState == .testing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(AVPhotosysTheme.textPrimary)
                            }

                            Text(L10n.string("auth.selfHosted.test"))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AVPhotosysTheme.textPrimary)
                        }
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
                    .disabled(!selfHostedConfigController.hasValidBaseURL || connectionState == .testing)

                    Button {
                        selfHostedConfigController.save()
                        Task { await hostedSyncController.refresh() }
                        dismiss()
                        onContinue?()
                    } label: {
                        Text(L10n.string("auth.selfHosted.save"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AVPhotosysTheme.brandBlack)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AVPhotosysTheme.highlight, in: Capsule())
                    }
                    .disabled(!selfHostedConfigController.hasValidBaseURL || connectionState == .testing)

                    if selfHostedConfigController.isConfigured {
                        Button {
                            selfHostedConfigController.clear()
                            connectionState = .idle
                            Task { await hostedSyncController.refresh() }
                        } label: {
                            Text(L10n.string("auth.selfHosted.clear"))
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
            }
            .padding(24)
        }
        .background(AVPhotosysTheme.shellBackground.ignoresSafeArea())
        .onAppear {
            selfHostedConfigController.reload()
        }
        .onChange(of: selfHostedConfigController.baseURLString) { _, _ in
            if connectionState != .testing {
                connectionState = .idle
            }
        }
        .onChange(of: selfHostedConfigController.authToken) { _, _ in
            if connectionState != .testing {
                connectionState = .idle
            }
        }
    }

    private func setupStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AVPhotosysTheme.brandBlack)
                .frame(width: 28, height: 28)
                .background(AVPhotosysTheme.highlight, in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AVPhotosysTheme.textPrimary)

                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AVPhotosysTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AVPhotosysTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AVPhotosysTheme.borderSubtle, lineWidth: 1)
                }
        )
    }

    private var connectionStatusCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: connectionStatusIconName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(connectionStatusColor)
                .frame(width: 20)

            Text(connectionStatusText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AVPhotosysTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AVPhotosysTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(connectionStatusColor.opacity(0.4), lineWidth: 1)
                }
        )
    }

    private var connectionStatusIconName: String {
        switch connectionState {
        case .idle:
            "circle.dashed"
        case .testing:
            "bolt.horizontal.circle"
        case .success:
            "checkmark.circle.fill"
        case .failure:
            "exclamationmark.triangle.fill"
        }
    }

    private var connectionStatusColor: Color {
        switch connectionState {
        case .idle:
            AVPhotosysTheme.textSecondary
        case .testing:
            AVPhotosysTheme.highlight
        case .success:
            .green
        case .failure:
            AVPhotosysTheme.warning
        }
    }

    private var connectionStatusText: String {
        switch connectionState {
        case .idle:
            ""
        case .testing:
            L10n.string("auth.selfHosted.test.checking")
        case .success(let message), .failure(let message):
            message
        }
    }

    private func testConnection() async {
        guard let baseURL = AppConfig.selfHostedURL(from: selfHostedConfigController.baseURLString) else {
            connectionState = .failure(L10n.string("auth.selfHosted.validation.baseURL"))
            return
        }

        connectionState = .testing
        let token = selfHostedConfigController.authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = await hostedSyncController.probeConnection(
            baseURL: baseURL,
            authToken: token.isEmpty ? nil : token
        )

        switch result.state {
        case .ready(let assetCount):
            connectionState = .success(L10n.string("auth.selfHosted.test.success", assetCount))
        case .authRequired:
            connectionState = .failure(L10n.string("auth.selfHosted.test.authRequired"))
        case .forbidden(let message):
            connectionState = .failure(message)
        case .failed(let message):
            connectionState = .failure(message)
        case .notConfigured:
            connectionState = .failure(L10n.string("auth.selfHosted.validation.baseURL"))
        case .checking:
            connectionState = .testing
        }
    }
}
