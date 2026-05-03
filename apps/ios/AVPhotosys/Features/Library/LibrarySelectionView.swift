import Photos
import SwiftUI

struct LibrarySelectionView: View {
    private enum SortMode: String, CaseIterable, Identifiable {
        case newest
        case oldest
        case filename
        case largest

        var id: String { rawValue }
    }

    @EnvironmentObject private var permissionController: PhotoPermissionController
    @EnvironmentObject private var localLibraryController: LocalLibraryController
    @EnvironmentObject private var syncQueueController: SyncQueueController

    @State private var searchQuery = ""
    @State private var sortMode: SortMode = .newest

    private let thumbnailSize: CGFloat = 68

    var body: some View {
        NavigationStack {
            List {
                Section(L10n.string("library.permissions.section")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(permissionController.title)
                            .font(.headline)
                        Text(permissionController.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if permissionController.canRequestAccess {
                            Button(L10n.string("library.permissions.request")) {
                                permissionController.requestAccess()
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button(L10n.string("library.permissions.refresh")) {
                                permissionController.refresh()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if permissionController.status == .authorized || permissionController.status == .limited {
                    Section(L10n.string("library.selected.section")) {
                        if localLibraryController.selectedAssets.isEmpty {
                            Text(L10n.string("library.selected.empty"))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(localLibraryController.selectedAssets) { asset in
                                assetRow(asset)
                            }

                            Button(L10n.string("library.selected.enqueue")) {
                                syncQueueController.enqueue(localLibraryController.selectedAssets)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    Section(L10n.string("library.recent.section")) {
                        if localLibraryController.isLoading {
                            ProgressView()
                        } else if localLibraryController.recentAssets.isEmpty {
                            Text(L10n.string("library.recent.empty"))
                                .foregroundStyle(.secondary)
                        } else {
                            recentControls

                            ForEach(displayedRecentAssets) { asset in
                                Button {
                                    localLibraryController.toggleSelection(for: asset)
                                } label: {
                                    HStack(spacing: 12) {
                                        LocalAssetThumbnailView(asset: asset, size: thumbnailSize)

                                        Image(systemName: localLibraryController.selectedAssetIDs.contains(asset.localIdentifier) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(localLibraryController.selectedAssetIDs.contains(asset.localIdentifier) ? .green : .secondary)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(asset.filename)
                                                .foregroundStyle(.primary)
                                            Text(assetSubtitle(for: asset))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Section(L10n.string("library.boundary.section")) {
                    Text(L10n.string("library.boundary.selective"))
                    Text(L10n.string("library.boundary.localMode"))
                    Text(L10n.string("library.boundary.hosted"))
                }
            }
            .scrollContentBackground(.hidden)
            .background(AVPhotosysTheme.shellBackground.ignoresSafeArea())
            .navigationTitle("AV Photosys")
            .searchable(text: $searchQuery, prompt: L10n.string("library.search"))
            .task {
                localLibraryController.refreshIfAuthorized(status: permissionController.status)
            }
            .onChange(of: permissionController.status) { _, newStatus in
                localLibraryController.refreshIfAuthorized(status: newStatus)
            }
        }
    }

    private func assetRow(_ asset: LocalPhotoAsset) -> some View {
        HStack(spacing: 12) {
            LocalAssetThumbnailView(asset: asset, size: thumbnailSize)

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.filename)
                    .font(.headline)
                Text(assetSubtitle(for: asset))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func assetSubtitle(for asset: LocalPhotoAsset) -> String {
        let dateText: String

        if let creationDate = asset.creationDate {
            dateText = creationDate.formatted(date: .abbreviated, time: .omitted)
        } else {
            dateText = L10n.string("library.asset.unknownDate")
        }

        return "\(dateText) • \(asset.pixelWidth)x\(asset.pixelHeight)"
    }

    private var displayedRecentAssets: [LocalPhotoAsset] {
        let filtered = localLibraryController.recentAssets.filter { asset in
            let normalizedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalizedQuery.isEmpty == false else { return true }
            return asset.filename.localizedCaseInsensitiveContains(normalizedQuery)
        }

        return filtered.sorted { lhs, rhs in
            switch sortMode {
            case .newest:
                (lhs.creationDate ?? .distantPast) > (rhs.creationDate ?? .distantPast)
            case .oldest:
                (lhs.creationDate ?? .distantPast) < (rhs.creationDate ?? .distantPast)
            case .filename:
                lhs.filename.localizedCaseInsensitiveCompare(rhs.filename) == .orderedAscending
            case .largest:
                (lhs.pixelWidth * lhs.pixelHeight) > (rhs.pixelWidth * rhs.pixelHeight)
            }
        }
    }

    private var recentControls: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(SortMode.allCases) { mode in
                    Button {
                        sortMode = mode
                    } label: {
                        Label(
                            L10n.string(sortLabelKey(for: mode)),
                            systemImage: sortMode == mode ? "checkmark" : "arrow.up.arrow.down"
                        )
                    }
                }
            } label: {
                Label(L10n.string("library.sort"), systemImage: "arrow.up.arrow.down")
            }
            .buttonStyle(.bordered)

            Spacer()

            Text(L10n.string("library.filteredCount", displayedRecentAssets.count))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func sortLabelKey(for mode: SortMode) -> String {
        switch mode {
        case .newest:
            "library.sort.newest"
        case .oldest:
            "library.sort.oldest"
        case .filename:
            "library.sort.filename"
        case .largest:
            "library.sort.largest"
        }
    }
}

private struct LocalAssetThumbnailView: View {
    @EnvironmentObject private var localLibraryController: LocalLibraryController

    let asset: LocalPhotoAsset
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AVPhotosysTheme.cardSurface)

            if let image = localLibraryController.thumbnail(for: asset) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.title3)
                    Text("\(asset.pixelWidth)x\(asset.pixelHeight)")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AVPhotosysTheme.borderSubtle.opacity(0.45), lineWidth: 1)
        )
        .task {
            await localLibraryController.loadThumbnailIfNeeded(for: asset)
        }
    }
}
