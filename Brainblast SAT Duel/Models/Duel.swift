import Foundation
import SwiftData

@Model
class Duel {
    @Attribute(.unique) var id: String
    @Attribute(.unique) var roomCode: String
    var creatorId: String
    var createdAt: Date
    var completedAt: Date?
    var active: Bool = true
    var currentQuestion: String?
    
    // Relationship to participants
    @Relationship var participants: [DuelParticipant]?
    
    init(id: String = UUID().uuidString, roomCode: String, creatorId: String, createdAt: Date = Date(), completedAt: Date? = nil, active: Bool = true, currentQuestion: String? = nil) {
        self.id = id
        self.roomCode = roomCode
        self.creatorId = creatorId
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.active = active
        self.currentQuestion = currentQuestion
    }
}
