import Foundation

@MainActor
final class SyncQueueController: ObservableObject {
    @Published private(set) var items: [SyncQueueItem]
    @Published private(set) var isSyncing = false
    @Published private(set) var lastRunSummary: SyncRunSummary?
    @Published private(set) var currentSyncFilename: String?

    private let userDefaults: UserDefaults
    private let queueKey = "avphotosys.syncQueue"
    private let deviceIDKey = "avphotosys.deviceID"
    private let photoLibraryService: PhotoLibraryService
    private let maxAttemptCount = 3

    init(
        userDefaults: UserDefaults = .standard,
        photoLibraryService: PhotoLibraryService = PhotoLibraryService()
    ) {
        self.userDefaults = userDefaults
        self.photoLibraryService = photoLibraryService

        if let data = userDefaults.data(forKey: queueKey),
           let decoded = try? JSONDecoder().decode([SyncQueueItem].self, from: data) {
            self.items = Self.compacted(decoded)
        } else {
            self.items = []
        }

        persist()
    }

    var pendingCount: Int {
        items.filter { $0.status == .pending }.count
    }

    var activeCount: Int {
        items.filter { [.preparing, .uploading, .committing].contains($0.status) }.count
    }

    var failedCount: Int {
        items.filter { $0.status == .failed }.count
    }

    var completedCount: Int {
        items.filter { $0.status == .completed }.count
    }

    var totalTrackedCount: Int {
        items.count
    }

    var overallProgress: Double {
        guard !items.isEmpty else { return 0 }
        let total = items.reduce(0.0) { partial, item in
            partial + item.status.progressValue
        }

        return total / Double(items.count)
    }

    var deviceID: String {
        if let existing = userDefaults.string(forKey: deviceIDKey) {
            return existing
        }

        let created = UUID().uuidString.lowercased()
        userDefaults.set(created, forKey: deviceIDKey)
        return created
    }

    func enqueue(_ assets: [LocalPhotoAsset]) {
        for asset in assets {
            guard !items.contains(where: { $0.localIdentifier == asset.localIdentifier }) else {
                continue
            }

            items.append(
                SyncQueueItem(
                    id: UUID().uuidString,
                    localIdentifier: asset.localIdentifier,
                    filename: asset.filename,
                    createdAt: .now,
                    status: .pending,
                    lastMessage: nil,
                    remoteAssetId: nil,
                    attemptCount: 0,
                    lastAttemptAt: nil,
                    completedAt: nil
                )
            )
        }

        persist()
    }

    func syncPending() async {
        guard !isSyncing else { return }
        guard let baseURL = AppConfig.avAccountAPIBaseURL else {
            updateAllPendingFailures(message: "Hosted sync is not configured.")
            return
        }

        let client = AVPhotosysAPIClient(
            baseURL: baseURL,
            authToken: AppConfig.isUsingSelfHostedOverride ? AppConfig.selfHostedAuthToken : nil,
            authTokenProvider: {
                try await SharedAccountService.getToken()
            }
        )

        isSyncing = true
        lastRunSummary = nil
        currentSyncFilename = nil
        defer {
            isSyncing = false
            currentSyncFilename = nil
            persist()
        }

        var syncedCount = 0
        var skippedCount = 0
        var failedCount = 0

        for index in items.indices {
            if items[index].status == .completed {
                continue
            }

            currentSyncFilename = items[index].filename
            let result = await syncItem(at: index, with: client)
            switch result {
            case .synced:
                syncedCount += 1
            case .skipped:
                skippedCount += 1
            case .failed:
                failedCount += 1
            }
        }

        lastRunSummary = SyncRunSummary(
            syncedCount: syncedCount,
            skippedCount: skippedCount,
            failedCount: failedCount,
            finishedAt: .now
        )
    }

    func retryFailed() {
        for index in items.indices where items[index].status == .failed {
            items[index].status = .pending
            items[index].lastMessage = nil
            items[index].completedAt = nil
        }

        persist()
    }

    func clearCompleted() {
        items.removeAll { $0.status == .completed }
        persist()
    }

    private func syncItem(at index: Int, with client: AVPhotosysAPIClient) async -> SyncOutcome {
        for attempt in 1 ... maxAttemptCount {
            do {
                items[index].attemptCount = attempt
                items[index].lastAttemptAt = .now
                items[index].completedAt = nil
                items[index].status = .preparing
                items[index].lastMessage = attempt == 1
                    ? "Loading local asset metadata"
                    : "Retrying upload preparation"

                let payload = try await photoLibraryService.fetchUploadPayload(for: items[index].localIdentifier)
                let prepare = try await client.prepareUpload(
                    deviceID: deviceID,
                    localIdentifier: payload.asset.localIdentifier,
                    filename: payload.asset.filename,
                    captureTakenAt: payload.captureTakenAt,
                    byteSize: payload.data.count,
                    pixelWidth: payload.asset.pixelWidth,
                    pixelHeight: payload.asset.pixelHeight,
                    sha256: payload.sha256
                )

                items[index].remoteAssetId = prepare.assetId

                if prepare.shouldUpload {
                    items[index].status = .uploading
                    items[index].lastMessage = attempt == 1
                        ? "Uploading bytes"
                        : "Retrying byte upload"
                    try await client.uploadPreparedAsset(uploadURLPath: prepare.uploadUrl, data: payload.data)

                    items[index].status = .committing
                    items[index].lastMessage = "Committing remote metadata"
                    _ = try await client.commitUpload(
                        assetID: prepare.assetId,
                        uploadToken: prepare.uploadToken,
                        deviceID: deviceID
                    )
                } else {
                    items[index].lastMessage = prepare.assetAlreadyExists
                        ? "Remote asset already exists"
                        : "Upload was skipped by the backend"
                }

                items[index].status = .completed
                items[index].lastMessage = prepare.shouldUpload
                    ? "Sync completed"
                    : items[index].lastMessage
                items[index].completedAt = .now
                return prepare.shouldUpload ? .synced : .skipped
            } catch {
                if shouldRetry(error) && attempt < maxAttemptCount {
                    items[index].status = .pending
                    items[index].lastMessage = "Transient error. Retrying shortly."
                    persist()
                    try? await Task.sleep(for: .milliseconds(backoffMilliseconds(for: attempt)))
                    continue
                }

                items[index].status = .failed
                items[index].lastMessage = error.localizedDescription
                return .failed
            }
        }

        items[index].status = .failed
        items[index].lastMessage = "Sync failed after multiple attempts."
        return .failed
    }

    private func updateAllPendingFailures(message: String) {
        for index in items.indices where items[index].status != .completed {
            items[index].status = .failed
            items[index].lastMessage = message
        }

        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            userDefaults.set(data, forKey: queueKey)
        }
    }

    private func shouldRetry(_ error: Error) -> Bool {
        if let apiError = error as? AVPhotosysAPIClientError {
            switch apiError {
            case .authRequired, .forbidden, .invalidUploadTarget, .notConfigured:
                return false
            case .server, .invalidResponse:
                return true
            }
        }

        if error is URLError {
            return true
        }

        return false
    }

    private func backoffMilliseconds(for attempt: Int) -> Int {
        switch attempt {
        case 1:
            700
        case 2:
            1400
        default:
            2000
        }
    }

    private static func compacted(_ items: [SyncQueueItem]) -> [SyncQueueItem] {
        let grouped = Dictionary(grouping: items, by: \.localIdentifier)

        return grouped.values
            .compactMap { group in
                group.min(by: isPreferred(_:over:))
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private static func isPreferred(_ lhs: SyncQueueItem, over rhs: SyncQueueItem) -> Bool {
        let lhsPriority = statusPriority(lhs.status)
        let rhsPriority = statusPriority(rhs.status)

        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }

        return comparisonDate(for: lhs) < comparisonDate(for: rhs)
    }

    private static func statusPriority(_ status: SyncQueueItemStatus) -> Int {
        switch status {
        case .completed:
            return 0
        case .committing:
            return 1
        case .uploading:
            return 2
        case .preparing:
            return 3
        case .failed:
            return 4
        case .pending:
            return 5
        }
    }

    private static func comparisonDate(for item: SyncQueueItem) -> Date {
        item.completedAt ?? item.lastAttemptAt ?? item.createdAt
    }
}

extension SyncQueueController {
    struct SyncRunSummary: Equatable {
        let syncedCount: Int
        let skippedCount: Int
        let failedCount: Int
        let finishedAt: Date
    }

    private enum SyncOutcome {
        case synced
        case skipped
        case failed
    }
}
