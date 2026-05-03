import Foundation

enum SyncQueueItemStatus: String, Codable {
    case pending
    case preparing
    case uploading
    case committing
    case completed
    case failed
}

extension SyncQueueItemStatus {
    var progressValue: Double {
        switch self {
        case .pending:
            0
        case .preparing:
            0.2
        case .uploading:
            0.65
        case .committing:
            0.9
        case .completed:
            1
        case .failed:
            0
        }
    }
}

struct SyncQueueItem: Identifiable, Codable, Equatable {
    let id: String
    let localIdentifier: String
    let filename: String
    let createdAt: Date
    var status: SyncQueueItemStatus
    var lastMessage: String?
    var remoteAssetId: String?
    var attemptCount: Int?
    var lastAttemptAt: Date?
    var completedAt: Date?
}
