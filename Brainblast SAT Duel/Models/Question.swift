import Foundation
import SwiftData

@Model
class Question {
    @Attribute(.unique) var questionText: String
    var optionA: String
    var optionB: String
    var optionC: String
    var optionD: String
    var correctOption: String

    init(questionText: String, optionA: String, optionB: String, optionC: String, optionD: String, correctOption: String) {
        self.questionText = questionText
        self.optionA = optionA
        self.optionB = optionB
        self.optionC = optionC
        self.optionD = optionD
        self.correctOption = correctOption
    }
}
