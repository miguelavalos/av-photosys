import Foundation

enum SharedAccountService {
    @MainActor
    static let instance: AVAccountService = DefaultAVAccountService()

    @MainActor
    static func getToken() async throws -> String? {
        try await instance.getToken()
    }
}
