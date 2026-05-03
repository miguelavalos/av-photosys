import ClerkKit
import Foundation

@MainActor
protocol AVAccountService {
    var isAvailable: Bool { get }
    var currentUser: PhotosAccountUser? { get }

    func getToken() async throws -> String?
    func signInWithApple() async throws
    func signInWithGoogle() async throws
    func signOut() async throws
}

enum AVAccountServiceError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            L10n.string("account.error.unavailable")
        }
    }
}

struct DefaultAVAccountService: AVAccountService {
    var isAvailable: Bool {
        AppConfig.isAVAccountAvailable
    }

    var currentUser: PhotosAccountUser? {
        guard isAvailable, let user = Clerk.shared.user else {
            return nil
        }

        let displayName =
            [user.firstName, user.lastName]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " ")

        return PhotosAccountUser(
            id: user.id,
            displayName: displayName.isEmpty ? L10n.string("account.displayName.listener") : displayName,
            emailAddress: user.primaryEmailAddress?.emailAddress
        )
    }

    func getToken() async throws -> String? {
        guard isAvailable else {
            return nil
        }

        if let token = try await Clerk.shared.session?.getToken(.init(skipCache: true)), !token.isEmpty {
            return token
        }

        if let fallbackSession = Clerk.shared.auth.sessions.first {
            try await Clerk.shared.auth.setActive(sessionId: fallbackSession.id)
            return try await Clerk.shared.session?.getToken(.init(skipCache: true))
        }

        return nil
    }

    func signInWithApple() async throws {
        guard isAvailable else {
            throw AVAccountServiceError.unavailable
        }

        let result = try await Clerk.shared.auth.signInWithApple()
        try await activateSession(from: result)
    }

    func signInWithGoogle() async throws {
        guard isAvailable else {
            throw AVAccountServiceError.unavailable
        }

        let result = try await Clerk.shared.auth.signInWithOAuth(provider: .google)
        try await activateSession(from: result)
    }

    func signOut() async throws {
        guard isAvailable else { return }
        try await Clerk.shared.auth.signOut()
    }

    private func activateSession(from result: TransferFlowResult) async throws {
        let createdSessionId: String? = switch result {
        case .signIn(let signIn):
            signIn.createdSessionId
        case .signUp(let signUp):
            signUp.createdSessionId
        }

        guard let createdSessionId, !createdSessionId.isEmpty else {
            return
        }

        try await Clerk.shared.auth.setActive(sessionId: createdSessionId)
    }
}
