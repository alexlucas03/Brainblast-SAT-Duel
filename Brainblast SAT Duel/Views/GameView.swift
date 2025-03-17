import SwiftUI

struct GameView: View {
    @EnvironmentObject private var dbManager: PostgresDBManager
    @State private var elapsedTime: Double = 0 // Count upward
    @State private var question: String = "What is the capital of France?"
    @State private var options: [String] = ["London", "Berlin", "Paris", "Rome"]
    @State private var selectedAnswer: String?
    @State private var timer: Timer?
    @State private var navigateToDetailView = false // Navigation flag

    var duel: Duel
    var userId: String

    var body: some View {
        VStack {
            // Timer (counting upward)
            Text("Time: \(Int(elapsedTime)) seconds")
                .padding()

            // Question
            Text(question)
                .font(.title)
                .padding()

            // Options
            VStack {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        selectedAnswer = option
                        checkAnswer(option)
                    }) {
                        Text(option)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedAnswer == option ? Color.blue.opacity(0.7) : Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)

            Spacer()
        }
        .padding()
        .onAppear {
            startTimer()
            loadDuelData()
        }
        .onDisappear {
            stopTimer()
        }
        .background(
            NavigationLink(destination: DuelDetailView(duel: duel), isActive: $navigateToDetailView) {
                EmptyView()
            }
            .hidden()
        )
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
        recordAnswer(answer)
    }

    private func recordAnswer(_ answer: String) {
        let isCorrect = answer == "Paris" // Replace with your actual answer checking logic

        // Record time and correctness in the database
        dbManager.recordAnswer(userId: userId, duelId: duel.id, timeTaken: Int(elapsedTime), isCorrect: isCorrect) { success, error in
            if success {
                print("Answer recorded successfully")
                updateTurn()
                navigateToDetailView = true // Trigger navigation to DuelDetailView
            } else {
                print("Error recording answer: \(error?.localizedDescription ?? "Unknown error")")
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

    private func loadDuelData() {
        // Load question and options from duel or database
        // Example:
        // question = duel.question // Assuming duel has a question property
        // options = duel.options   // Assuming duel has an options property
        // Or fetch from a database based on duel.id
    }
}

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView(duel: Duel(id: "testId", roomCode: "TEST", creatorId: "test", createdAt: Date(), completedAt: nil, active: true), userId: "testUserId")
            .environmentObject(PostgresDBManager())
    }
}
