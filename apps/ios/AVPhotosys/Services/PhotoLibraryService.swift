import CryptoKit
import Foundation
import Photos
import UIKit

struct LocalPhotoUploadPayload {
    let asset: LocalPhotoAsset
    let data: Data
    let captureTakenAt: String?
    let sha256: String
}

enum PhotoLibraryServiceError: LocalizedError {
    case assetNotFound
    case imageDataUnavailable
    case assetResourceUnavailable

    var errorDescription: String? {
        switch self {
        case .assetNotFound:
            "The local photo asset could not be found."
        case .imageDataUnavailable:
            "The selected asset did not return image data."
        case .assetResourceUnavailable:
            "The selected asset did not expose an original photo resource."
        }
    }
}

struct PhotoLibraryService {
    func fetchRecentAssets(limit: Int = 24) -> [LocalPhotoAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit

        let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [LocalPhotoAsset] = []

        fetchResult.enumerateObjects { asset, _, _ in
            let filename = PHAssetResource.assetResources(for: asset).first?.originalFilename ?? "Image"
            assets.append(
                LocalPhotoAsset(
                    localIdentifier: asset.localIdentifier,
                    filename: filename,
                    creationDate: asset.creationDate,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight
                )
            )
        }

        return assets
    }

    func fetchUploadPayload(for localIdentifier: String) async throws -> LocalPhotoUploadPayload {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            throw PhotoLibraryServiceError.assetNotFound
        }

        let filename = PHAssetResource.assetResources(for: asset).first?.originalFilename ?? "Image"
        let data = try await requestOriginalImageData(for: asset)

        return LocalPhotoUploadPayload(
            asset: LocalPhotoAsset(
                localIdentifier: asset.localIdentifier,
                filename: filename,
                creationDate: asset.creationDate,
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight
            ),
            data: data,
            captureTakenAt: asset.creationDate.map(Self.isoString),
            sha256: Self.sha256Hex(for: data)
        )
    }

    func requestThumbnail(for localIdentifier: String, targetSize: CGSize) async throws -> UIImage {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            throw PhotoLibraryServiceError.assetNotFound
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                if let image {
                    continuation.resume(returning: image)
                }
            }
        }
    }

    private func requestOriginalImageData(for asset: PHAsset) async throws -> Data {
        guard let resource = PHAssetResource.assetResources(for: asset)
            .first(where: { $0.type == .photo || $0.type == .fullSizePhoto })
        else {
            throw PhotoLibraryServiceError.assetResourceUnavailable
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true

            var buffer = Data()

            PHAssetResourceManager.default().requestData(for: resource, options: options) { chunk in
                buffer.append(chunk)
            } completionHandler: { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard !buffer.isEmpty else {
                    continuation.resume(throwing: PhotoLibraryServiceError.imageDataUnavailable)
                    return
                }

                continuation.resume(returning: buffer)
            }
        }
    }

    private static func sha256Hex(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
