import SwiftUI

struct SyncQueueView: View {
    @EnvironmentObject private var hostedSyncController: HostedSyncController
    @EnvironmentObject private var syncQueueController: SyncQueueController
    @State private var assetPendingDeletion: HostedPhotoAsset?

    var body: some View {
        NavigationStack {
            List {
                Section(L10n.string("sync.queue.section")) {
                    if syncQueueController.items.isEmpty {
                        ContentUnavailableView(
                            L10n.string("sync.queue.empty.title"),
                            systemImage: "tray",
                            description: Text(L10n.string("sync.queue.empty.detail"))
                        )
                    } else {
                        if syncQueueController.isSyncing {
                            activeSyncProgressView
                        }

                        queueSummary

                        if let summary = syncQueueController.lastRunSummary {
                            lastRunSummaryView(summary)
                        }

                        ForEach(syncQueueController.items) { item in
                            queueRow(for: item)
                        }

                        Button(syncQueueController.isSyncing ? L10n.string("sync.queue.syncing") : L10n.string("sync.queue.sync")) {
                            Task {
                                await syncQueueController.syncPending()
                                await hostedSyncController.refresh()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(syncQueueController.isSyncing)

                        if syncQueueController.failedCount > 0 {
                            Button(L10n.string("sync.queue.retryFailed")) {
                                syncQueueController.retryFailed()
                            }
                            .buttonStyle(.bordered)
                        }

                        if syncQueueController.completedCount > 0 {
                            Button(L10n.string("sync.queue.clearCompleted")) {
                                syncQueueController.clearCompleted()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Section(L10n.string("sync.hosted.section")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(statusTitle)
                            .font(.headline)
                        Text(statusDetail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button(L10n.string("sync.hosted.refresh")) {
                            Task {
                                await hostedSyncController.refresh()
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        if !hostedSyncController.assets.isEmpty {
                            Text(L10n.string("sync.hosted.gallery.open", hostedSyncController.assets.count))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if !hostedSyncController.assets.isEmpty {
                    Section(L10n.string("sync.hosted.assets")) {
                        ForEach(hostedSyncController.assets.prefix(10)) { asset in
                            HStack(alignment: .top, spacing: 12) {
                                HostedAssetThumbnailView(asset: asset)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(asset.originalFilename)
                                        .font(.headline)
                                    Text("\(asset.pixelWidth)x\(asset.pixelHeight) • \(asset.byteSize) bytes • \(asset.syncStatus)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if hostedSyncController.deletingAssetID == asset.assetId {
                                        Text(L10n.string("sync.hosted.deleting"))
                                            .font(.caption)
                                            .foregroundStyle(AVPhotosysTheme.warning)
                                    }
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    assetPendingDeletion = asset
                                } label: {
                                    Label(L10n.string("sync.hosted.delete"), systemImage: "trash")
                                }
                                .disabled(hostedSyncController.deletingAssetID != nil)
                            }
                        }
                    }
                }

                if !hostedSyncController.recentChanges.isEmpty {
                    Section(L10n.string("sync.hosted.changes")) {
                        ForEach(hostedSyncController.recentChanges.prefix(10)) { asset in
                            HStack(alignment: .top, spacing: 12) {
                                HostedAssetThumbnailView(asset: asset)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(asset.originalFilename)
                                            .font(.headline)

                                        Spacer(minLength: 12)

                                        Text(changeLabel(for: asset))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(changeColor(for: asset))
                                    }

                                    Text(relativeDate(changeDate(for: asset)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section(L10n.string("sync.flow.section")) {
                    Label(L10n.string("sync.flow.step1"), systemImage: "1.circle")
                    Label(L10n.string("sync.flow.step2"), systemImage: "2.circle")
                    Label(L10n.string("sync.flow.step3"), systemImage: "3.circle")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AVPhotosysTheme.shellBackground.ignoresSafeArea())
            .navigationTitle(L10n.string("tab.sync"))
            .task {
                await hostedSyncController.refresh()
            }
            .alert(
                L10n.string("sync.hosted.delete.confirm.title"),
                isPresented: deleteAlertPresentedBinding,
                presenting: assetPendingDeletion
            ) { asset in
                Button(L10n.string("action.cancel"), role: .cancel) {
                    assetPendingDeletion = nil
                }
                Button(L10n.string("sync.hosted.delete"), role: .destructive) {
                    Task {
                        do {
                            try await hostedSyncController.deleteAsset(asset)
                        } catch {
                            await hostedSyncController.refresh()
                        }
                        assetPendingDeletion = nil
                    }
                }
            } message: { asset in
                Text(L10n.string("sync.hosted.delete.confirm.message", asset.originalFilename))
            }
        }
    }

    private var statusTitle: String {
        switch hostedSyncController.hostedState {
        case .notConfigured:
            L10n.string("sync.hosted.status.notConfigured")
        case .checking:
            L10n.string("sync.hosted.status.checking")
        case .authRequired:
            L10n.string("sync.hosted.status.authRequired")
        case .forbidden:
            L10n.string("sync.hosted.status.forbidden")
        case .ready(let assetCount):
            assetCount == 0
                ? L10n.string("sync.hosted.status.readyEmpty")
                : L10n.string("sync.hosted.status.readyCount", assetCount)
        case .failed:
            L10n.string("sync.hosted.status.failed")
        }
    }

    private var statusDetail: String {
        switch hostedSyncController.hostedState {
        case .notConfigured:
            L10n.string("sync.hosted.detail.notConfigured")
        case .checking:
            L10n.string("sync.hosted.detail.checking")
        case .authRequired:
            L10n.string("sync.hosted.detail.authRequired")
        case .forbidden(let message):
            message
        case .ready:
            L10n.string("sync.hosted.detail.ready")
        case .failed(let message):
            message
        }
    }

    private var queueSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("sync.queue.summary.title"))
                .font(.headline)

            HStack(spacing: 12) {
                summaryPill(
                    title: L10n.string("sync.queue.summary.pending"),
                    value: syncQueueController.pendingCount,
                    tint: .secondary
                )
                summaryPill(
                    title: L10n.string("sync.queue.summary.active"),
                    value: syncQueueController.activeCount,
                    tint: AVPhotosysTheme.highlight
                )
                summaryPill(
                    title: L10n.string("sync.queue.summary.failed"),
                    value: syncQueueController.failedCount,
                    tint: AVPhotosysTheme.warning
                )
                summaryPill(
                    title: L10n.string("sync.queue.summary.completed"),
                    value: syncQueueController.completedCount,
                    tint: AVPhotosysTheme.highlight
                )
            }
            .font(.caption)
        }
        .padding(.vertical, 6)
    }

    private var activeSyncProgressView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("sync.queue.progress.title"))
                .font(.headline)

            ProgressView(value: syncQueueController.overallProgress)
                .tint(AVPhotosysTheme.highlight)

            Text(
                L10n.string(
                    "sync.queue.progress.summary",
                    syncQueueController.completedCount,
                    syncQueueController.totalTrackedCount
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if let currentSyncFilename = syncQueueController.currentSyncFilename {
                Text(L10n.string("sync.queue.progress.current", currentSyncFilename))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func lastRunSummaryView(_ summary: SyncQueueController.SyncRunSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.string("sync.queue.lastRun.title"))
                .font(.headline)

            Text(
                L10n.string(
                    "sync.queue.lastRun.summary",
                    summary.syncedCount,
                    summary.skippedCount,
                    summary.failedCount
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(relativeDate(summary.finishedAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func queueRow(for item: SyncQueueItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.filename)
                    .font(.headline)

                Spacer(minLength: 12)

                Text(statusLabel(for: item.status))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor(for: item.status))
            }

            ProgressView(value: item.status.progressValue)
                .tint(statusColor(for: item.status))

            HStack(spacing: 10) {
                if let attemptCount = item.attemptCount, attemptCount > 0 {
                    Text(L10n.string("sync.queue.attempts", attemptCount))
                }

                if let completedAt = item.completedAt {
                    Text(relativeDate(completedAt))
                } else if let lastAttemptAt = item.lastAttemptAt {
                    Text(relativeDate(lastAttemptAt))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let lastMessage = item.lastMessage {
                Text(lastMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func summaryPill(title: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.headline)
            Text(title)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }

    private func statusLabel(for status: SyncQueueItemStatus) -> String {
        switch status {
        case .pending:
            L10n.string("sync.queue.status.pending")
        case .preparing:
            L10n.string("sync.queue.status.preparing")
        case .uploading:
            L10n.string("sync.queue.status.uploading")
        case .committing:
            L10n.string("sync.queue.status.committing")
        case .completed:
            L10n.string("sync.queue.status.completed")
        case .failed:
            L10n.string("sync.queue.status.failed")
        }
    }

    private func statusColor(for status: SyncQueueItemStatus) -> Color {
        switch status {
        case .pending:
            .secondary
        case .preparing, .uploading, .committing:
            AVPhotosysTheme.highlight
        case .completed:
            AVPhotosysTheme.highlight
        case .failed:
            AVPhotosysTheme.warning
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let now = Date()
        if date >= now || abs(date.timeIntervalSince(now)) < 1 {
            return L10n.string("time.now")
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let clampedDate = date > now ? now : date
        return formatter.localizedString(for: clampedDate, relativeTo: now)
    }

    private func changeLabel(for asset: HostedPhotoAsset) -> String {
        asset.syncStatus == "deleted"
            ? L10n.string("sync.hosted.change.deleted")
            : L10n.string("sync.hosted.change.ready")
    }

    private func changeColor(for asset: HostedPhotoAsset) -> Color {
        asset.syncStatus == "deleted" ? AVPhotosysTheme.warning : AVPhotosysTheme.highlight
    }

    private func changeDate(for asset: HostedPhotoAsset) -> Date {
        let formatter = ISO8601DateFormatter()
        if asset.syncStatus == "deleted",
           let deletedAt = asset.deletedAt,
           let date = formatter.date(from: deletedAt) {
            return date
        }

        return formatter.date(from: asset.updatedAt) ?? .now
    }

    private var deleteAlertPresentedBinding: Binding<Bool> {
        Binding(
            get: { assetPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    assetPendingDeletion = nil
                }
            }
        )
    }
}
