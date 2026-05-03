import Foundation

@MainActor
final class SelfHostedConfigController: ObservableObject {
    @Published var baseURLString: String
    @Published var authToken: String

    init() {
        self.baseURLString = AppConfig.selfHostedBaseURLString ?? ""
        self.authToken = AppConfig.selfHostedAuthToken ?? ""
    }

    var isConfigured: Bool {
        AppConfig.isUsingSelfHostedOverride
    }

    var hasValidBaseURL: Bool {
        AppConfig.hasValidSelfHostedBaseURL(baseURLString)
    }

    var resolvedBaseURLString: String {
        AppConfig.selfHostedBaseURLString ?? (AppConfig.avAccountAPIBaseURL?.absoluteString ?? "")
    }

    func reload() {
        baseURLString = AppConfig.selfHostedBaseURLString ?? ""
        authToken = AppConfig.selfHostedAuthToken ?? ""
    }

    func save() {
        AppConfig.saveSelfHostedConfiguration(
            baseURLString: baseURLString,
            authToken: authToken
        )
        reload()
    }

    func clear() {
        AppConfig.clearSelfHostedConfiguration()
        reload()
    }
}
