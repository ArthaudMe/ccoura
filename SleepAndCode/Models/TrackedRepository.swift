import Foundation
import SwiftData

@Model
final class TrackedRepository {
    @Attribute(.unique) var fullName: String
    var isActive: Bool
    var lastSyncedAt: Date?
    var ownerAvatarURL: String?
    var repoDescription: String?
    var isPrivate: Bool

    init(
        fullName: String,
        isActive: Bool = true,
        lastSyncedAt: Date? = nil,
        ownerAvatarURL: String? = nil,
        repoDescription: String? = nil,
        isPrivate: Bool = false
    ) {
        self.fullName = fullName
        self.isActive = isActive
        self.lastSyncedAt = lastSyncedAt
        self.ownerAvatarURL = ownerAvatarURL
        self.repoDescription = repoDescription
        self.isPrivate = isPrivate
    }

    var owner: String {
        fullName.components(separatedBy: "/").first ?? ""
    }

    var name: String {
        fullName.components(separatedBy: "/").last ?? fullName
    }
}
