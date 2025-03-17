import SwiftUI

struct GameView: View {
    @EnvironmentObject private var dbManager: PostgresDBManager
    @State private var elapsedTime: Double = 0 // Count upward
    @State private var question: String = "Loading question..."
    @State private var options: [String] = ["", "", "", ""]
    @State private var correctOption: String = ""
    @State private var selectedAnswer: String?
    @State private var timer: Timer?
    @State private var navigateToDetailView = false // Navigation flag
    @State private var isLoading = true
    @State private var errorMessage: String?

    var duel: Duel
    var userId: String

    var body: some View {
        ZStack {
            VStack {
                if isLoading {
                    ProgressView("Loading question...")
                } else if let error = errorMessage {
                    VStack {
                        Text("Error loading question")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                        Button("Return to Duel") {
                            navigateToDetailView = true
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                } else {
                    // Timer (counting upward)
                    Text("Time: \(Int(elapsedTime)) seconds")
                        .padding()

                    // Question
                    Text(question)
                        .font(.title)
                        .padding()
                        .multilineTextAlignment(.center)

                    // Options
                    VStack(spacing: 12) {
                        ForEach(options.indices, id: \.self) { index in
                            Button(action: {
                                selectedAnswer = options[index]
                                checkAnswer(options[index])
                            }) {
                                Text(options[index])
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        selectedAnswer == options[index]
                                            ? Color.blue.opacity(0.7)
                                            : Color.gray.opacity(0.2)
                                    )
                                    .foregroundColor(
                                        selectedAnswer == options[index]
                                            ? Color.white
                                            : Color.primary
                                    )
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            .disabled(selectedAnswer != nil) // Disable after an answer is selected
                        }
                    }
                    .padding(.vertical)

                    Spacer()
                }
            }
            .padding()
            .onAppear {
                loadQuestion()
            }
            .onDisappear {
                stopTimer()
            }
            
            // Hidden navigation link
            NavigationLink(destination: DuelDetailView(duel: duel), isActive: $navigateToDetailView) {
                EmptyView()
            }
            .hidden()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func checkAnswer(_ answer: String) {
        stopTimer() // Stop the timer when an answer is selected
        
        let isCorrect = answer == correctOption
        
        // Record time and correctness in the database
        dbManager.recordAnswer(userId: userId, duelId: duel.id, timeTaken: Int(elapsedTime), isCorrect: isCorrect) { success, error in
            if success {
                print("Answer recorded successfully")
                updateTurn()
                
                // Add a small delay before navigating back to give user time to see their choice
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    navigateToDetailView = true // Trigger navigation to DuelDetailView
                }
            } else {
                print("Error recording answer: \(error?.localizedDescription ?? "Unknown error")")
                errorMessage = "Failed to record your answer. Please try again."
            }
        }
    }

    private func updateTurn() {
        // Switch the turn to the opponent
        dbManager.switchTurn(duelId: duel.id, currentUserId: userId) { success, error in
            if success {
                print("Turn switched successfully")
            } else {
                print("Error switching turn: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    private func loadQuestion() {
        dbManager.getCurrentQuestion(duelId: duel.id) { questionData, error in
            if let question = questionData {
                self.question = question.questionText
                self.options = [
                    question.optionA,
                    question.optionB,
                    question.optionC,
                    question.optionD
                ]
                self.correctOption = question.correctOption
                self.isLoading = false
                self.startTimer() // Start timer after question is loaded
            } else {
                self.isLoading = false
                self.errorMessage = error?.localizedDescription ?? "Failed to load question"
                print("Error loading question: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView(duel: Duel(id: "testId", roomCode: "TEST", creatorId: "test", createdAt: Date(), completedAt: nil, active: true), userId: "testUserId")
            .environmentObject(PostgresDBManager())
    }
}
