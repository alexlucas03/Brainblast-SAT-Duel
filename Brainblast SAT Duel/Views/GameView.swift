import SwiftUI

// Extension to interpolate color from green to red
extension Color {
    static func interpolateFromGreenToRed(progress: Double) -> Color {
        let clampedProgress = min(max(progress, 0), 1) // Ensure progress is between 0 and 1
        
        // Start with green (progress = 0)
        // Pass through yellow (progress = 0.5)
        // End with red (progress = 1)
        if clampedProgress < 0.5 {
            // Green to Yellow (normalize progress to 0-1 range within this segment)
            let normalizedProgress = clampedProgress * 2
            return Color(
                red: normalizedProgress,
                green: 1.0,
                blue: 0.0
            )
        } else {
            // Yellow to Red (normalize progress to 0-1 range within this segment)
            let normalizedProgress = (clampedProgress - 0.5) * 2
            return Color(
                red: 1.0,
                green: 1.0 - normalizedProgress,
                blue: 0.0
            )
        }
    }
}

// Shake effect modifier
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        guard animatableData > 0 else { return ProjectionTransform(.identity) }
        
        // Stronger shake as we reach the end
        let intensity = animatableData * 3
        let translation = CGFloat(sin(animatableData * .pi * 10)) * 3 * intensity
        
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
    
struct GameView: View {
    @EnvironmentObject private var dbManager: PostgresDBManager
    @EnvironmentObject private var appState: AppState
    @State private var elapsedTime: Double = 0
    @State private var maxTime: Double = 30 // Maximum time for the question in seconds
    @State private var question: String = "Loading question..."
    @State private var options: [String] = ["", "", "", ""]
    @State private var correctOption: String = ""
    @State private var selectedAnswer: String?
    @State private var timer: Timer?
    @State private var navigateToDetailView = false
    @State private var errorMessage: String?
    @State private var showResult: Bool = false
    @State private var isCorrect: Bool = false
    
    var duel: Duel
    var userId: String
    
    var body: some View {
        ZStack {
            // Main game content
            VStack(spacing: 0) {
                // Timer bar at the top
                ZStack(alignment: .leading) {
                    // Background bar
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 10)
                    
                    // Remaining time indicator with dynamic color and shaking
                    Capsule()
                        .fill(
                            Color.interpolateFromGreenToRed(progress: elapsedTime / maxTime)
                        )
                        .frame(width: max(0, CGFloat(1 - elapsedTime / maxTime)) * UIScreen.main.bounds.width, height: 10)
                        .modifier(ShakeEffect(animatableData: elapsedTime > maxTime * 0.7 ? CGFloat(elapsedTime.truncatingRemainder(dividingBy: 1)) : 0))
                        .animation(.linear, value: elapsedTime)
                }
                .padding(.bottom, 8)
                
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
                    Text(question)
                        .font(.title)
                        .padding()
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 12) {
                        ForEach(options.indices, id: \.self) { index in
                            Button(action: {
                                selectedAnswer = options[index]
                                isCorrect = options[index] == correctOption
                                showResult = true
                                
                                // Record answer after a delay to show the result
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    appState.startLoading()
                                    checkAnswer(options[index])
                                }
                            }) {
                                Text(options[index])
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        getButtonBackground(for: options[index])
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
        // Remove back button
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: EmptyView())
        .onDisappear {
            stopTimer()
        }
    }
    
    @ViewBuilder
    private func getButtonBackground(for option: String) -> some View {
        if !showResult {
            // Normal state, not showing results yet
            if selectedAnswer == option {
                Color.blue.opacity(0.7)
            } else {
                Color.gray.opacity(0.2)
            }
        } else {
            // Showing results
            if option == correctOption {
                // Correct answer - rainbow gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.98, green: 0.7, blue: 0.6),
                        Color(red: 0.95, green: 0.95, blue: 0.6),
                        Color(red: 0.7, green: 0.98, blue: 0.7),
                        Color(red: 0.6, green: 0.8, blue: 0.98)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else if selectedAnswer == option && option != correctOption {
                // Incorrect selected answer - red
                Color.red.opacity(0.7)
            } else {
                // Other options when showing results
                Color.gray.opacity(0.2)
            }
        }
    }
    
    private func startTimer() {
        // Reset elapsed time
        elapsedTime = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if elapsedTime < maxTime {
                elapsedTime += 0.1
            } else {
                // Time's up - auto-submit if no answer selected
                if selectedAnswer == nil {
                    // Select the first option as a default if time runs out
                    selectedAnswer = options.first
                    isCorrect = selectedAnswer == correctOption
                    showResult = true
                    
                    // Record answer after a delay to show the result
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        appState.startLoading()
                        checkAnswer(selectedAnswer ?? "")
                    }
                }
            }
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

// Remove the extension - we'll use SwiftUI's built-in modifiers instead

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GameView(duel: Duel(id: "testId", roomCode: "TEST", creatorId: "test", createdAt: Date(), completedAt: nil, active: true), userId: "testUserId")
                .environmentObject(PostgresDBManager())
                .environmentObject(AppState())
        }
    }
}
