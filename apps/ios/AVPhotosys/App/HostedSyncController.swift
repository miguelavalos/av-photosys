import Foundation
import UIKit

@MainActor
final class HostedSyncController: ObservableObject {
    enum HostedState: Equatable {
        case notConfigured
        case checking
        case authRequired
        case forbidden(String)
        case ready(assetCount: Int)
        case failed(String)
    }

    @Published private(set) var hostedState: HostedState = .notConfigured
    @Published private(set) var assets: [HostedPhotoAsset] = []
    @Published private(set) var recentChanges: [HostedPhotoAsset] = []
    @Published private(set) var lastRefreshedAt: Date?
    @Published private(set) var deletingAssetID: String?
    @Published private(set) var changesCursor: String?
    @Published private(set) var nextAssetsCursor: String?
    @Published private(set) var isLoadingMoreAssets = false
    @Published private(set) var totalRemoteAssetCount = 0

    private let userDefaults: UserDefaults
    private let recentChangesKey = "avphotosys.hosted.recentChanges"
    private let changesCursorKey = "avphotosys.hosted.changesCursor"
    private let maxStoredChanges = 10
    private let assetPageSize = 60
    private var previewImageCache: [String: UIImage] = [:]

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let data = userDefaults.data(forKey: recentChangesKey),
           let decoded = try? JSONDecoder().decode([HostedPhotoAsset].self, from: data) {
            recentChanges = decoded
        } else {
            recentChanges = []
        }

        changesCursor = userDefaults.string(forKey: changesCursorKey)
    }

    func refresh() async {
        guard let baseURL = AppConfig.avAccountAPIBaseURL else {
            hostedState = .notConfigured
            assets = []
            recentChanges = []
            changesCursor = nil
            nextAssetsCursor = nil
            totalRemoteAssetCount = 0
            lastRefreshedAt = nil
            persistChangesState()
            return
        }

        hostedState = .checking

        let result = await probeConnection(
            baseURL: baseURL,
            authToken: AppConfig.isUsingSelfHostedOverride ? AppConfig.selfHostedAuthToken : nil
        )
        assets = result.assets
        recentChanges = mergedRecentChanges(current: recentChanges, incoming: result.changes)
        changesCursor = result.changesCursor
        nextAssetsCursor = result.assetsCursor
        totalRemoteAssetCount = result.totalAssetCount
        hostedState = result.state
        lastRefreshedAt = result.lastRefreshedAt
        persistChangesState()
    }

    func loadMoreAssets() async {
        guard let baseURL = AppConfig.avAccountAPIBaseURL, let cursor = nextAssetsCursor, !cursor.isEmpty else {
            return
        }

        isLoadingMoreAssets = true
        defer { isLoadingMoreAssets = false }

        let client = makeClient(
            baseURL: baseURL,
            authToken: AppConfig.isUsingSelfHostedOverride ? AppConfig.selfHostedAuthToken : nil
        )

        do {
            let response = try await client.listAssets(cursor: cursor, limit: assetPageSize)
            var seen = Set(assets.map(\.assetId))
            let appendedAssets = response.assets.filter { seen.insert($0.assetId).inserted }
            assets.append(contentsOf: appendedAssets)
            nextAssetsCursor = response.cursor
            totalRemoteAssetCount = response.totalCount
            hostedState = .ready(assetCount: totalRemoteAssetCount)
            lastRefreshedAt = .now
        } catch {
            hostedState = .failed(error.localizedDescription)
        }
    }

    func probeConnection(baseURL: URL, authToken: String?) async -> ProbeResult {
        let client = makeClient(baseURL: baseURL, authToken: authToken)

        do {
            _ = try await client.fetchHealth()
        } catch {
            return ProbeResult(
                state: .failed("Health check failed: \(error.localizedDescription)"),
                assets: [],
                assetsCursor: nil,
                totalAssetCount: 0,
                changes: [],
                changesCursor: nil,
                lastRefreshedAt: nil
            )
        }

        let response: HostedPhotoAssetListResponse
        do {
            response = try await client.listAssets(limit: assetPageSize)
        } catch let error as AVPhotosysAPIClientError {
            switch error {
            case .authRequired:
                return ProbeResult(state: .authRequired, assets: [], assetsCursor: nil, totalAssetCount: 0, changes: [], changesCursor: nil, lastRefreshedAt: nil)
            case .forbidden(let message):
                return ProbeResult(state: .forbidden(message), assets: [], assetsCursor: nil, totalAssetCount: 0, changes: [], changesCursor: nil, lastRefreshedAt: nil)
            default:
                return ProbeResult(
                    state: .failed(error.localizedDescription),
                    assets: [],
                    assetsCursor: nil,
                    totalAssetCount: 0,
                    changes: [],
                    changesCursor: nil,
                    lastRefreshedAt: nil
                )
            }
        } catch {
            return ProbeResult(
                state: .failed("Asset listing failed: \(error.localizedDescription)"),
                assets: [],
                assetsCursor: nil,
                totalAssetCount: 0,
                changes: [],
                changesCursor: nil,
                lastRefreshedAt: nil
            )
        }

        let changesResponse: HostedPhotoAssetChangesResponse
        do {
            changesResponse = try await client.listChanges(cursor: changesCursor)
        } catch let error as AVPhotosysAPIClientError {
            switch error {
            case .authRequired:
                return ProbeResult(state: .authRequired, assets: response.assets, assetsCursor: response.cursor, totalAssetCount: response.totalCount, changes: [], changesCursor: changesCursor, lastRefreshedAt: nil)
            case .forbidden(let message):
                return ProbeResult(state: .forbidden(message), assets: response.assets, assetsCursor: response.cursor, totalAssetCount: response.totalCount, changes: [], changesCursor: changesCursor, lastRefreshedAt: nil)
            default:
                return ProbeResult(
                    state: .failed(error.localizedDescription),
                    assets: response.assets,
                    assetsCursor: response.cursor,
                    totalAssetCount: response.totalCount,
                    changes: [],
                    changesCursor: changesCursor,
                    lastRefreshedAt: nil
                )
            }
        } catch {
            return ProbeResult(
                state: .failed("Change feed failed: \(error.localizedDescription)"),
                assets: response.assets,
                assetsCursor: response.cursor,
                totalAssetCount: response.totalCount,
                changes: [],
                changesCursor: changesCursor,
                lastRefreshedAt: nil
            )
        }

        return ProbeResult(
            state: .ready(assetCount: response.totalCount),
            assets: response.assets,
            assetsCursor: response.cursor,
            totalAssetCount: response.totalCount,
            changes: changesResponse.changes,
            changesCursor: changesResponse.cursor,
            lastRefreshedAt: .now
        )
    }

    func deleteAsset(_ asset: HostedPhotoAsset) async throws {
        guard let baseURL = AppConfig.avAccountAPIBaseURL else {
            hostedState = .notConfigured
            assets = []
            recentChanges = []
            changesCursor = nil
            nextAssetsCursor = nil
            totalRemoteAssetCount = 0
            lastRefreshedAt = nil
            return
        }

        deletingAssetID = asset.assetId
        defer { deletingAssetID = nil }

        let client = makeClient(
            baseURL: baseURL,
            authToken: AppConfig.isUsingSelfHostedOverride ? AppConfig.selfHostedAuthToken : nil
        )

        _ = try await client.deleteAsset(assetID: asset.assetId)
        assets.removeAll { $0.assetId == asset.assetId }
        recentChanges.insert(
            HostedPhotoAsset(
                assetId: asset.assetId,
                deviceId: asset.deviceId,
                sourceLocalIdentifier: asset.sourceLocalIdentifier,
                originalFilename: asset.originalFilename,
                mediaType: asset.mediaType,
                captureTakenAt: asset.captureTakenAt,
                importedAt: asset.importedAt,
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight,
                byteSize: asset.byteSize,
                sha256: asset.sha256,
                storageKeyOriginal: asset.storageKeyOriginal,
                previewPath: nil,
                syncStatus: "deleted",
                deletedAt: ISO8601DateFormatter().string(from: .now),
                updatedAt: ISO8601DateFormatter().string(from: .now)
            ),
            at: 0
        )
        recentChanges = Array(recentChanges.prefix(maxStoredChanges))
        totalRemoteAssetCount = max(0, totalRemoteAssetCount - 1)
        hostedState = .ready(assetCount: totalRemoteAssetCount)
        lastRefreshedAt = .now
        changesCursor = recentChanges.first?.updatedAt ?? changesCursor
        persistChangesState()
    }

    func previewImage(for asset: HostedPhotoAsset) async throws -> UIImage? {
        guard let previewPath = asset.previewPath, !previewPath.isEmpty else {
            return nil
        }

        if let cachedImage = previewImageCache[previewPath] {
            return cachedImage
        }

        guard let baseURL = AppConfig.avAccountAPIBaseURL else {
            return nil
        }

        let client = makeClient(
            baseURL: baseURL,
            authToken: AppConfig.isUsingSelfHostedOverride ? AppConfig.selfHostedAuthToken : nil
        )
        let data = try await client.fetchPreviewData(path: previewPath)

        guard let image = UIImage(data: data) else {
            return nil
        }

        previewImageCache[previewPath] = image
        return image
    }

    private func makeClient(baseURL: URL, authToken: String?) -> AVPhotosysAPIClient {
        AVPhotosysAPIClient(
            baseURL: baseURL,
            authToken: authToken,
            authTokenProvider: {
                try await SharedAccountService.getToken()
            }
        )
    }

    private func mergedRecentChanges(current: [HostedPhotoAsset], incoming: [HostedPhotoAsset]) -> [HostedPhotoAsset] {
        var seen = Set<String>()
        var merged: [HostedPhotoAsset] = []

        for asset in (incoming + current) {
            let key = "\(asset.assetId)|\(asset.updatedAt)|\(asset.syncStatus)"
            guard seen.insert(key).inserted else { continue }
            merged.append(asset)
        }

        merged.sort { lhs, rhs in
            lhs.updatedAt > rhs.updatedAt
        }

        return Array(merged.prefix(maxStoredChanges))
    }

    private func persistChangesState() {
        if let data = try? JSONEncoder().encode(recentChanges) {
            userDefaults.set(data, forKey: recentChangesKey)
        }

        userDefaults.set(changesCursor, forKey: changesCursorKey)
    }
}

extension HostedSyncController {
    struct ProbeResult {
        let state: HostedState
        let assets: [HostedPhotoAsset]
        let assetsCursor: String?
        let totalAssetCount: Int
        let changes: [HostedPhotoAsset]
        let changesCursor: String?
        let lastRefreshedAt: Date?
    }
}
