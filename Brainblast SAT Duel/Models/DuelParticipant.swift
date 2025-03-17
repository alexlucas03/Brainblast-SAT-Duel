import Foundation
import SwiftData

@Model
class DuelParticipant {
    var id: String = UUID().uuidString
    var userId: String
    
    @Relationship(inverse: \Duel.participants)
    var duel: Duel?
    
    init(userId: String) {
        self.userId = userId
    }
}
