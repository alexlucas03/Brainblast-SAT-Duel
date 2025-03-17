import Foundation
import SwiftData

@Model
class User {
    @Attribute(.unique) var username: String  // Make username unique
    var score: Int
    var createdAt: Date
    
    // CloudKit requires a stable identity
    @Attribute(.externalStorage) var profileImage: Data?

    init(username: String, score: Int) {
        self.username = username
        self.score = score
        self.createdAt = Date()
    }
}
