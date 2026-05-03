import Foundation
import Photos
import UIKit

@MainActor
final class LocalLibraryController: ObservableObject {
    @Published private(set) var recentAssets: [LocalPhotoAsset] = []
    @Published private(set) var selectedAssetIDs: Set<String>
    @Published private(set) var isLoading = false
    @Published private var thumbnails: [String: UIImage] = [:]

    private let service: PhotoLibraryService
    private let userDefaults: UserDefaults
    private let selectionKey = "avphotosys.selectedAssetIDs"
    private let thumbnailSize = CGSize(width: 240, height: 240)

    init(
        service: PhotoLibraryService = PhotoLibraryService(),
        userDefaults: UserDefaults = .standard
    ) {
        self.service = service
        self.userDefaults = userDefaults
        self.selectedAssetIDs = Set(userDefaults.stringArray(forKey: selectionKey) ?? [])
    }

    var selectedAssets: [LocalPhotoAsset] {
        recentAssets.filter { selectedAssetIDs.contains($0.localIdentifier) }
    }

    func refreshIfAuthorized(status: PHAuthorizationStatus) {
        guard status == .authorized || status == .limited else {
            recentAssets = []
            return
        }

        isLoading = true
        recentAssets = service.fetchRecentAssets()
        isLoading = false
    }

    func toggleSelection(for asset: LocalPhotoAsset) {
        if selectedAssetIDs.contains(asset.localIdentifier) {
            selectedAssetIDs.remove(asset.localIdentifier)
        } else {
            selectedAssetIDs.insert(asset.localIdentifier)
        }

        persistSelection()
    }

    func thumbnail(for asset: LocalPhotoAsset) -> UIImage? {
        thumbnails[asset.localIdentifier]
    }

    func loadThumbnailIfNeeded(for asset: LocalPhotoAsset) async {
        guard thumbnails[asset.localIdentifier] == nil else {
            return
        }

        do {
            let image = try await service.requestThumbnail(
                for: asset.localIdentifier,
                targetSize: thumbnailSize
            )
            thumbnails[asset.localIdentifier] = image
        } catch {
            return
        }
    }

    private func persistSelection() {
        userDefaults.set(Array(selectedAssetIDs).sorted(), forKey: selectionKey)
    }
}
