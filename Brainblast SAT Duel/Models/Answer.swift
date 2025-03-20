import Foundation
import SwiftData

@Model
final class Answer {
    var userId: String
    var questionNumber: Int
    var timeTaken: Int
    var isCorrect: Bool
    
    // Reference to which round this answer belongs to
    @Relationship
    var round: Round?
    
    // Reference to whether this is a user answer or opponent answer
    var isUserAnswer: Bool
    
    init(userId: String, questionNumber: Int, timeTaken: Int, isCorrect: Bool, isUserAnswer: Bool = false) {
        self.userId = userId
        self.questionNumber = questionNumber
        self.timeTaken = timeTaken
        self.isCorrect = isCorrect
        self.isUserAnswer = isUserAnswer
    }
}
