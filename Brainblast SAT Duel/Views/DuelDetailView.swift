import SwiftUI

struct RoundedLeftRectangle: Shape {
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start from top-left corner
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        
        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        
        // Right edge (not rounded)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        
        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        
        // Bottom-left rounded corner
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        
        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        
        // Top-left rounded corner
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        
        path.closeSubpath()
        return path
    }
}

struct RoundedRightRectangle: Shape {
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start from top-left corner (not rounded)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        
        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        
        // Top-right rounded corner
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        
        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        
        // Bottom-right rounded corner
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        
        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        
        // Left edge (not rounded)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        path.closeSubpath()
        return path
    }
}

struct DuelDetailView: View {
    @EnvironmentObject private var dbManager: PostgresDBManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    let duel: Duel
    
    @State private var participants: [User] = []
    @State private var currentUser: User?
    @State private var opponent: User?
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = "Error"
    @State private var alertMessage: String = ""
    @State private var navigateToHome: Bool = false
    @State private var answers: [Answer] = []
    @State private var rounds: [Round] = []
    @State private var isUsersTurn: Bool = false
    @State private var gameOver: Bool = false
    @State private var navigateToGameView: Bool = false
    
    // Timer for polling turn status
    @State private var timer: Timer? = nil
    
    // For winner determination
    private enum RoundWinner {
        case user
        case opponent
        case tie
        case incomplete
    }
    
    var body: some View {
        ZStack {
            duelActiveView
            
            // Navigation link to GameView when it's user's turn
            NavigationLink(
                destination: Group {
                    if let userId = dbManager.currentUserId {
                        GameView(duel: duel, userId: userId)
                    } else {
                        // Fallback if somehow userId is missing
                        Text("Unable to start game: User ID not found")
                            .foregroundColor(.black)
                            .padding()
                            .onAppear {
                                // Return back to duel detail after a delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    navigateToGameView = false
                                }
                            }
                    }
                },
                isActive: $navigateToGameView
            ) {
                EmptyView()
            }
            
            // Navigation link to DuelResultView when game is over
            NavigationLink(
                destination: Group {
                    if let currentUser = currentUser, let opponent = opponent {
                        DuelResultView(
                            navigateToHome: $navigateToHome,
                            isWinner: currentUser.score >= 3,
                            opponentName: opponent.username,
                            userScore: currentUser.score,
                            opponentScore: opponent.score,
                            duelId: duel.id
                        )
                    } else {
                        EmptyView()
                    }
                },
                isActive: $gameOver
            ) {
                EmptyView()
            }
        }
        .background(Color.white)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle).foregroundColor(.black),
                message: Text(alertMessage).foregroundColor(.black),
                dismissButton: .default(Text("OK").foregroundColor(.black))
            )
        }
        // Navigation link to Content View with improved loading handling
        NavigationLink(destination: ContentView()
            .navigationBarBackButtonHidden(true)
            .onAppear {
                // Reset navigation state when destination appears
                appState.stopNavigating()
            },
            isActive: $navigateToHome
        ) {
            EmptyView()
        }
        .hidden()
        .onAppear {
            // Load initial data when view appears
            appState.startLoading()
            loadData()
            
            // Start polling for turn updates
            startTurnPolling()
        }
        .onDisappear {
            // Cancel the timer when view disappears
            stopTurnPolling()
        }
    }
    
    // The original duel view when game is still active
    private var duelActiveView: some View {
        ScrollView {
            // Main content
            VStack(spacing: 16) {
                // Top header with home button, duel code, and leave button
                HStack {
                    // Home button
                    Button(action: {
                        appState.startNavigating()
                        // Slight delay before actual navigation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigateToHome = true
                        }
                    }) {
                        Image(systemName: "house.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .padding(10)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .disabled(appState.isShowingLoadingView)
                    
                    Spacer()
                    
                    // Leave duel button
                    Button(action: {
                        appState.startLoading()
                        leaveDuel()
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title3)
                            .foregroundColor(.red)
                            .padding(10)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .disabled(appState.isShowingLoadingView)
                }
                .padding(.horizontal)
                
                // Top section with player names and scores
                if let currentUser = currentUser, let opponent = opponent {
                    HStack {
                        // Current user - using actual username
                        VStack {
                            Text("You")
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(.bottom, 4)
                            
                            Text("\(currentUser.score)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        
                        ZStack {
                            GIFView(gifName: "bullet")
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(-90))
                                .scaleEffect(x: 1, y: -1)
                        }
                        .padding(5)
                        
                        // Opponent
                        VStack {
                            Text(opponent.username.prefix(1).uppercased() + opponent.username.dropFirst())
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(.bottom, 4)
                            
                            Text("\(opponent.score)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.98, green: 0.7, blue: 0.6),
                                        Color(red: 0.95, green: 0.95, blue: 0.6),
                                        Color(red: 0.7, green: 0.98, blue: 0.7),
                                        Color(red: 0.6, green: 0.8, blue: 0.98)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .padding(.horizontal)
                } else if appState.isLoading {
                    ProgressView("Loading participants...")
                        .foregroundColor(.black)
                        .padding()
                } else {
                    Text("Waiting for opponent...")
                        .foregroundColor(.black)
                        .padding()
                }
                
                // Round history section
                VStack(spacing: 12) {
                    if appState.isLoading {
                        ProgressView("Loading round history...")
                            .foregroundColor(.black)
                            .padding()
                    } else if rounds.isEmpty {
                        Text("No rounds played yet")
                            .foregroundColor(.black)
                            .padding()
                    } else {
                        ForEach(rounds, id: \.questionNumber) { round in
                            // Question header moved outside the grey area
                            Text("Question \(round.questionNumber)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.horizontal)
                                .padding(.top, 4)
                            
                            // Entire round card with winner's gradient fill
                            ZStack {
                                // Background with winner's rainbow fill
                                winnerBackgroundForRound(round: round)
                                
                                // Content overlay
                                VStack(spacing: 8) {
                                    // Result indicators
                                    HStack {
                                        // User result
                                        VStack {
                                            if round.userAnswer != nil {
                                                Image(systemName: round.userCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                    .foregroundColor(round.userCorrect ? .green : .red)
                                                    .font(.title2)
                                                
                                                if let time = round.userTime {
                                                    Text("\(time)s")
                                                        .font(.caption)
                                                        .foregroundColor(.black)
                                                }
                                            } else {
                                                Image(systemName: "questionmark.circle.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.title2)
                                                Text("Waiting")
                                                    .font(.caption)
                                                    .foregroundColor(.black)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        
                                        // VS divider
                                        Divider()
                                            .frame(height: 40)
                                        
                                        // Opponent result
                                        VStack {
                                            if round.opponentAnswer != nil {
                                                Image(systemName: round.opponentCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                    .foregroundColor(round.opponentCorrect ? .green : .red)
                                                    .font(.title2)
                                                
                                                if let time = round.opponentTime {
                                                    Text("\(time)s")
                                                        .font(.caption)
                                                        .foregroundColor(.black)
                                                }
                                            } else {
                                                Image(systemName: "questionmark.circle.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.title2)
                                                Text("Waiting")
                                                    .font(.caption)
                                                    .foregroundColor(.black)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                    }
                                    .padding(.horizontal)
                                }
                                .cornerRadius(12)
                                .padding(3) // Small padding to allow the background to show around the edges
                            }
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .refreshable {
            loadData()
        }
        // Disable refreshing during loading
        .disabled(appState.isShowingLoadingView)
    }
    
    // Function to start polling for turn updates
    private func startTurnPolling() {
        // Cancel any existing timer
        stopTurnPolling()
        
        // Create a new timer that polls every 3 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            checkTurnWithNavigation()
        }
    }
    
    // Function to stop polling
    private func stopTurnPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    // Modified check turn function that navigates to GameView if it's user's turn
    private func checkTurnWithNavigation() {
        guard let userId = dbManager.currentUserId else {
            return
        }
        
        // First check if the game is over
        dbManager.getDuelParticipants(duelId: duel.id) { (fetchedParticipants: [User]?, error: Error?) in
            DispatchQueue.main.async {
                if let fetchedParticipants = fetchedParticipants {
                    // Check if anyone has 3 or more points
                    let isGameOver = fetchedParticipants.contains { $0.score >= 3 }
                    
                    if isGameOver {
                        // Game is over, update gameOver state and don't check turn
                        if !gameOver {
                            gameOver = true
                        }
                    } else {
                        // Only check turn if game is not over
                        dbManager.isUsersTurn(userId: userId, duelId: duel.id) { isTurn, error in
                            if let isTurn = isTurn {
                                DispatchQueue.main.async {
                                    // Only navigate if it wasn't their turn before and now it is
                                    if isTurn && !isUsersTurn && !gameOver {
                                        navigateToGameView = true
                                    }
                                    
                                    // Update the state
                                    isUsersTurn = isTurn
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func loadData() {
        // First check if it's user's turn - if so, we'll navigate directly to GameView
        guard let userId = dbManager.currentUserId else {
            loadParticipants()
            loadAnswers()
            appState.stopLoading()
            return
        }
        
        dbManager.isUsersTurn(userId: userId, duelId: duel.id) { isTurn, error in
            DispatchQueue.main.async {
                isUsersTurn = isTurn ?? false
                
                // If it's user's turn immediately, navigate to game view
                if isTurn == true && !gameOver {
                    appState.stopLoading()
                    navigateToGameView = true
                } else {
                    // Otherwise load the rest of the data
                    loadParticipants()
                    loadAnswers()
                }
            }
        }
    }
    
    @ViewBuilder
    private func winnerBackgroundForRound(round: Round) -> some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
            
            if let userId = dbManager.currentUserId,
               round.userAnswer != nil && round.opponentAnswer != nil {
                
                // Both players have answered - determine winner
                if round.userCorrect && !round.opponentCorrect {
                    // User won
                    HStack(spacing: 0) {
                        // Left half with rainbow gradient
                        RoundedLeftRectangle(radius: 12)
                            .fill(
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
                            )
                            .frame(width: geometry.size.width * 0.5)
                        
                        // Right half without gradient
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: geometry.size.width * 0.5)
                    }
                } else if !round.userCorrect && round.opponentCorrect {
                    // Opponent won
                    HStack(spacing: 0) {
                        // Left half without gradient
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: geometry.size.width * 0.5)
                        
                        // Right half with rainbow gradient
                        RoundedRightRectangle(radius: 12)
                            .fill(
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
                            )
                            .frame(width: geometry.size.width * 0.5)
                    }
                } else if round.userCorrect && round.opponentCorrect {
                    // Both correct - compare times
                    if let userTime = round.userTime, let opponentTime = round.opponentTime {
                        if userTime < opponentTime {
                            // User faster
                            HStack(spacing: 0) {
                                RoundedLeftRectangle(radius: 12)
                                    .fill(
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
                                    )
                                    .frame(width: geometry.size.width * 0.5)
                                
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: geometry.size.width * 0.5)
                            }
                        } else if opponentTime < userTime {
                            // Opponent faster
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: geometry.size.width * 0.5)
                                
                                RoundedRightRectangle(radius: 12)
                                    .fill(
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
                                    )
                                    .frame(width: geometry.size.width * 0.5)
                            }
                        }
                        // If times are equal, no highlight (tie)
                    }
                }
                // If both incorrect, no highlight
            }
        }
    }
    
    private func loadParticipants() {
        dbManager.getDuelParticipants(duelId: duel.id) { (fetchedParticipants: [User]?, error: Error?) in
            DispatchQueue.main.async {
                if let error = error {
                    alertTitle = "Error"
                    alertMessage = "Failed to load participants: \(error.localizedDescription)"
                    showAlert = true
                } else if let fetchedParticipants = fetchedParticipants {
                    participants = fetchedParticipants
                    
                    // Determine current user and opponent
                    if let currentUsername = dbManager.currentUsername {
                        currentUser = fetchedParticipants.first(where: { $0.username == currentUsername })
                        opponent = fetchedParticipants.first(where: { $0.username != currentUsername })
                        
                        // Check if game is over (either player has 3 or more points)
                        if let user = currentUser, let opp = opponent {
                            let isGameOver = user.score >= 3 || opp.score >= 3
                            
                            // If the game is newly over, trigger navigation
                            if isGameOver && !gameOver {
                                gameOver = true
                            }
                        }
                    }
                }
                
                // Continue loading other data, don't stop loading yet
            }
        }
    }
    
    private func loadAnswers() {
        guard let userId = dbManager.currentUserId else {
            appState.stopLoading()
            return
        }
        
        dbManager.getDuelRounds(duelId: duel.id) { roundsData, error in
            DispatchQueue.main.async {
                // Stop loading now that we have all data
                appState.stopLoading()
                
                if let error = error {
                    alertTitle = "Error"
                    alertMessage = "Failed to load rounds: \(error.localizedDescription)"
                    showAlert = true
                } else if let roundsData = roundsData {
                    // Process the rounds data
                    var processedRounds: [Round] = []
                    
                    for roundData in roundsData {
                        // Create a new Round with just the question number
                        let round = Round(questionNumber: roundData.roundNumber)
                        
                        // Add answers to the round
                        for answer in roundData.userAnswers {
                            // Set isUserAnswer based on whether this is the current user's answer
                            let isUserAnswer = answer.userId == userId
                            
                            // Create a new Answer with the isUserAnswer flag
                            let newAnswer = Answer(
                                userId: answer.userId,
                                questionNumber: answer.questionNumber,
                                timeTaken: answer.timeTaken,
                                isCorrect: answer.isCorrect,
                                isUserAnswer: isUserAnswer
                            )
                            
                            // Add the answer to the round
                            round.addAnswer(newAnswer)
                        }
                        
                        processedRounds.append(round)
                    }
                    
                    // Sort by question number to ensure correct order
                    self.rounds = processedRounds.sorted(by: { $0.questionNumber < $1.questionNumber })
                }
            }
        }
    }
    
    private func processAnswersIntoRounds(answers: [Answer], userId: String) {
        // Create a mapping of userIds to their sequence of answers
        var userAnswersByQuestion: [String: [Int: Answer]] = [:]
        
        // Group all answers by userId and questionNumber
        for answer in answers {
            if userAnswersByQuestion[answer.userId] == nil {
                userAnswersByQuestion[answer.userId] = [:]
            }
            userAnswersByQuestion[answer.userId]?[answer.questionNumber] = answer
        }
        
        // Find the opponent's userId
        let opponentId = userAnswersByQuestion.keys.first(where: { $0 != userId }) ?? ""
        
        // Get the maximum question number
        let userMaxQuestion = userAnswersByQuestion[userId]?.keys.max() ?? 0
        let opponentMaxQuestion = userAnswersByQuestion[opponentId]?.keys.max() ?? 0
        let maxQuestionNumber = max(userMaxQuestion, opponentMaxQuestion)
        
        // Create rounds in order
        var orderedRounds: [Round] = []
        for questionNum in 1...maxQuestionNumber {
            let round = Round(questionNumber: questionNum)
            
            // Add user answer if it exists
            if let userAnswer = userAnswersByQuestion[userId]?[questionNum] {
                // Create a new Answer with isUserAnswer=true
                let newUserAnswer = Answer(
                    userId: userAnswer.userId,
                    questionNumber: userAnswer.questionNumber,
                    timeTaken: userAnswer.timeTaken,
                    isCorrect: userAnswer.isCorrect,
                    isUserAnswer: true
                )
                round.addAnswer(newUserAnswer)
            }
            
            // Add opponent answer if it exists
            if let opponentAnswer = userAnswersByQuestion[opponentId]?[questionNum] {
                // Create a new Answer with isUserAnswer=false
                let newOpponentAnswer = Answer(
                    userId: opponentAnswer.userId,
                    questionNumber: opponentAnswer.questionNumber,
                    timeTaken: opponentAnswer.timeTaken,
                    isCorrect: opponentAnswer.isCorrect,
                    isUserAnswer: false
                )
                round.addAnswer(newOpponentAnswer)
            }
            
            orderedRounds.append(round)
        }
        
        // Apply the sorted rounds
        self.rounds = orderedRounds
    }

    private func leaveDuel() {
        guard let userId = dbManager.currentUserId else {
            appState.stopLoading()
            return
        }
        
        dbManager.leaveDuel(userId: userId, duelId: duel.id) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Switch to navigation loading before navigating
                    appState.stopLoading()
                    appState.startNavigating()
                    
                    // Slight delay before actual navigation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigateToHome = true
                    }
                } else {
                    appState.stopLoading()
                    alertTitle = "Error"
                    alertMessage = "Failed to leave duel: \(error?.localizedDescription ?? "Unknown error")"
                    showAlert = true
                }
            }
        }
    }
}
