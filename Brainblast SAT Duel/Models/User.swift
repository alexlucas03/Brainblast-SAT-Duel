import Foundation
import SwiftData

@Model
class User {
    @Attribute(.unique) var username: String  // Make username unique
    var createdAt: Date
    
    // CloudKit requires a stable identity
    @Attribute(.externalStorage) var profileImage: Data?

    init(username: String) {
        self.username = username
        self.createdAt = Date()
    }
}
