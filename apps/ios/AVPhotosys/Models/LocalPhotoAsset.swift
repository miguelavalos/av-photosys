import Foundation

struct LocalPhotoAsset: Identifiable, Codable, Equatable {
    let localIdentifier: String
    let filename: String
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int

    var id: String { localIdentifier }
}
