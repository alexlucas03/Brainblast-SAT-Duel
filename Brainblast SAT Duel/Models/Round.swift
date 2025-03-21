import Foundation
import SwiftData

@Model
final class Round {
    var questionNumber: Int
    
    // Relationship to answers
    @Relationship(deleteRule: .cascade)
    var answers: [Answer] = []
    
    // Computed properties to find specific answers
    @Transient
    var userAnswer: Answer? {
        return answers.first(where: { $0.isUserAnswer })
    }
    
    @Transient
    var opponentAnswer: Answer? {
        return answers.first(where: { !$0.isUserAnswer })
    }
    
    // Convenience computed properties
    @Transient
    var userCorrect: Bool {
        userAnswer?.isCorrect ?? false
    }
    
    @Transient
    var opponentCorrect: Bool {
        opponentAnswer?.isCorrect ?? false
    }
    
    @Transient
    var userTime: Int? {
        userAnswer?.timeTaken
    }
    
    @Transient
    var opponentTime: Int? {
        opponentAnswer?.timeTaken
    }
    
    // Initializer
    init(questionNumber: Int) {
        self.questionNumber = questionNumber
    }
    
    // Helper method to add an answer
    func addAnswer(_ answer: Answer) {
        answer.round = self
        answers.append(answer)
    }
}
