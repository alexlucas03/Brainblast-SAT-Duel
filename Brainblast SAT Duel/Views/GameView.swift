import SwiftUI

struct GameView: View {
    @EnvironmentObject private var dbManager: PostgresDBManager
    @EnvironmentObject private var appState: AppState
    @State private var elapsedTime: Double = 0
    @State private var question: String = "Loading question..."
    @State private var options: [String] = ["", "", "", ""]
    @State private var correctOption: String = ""
    @State private var selectedAnswer: String?
    @State private var timer: Timer?
    @State private var navigateToDetailView = false
    @State private var errorMessage: String?

    var duel: Duel
    var userId: String

    var body: some View {
        ZStack {
            // Main game content
            VStack {
                if let error = errorMessage {
                    // Error display
                    VStack {
                        Text("Error loading question")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                        Button("Return to Duel") {
                            appState.startNavigating()
                            // Slight delay before actual navigation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                navigateToDetailView = true
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(appState.isShowingLoadingView)
                    }
                    .padding()
                } else {
                    // Game UI
                    Text("Time: \(Int(elapsedTime)) seconds")
                        .padding()

                    Text(question)
                        .font(.title)
                        .padding()
                        .multilineTextAlignment(.center)

                    VStack(spacing: 12) {
                        ForEach(options.indices, id: \.self) { index in
                            Button(action: {
                                selectedAnswer = options[index]
                                appState.startLoading()
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
                            .disabled(selectedAnswer != nil || appState.isShowingLoadingView)
                        }
                    }
                    .padding(.vertical)

                    Spacer()
                }
            }
            .padding()

            // Hidden navigation link
            NavigationLink(
                destination: DuelDetailView(duel: duel)
                    .onAppear {
                        // Reset navigation state when destination appears
                        appState.stopNavigating()
                    },
                isActive: $navigateToDetailView
            ) {
                EmptyView()
            }
            .hidden()
        }
        .onAppear {
            // Load question when view appears
            appState.startLoading()
            loadQuestion()
        }
        .onDisappear {
            stopTimer()
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
        stopTimer()

        let isCorrect = answer == correctOption

        dbManager.recordAnswer(userId: userId, duelId: duel.id, timeTaken: Int(elapsedTime), isCorrect: isCorrect) { success, error in
            if success {
                print("Answer recorded successfully")
                updateTurn()

                // Switch from loading to navigating state
                DispatchQueue.main.async {
                    appState.stopLoading()
                    appState.startNavigating()
                }

                // Navigation delay after answering
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    navigateToDetailView = true
                }
            } else {
                DispatchQueue.main.async {
                    appState.stopLoading()
                    print("Error recording answer: \(error?.localizedDescription ?? "Unknown error")")
                    errorMessage = "Failed to record your answer. Please try again."
                }
            }
        }
    }

    private func updateTurn() {
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
            DispatchQueue.main.async {
                appState.stopLoading()
                
                if let question = questionData {
                    self.question = question.questionText
                    self.options = [
                        question.optionA,
                        question.optionB,
                        question.optionC,
                        question.optionD
                    ]
                    self.correctOption = question.correctOption
                    self.startTimer()
                } else {
                    self.errorMessage = error?.localizedDescription ?? "Failed to load question"
                    print("Error loading question: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
}

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView(duel: Duel(id: "testId", roomCode: "TEST", creatorId: "test", createdAt: Date(), completedAt: nil, active: true), userId: "testUserId")
            .environmentObject(PostgresDBManager())
            .environmentObject(AppState())
    }
}
