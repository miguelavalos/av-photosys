import Foundation

enum AccessMode: String, Codable {
    case guest
    case signedInFree
    case signedInPro
}

struct PhotosAccountUser: Equatable {
    let id: String
    let displayName: String
    let emailAddress: String?

    var initials: String {
        let pieces = displayName.split(separator: " ")
        let initials = pieces.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return initials.isEmpty ? "AV" : initials.uppercased()
    }
}

@MainActor
final class AccessController: ObservableObject {
    @Published private(set) var accessMode: AccessMode
    @Published private(set) var accountUser: PhotosAccountUser?
    @Published private(set) var accessCapabilities: AccessCapabilities

    let accountService: AVAccountService

    private let userDefaults: UserDefaults
    private let apiClient: AVPhotosysAccessAPIClient
    private let onboardingPromptKey = "avphotosys.guestOnboarding.lastPromptAt"

    init(
        accountService: AVAccountService = SharedAccountService.instance,
        apiClient: AVPhotosysAccessAPIClient? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.accountService = accountService
        self.userDefaults = userDefaults
        self.accountUser = accountService.currentUser
        let initialAccessMode: AccessMode = accountService.currentUser == nil ? .guest : .signedInFree
        self.accessMode = initialAccessMode
        self.accessCapabilities = .forMode(initialAccessMode)
        self.apiClient = apiClient ?? AVPhotosysAccessAPIClient(getToken: { try await accountService.getToken() })
    }

    var accountIsAvailable: Bool {
        accountService.isAvailable
    }

    var hasEverSeenGuestOnboarding: Bool {
        userDefaults.object(forKey: onboardingPromptKey) as? Date != nil
    }

    var shouldAutoShowGuestOnboarding: Bool {
        guard accessMode == .guest else { return false }
        guard let lastPromptAt = userDefaults.object(forKey: onboardingPromptKey) as? Date else {
            return true
        }

        return Date() >= lastPromptAt.addingTimeInterval(10 * 24 * 60 * 60)
    }

    func syncFromAccountProvider() async {
        accountUser = accountService.currentUser
        accessMode = accountUser == nil ? .guest : .signedInFree
        accessCapabilities = .forMode(accessMode)
        await refreshBackendAccess()
    }

    func markGuestOnboardingPromptShown() {
        userDefaults.set(Date(), forKey: onboardingPromptKey)
    }

    func skipForNow() {
        markGuestOnboardingPromptShown()
        accessMode = .guest
    }

    func signInWithApple() async throws {
        try await accountService.signInWithApple()
        markGuestOnboardingPromptShown()
        await syncFromAccountProvider()
    }

    func signInWithGoogle() async throws {
        try await accountService.signInWithGoogle()
        markGuestOnboardingPromptShown()
        await syncFromAccountProvider()
    }

    func signOut() async {
        try? await accountService.signOut()
        await syncFromAccountProvider()
    }

    private func refreshBackendAccess() async {
        guard accountUser != nil else { return }
        guard apiClient.isConfigured() else { return }

        do {
            let payload = try await apiClient.fetchMeAccess()
            guard let access = payload.apps.first(where: { $0.appId == "avphotosys" }) else {
                return
            }

            accessMode = access.accessMode
            accessCapabilities = access.capabilities
        } catch {
            accessMode = .signedInFree
            accessCapabilities = .forMode(.signedInFree)
        }
    }
}

struct AccessCapabilities: Codable, Equatable {
    let isSignedIn: Bool
    let canUseBackend: Bool
    let canUsePremiumFeatures: Bool
    let canUseCloudSync: Bool
    let canManagePlan: Bool

    static func forMode(_ mode: AccessMode) -> AccessCapabilities {
        AccessCapabilities(
            isSignedIn: mode != .guest,
            canUseBackend: mode != .guest,
            canUsePremiumFeatures: mode == .signedInPro,
            canUseCloudSync: mode == .signedInPro,
            canManagePlan: mode != .guest
        )
    }
}

private struct MeAccessResponse: Decodable {
    let apps: [AppAccess]
}

private struct AppAccess: Decodable {
    let appId: String
    let accessMode: AccessMode
    let capabilities: AccessCapabilities
}

enum AVPhotosysAccessAPIClientError: LocalizedError {
    case missingToken
    case missingBaseURL
    case requestFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Missing AV Account token."
        case .missingBaseURL:
            "Missing AV Account API base URL."
        case .requestFailed(let statusCode):
            "AV Account API request failed with status \(statusCode)."
        }
    }
}

@MainActor
final class AVPhotosysAccessAPIClient {
    private let getToken: () async throws -> String?
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        getToken: @escaping () async throws -> String?,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.getToken = getToken
        self.session = session
        self.decoder = decoder
    }

    func isConfigured() -> Bool {
        AppConfig.avAccountAPIBaseURL != nil
    }

    fileprivate func fetchMeAccess() async throws -> MeAccessResponse {
        guard let token = try await getToken(), !token.isEmpty else {
            throw AVPhotosysAccessAPIClientError.missingToken
        }
        guard let baseURL = AppConfig.avAccountAPIBaseURL else {
            throw AVPhotosysAccessAPIClientError.missingBaseURL
        }

        var request = URLRequest(url: baseURL.appending(path: "v1/me/access"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AVPhotosysAccessAPIClientError.requestFailed(statusCode: httpResponse.statusCode)
        }

        return try decoder.decode(MeAccessResponse.self, from: data)
    }
}
