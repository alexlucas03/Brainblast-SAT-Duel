import Foundation
import SwiftData

@Model
class DuelParticipant {
    var id: String = UUID().uuidString
    var userId: String
    var isTheirTurn: Bool
    var score: Int

    @Relationship(inverse: \Duel.participants)
    var duel: Duel?

    init(userId: String, isTheirTurn: Bool) {
        self.userId = userId
        self.isTheirTurn = isTheirTurn
        self.score = 0
    }
}
