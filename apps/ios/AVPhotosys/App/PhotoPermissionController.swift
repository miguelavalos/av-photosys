import Photos
import SwiftUI

@MainActor
final class PhotoPermissionController: ObservableObject {
    @Published private(set) var status: PHAuthorizationStatus

    init(status: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)) {
        self.status = status
    }

    var title: String {
        switch status {
        case .authorized, .limited:
            "Photo access is ready"
        case .denied, .restricted:
            "Photo access is unavailable"
        case .notDetermined:
            "Photo access is not requested yet"
        @unknown default:
            "Photo access state is unknown"
        }
    }

    var detail: String {
        switch status {
        case .authorized:
            "The app can read your photo library. Next step is selective sync and upload orchestration."
        case .limited:
            "The app can access only the photos you have selected for limited access."
        case .denied:
            "Access was denied. You can enable it later in Settings."
        case .restricted:
            "This device does not currently allow photo library access."
        case .notDetermined:
            "Request access when you are ready to choose which photos should sync."
        @unknown default:
            "The current authorization state is not recognized."
        }
    }

    var canRequestAccess: Bool {
        status == .notDetermined
    }

    func refresh() {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
            Task { @MainActor in
                self?.status = newStatus
            }
        }
    }
}
